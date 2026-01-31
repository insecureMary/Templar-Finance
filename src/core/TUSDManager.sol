// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IAccountManager} from "../interfaces/core/IAccountManager.sol";
import {ICollateralManager} from "../interfaces/core/ICollateralManager.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {ITUSDManager} from "../interfaces/core/ITUSDManager.sol";
import {ITemplarUsd} from "../interfaces/core/ITemplarUsd.sol";

contract TUSDManager is ITUSDManager {
    using Math for uint256;
    //This maps token address to it's own specific tokenManager registry info
    mapping(address token => tokenRegistryInfo) public tokenRegistry;

    /* This maps token address to total borrowed TUSD against that token as collateral
     */
    mapping(address token => uint256 totalBorrowedTUSD) public totalBorrowedTUSD;

    /**
     * @notice The Templar USD contract address
     */
    ITemplarUsd public immutable TUSD;

    /**
     * @notice The Manager contract address, control all protocol wide settings
     */
    IManager public appManager;

    constructor(address _TUSD, address _manager) {
        TUSD = ITemplarUsd(_TUSD);
        appManager = IManager(_manager);
    }

    function depositCollateral(address account, address token, uint256 amount) external {
        require(tokenRegistry[token].isActive, InactiveToken());
        _getCollateralManager(token).depositCollateral(account, amount);
    }

    function withdrawCollateral(address account, address token, uint256 amount) external {
        require(tokenRegistry[token].isActive, InactiveToken());
        _getCollateralManager(token).withdrawCollateral(account, amount);
        require(!isAccountSolvent(token, account), Insolvent());
    }

    function forceWithdrawCollateral(address account, address token, uint256 amount) external {
        //sanity checks
        require(msg.sender == appManager.liquidationManager(), Unauthorized());
        require(tokenRegistry[token].isActive, InactiveToken());
        _getCollateralManager(token).withdrawCollateral(account, amount);
    }

    function borrow(address account, address token, uint256 amount, uint256 minAmountOut, bool mintToSender) external {
        require(amount > 0, ZeroAmount());
        require(tokenRegistry[token].isActive, InactiveToken());

        //get and convert amount to 18 decimals
        uint256 amount18 = transformTo18Decimals(token, amount);
        //get the value
        uint256 amountValue = amount18.mulDiv(ICollateralManager(token).getExchangeRate(), appManager.EXCHANGE_RATE_PRECISION());
        uint256 mintAmount = amountValue.mulDiv(appManager.EXCHANGE_RATE_PRECISION(), 1);
        //slippage check
        require(mintAmount >= minAmountOut, MintAmountIsLessThanSlippage());

        //update state and mint
        totalBorrowedTUSD[token] += mintAmount;
        _getCollateralManager(token).borrow(account, amount);
        address receiver = mintToSender ? IAccountManager(account).accountToUser(account) : account;
        TUSD.mint(receiver, mintAmount);
    }

    function isAccountSolvent(address token, address account) public returns (bool) {
        ICollateralManager manager = _getCollateralManager(token);

        //if account has not borrow, just return 0;
        if (manager.borrowed(account) == 0) {
            return true;
        }

        uint256 collateralizationRatio = getCollaterizationRatio(token, account, manager.getConfig().collateralizationRate);

        return collateralizationRatio >= manager.borrowed(account);
    }

    function getCollaterizationRatio(address token, address account, uint256 rate) public returns (uint256) {
        ICollateralManager collateralManager = ICollateralManager(token);
        uint256 collateralAmount = collateralManager.collateralDeposited(account);
        uint256 exchangeRate = collateralManager.getExchangeRate();
        uint256 precision = appManager.EXCHANGE_RATE_PRECISION() * appManager.PRECISION_FACTOR();

        /**
         * Easy!
         * collateralAmount(in token decimal) * rate(in 1e5 format) * exchangeRate(in 1e18 format)
         * ----------------------------------------------------------------------------------------
         *                          precision(in 1e5 * 1e18 format)
         */
        uint256 ratio = (collateralAmount * rate * exchangeRate) / precision;
        //regularize collateral decimal to 18 decimal format
        return transformTo18Decimals(token, ratio);
    }

    function transformTo18Decimals(address token, uint256 amount) public view returns (uint256) {
        uint256 decimal = IERC20Metadata(token).decimals();
        if (decimal == 18) {
            return amount;
        }
        return _transformTo18Decimals(amount, decimal);
    }

    function _transformTo18Decimals(uint256 _amount, uint256 _decimals) private pure returns (uint256) {
        if (_decimals < 18) return _amount * (10 ** (18 - _decimals));
        if (_decimals > 18) return _amount / (10 ** (_decimals - 18));
    }

    function _getCollateralManager(address token) private view returns (ICollateralManager) {
        return ICollateralManager(tokenRegistry[token].deployedAt);
    }
}
