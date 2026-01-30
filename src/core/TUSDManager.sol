// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICollateralManager} from "../interfaces/core/ICollateralManager.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {ITUSDManager} from "../interfaces/core/ITUSDManager.sol";
import {ITemplarUsd} from "../interfaces/core/ITemplarUsd.sol";

contract TUSDManager is ITUSDManager {
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
    }

    function isAccountSolvent(address token, address account) public view returns (bool) {
        ICollateralManager manager = _getCollateralManager(token);

        //if account has not borrow, just return 0;
        if (manager.borrowed(account) == 0) {
            return true;
        }

        uint256 collateralizationRatio = getCollaterizationRatio(token, account, manager.config.collateralizationRate);

        return collateralizationRatio >= manager.borrowed;
    }

    function getCollaterizationRatio(address token, address account, uint256 rate) public view returns (uint256) {
        ICollateralManager collateralManager = ICollateralManager(token);
        uint256 collateralAmount = collateralManager.CollateralDeposited(account);
        uint256 exchangeRate = collateralManager.getExchangeRate();
        uint256 precision = appManager.EXCHANGE_RATE_PRECISION() * appManager.PRECISION();

        /**
         * Easy!
         * collateralAmount(in token decimal) * rate(in 1e5 format) * exchangeRate(in 1e18 format)
         * ----------------------------------------------------------------------------------------
         *                          precision(in 1e5 * 1e18 format)
         */
        uint256 ratio = (collateralAmount * rate * exchangeRate) / precision;
        //regularize collateral decimal to 18 decimal format
        uint256 decimal = IERC20Metadata(token).decimals();
        if (decimal == 18) {
            return ratio;
        }
        return _transformTo18Decimals(ratio, decimal);
    }

    function _transformTo18Decimals(uint256 _amount, uint256 _decimals) private pure returns (uint256) {
        if (_decimals < 18) return _amount * (10 ** (18 - _decimals));
        if (_decimals > 18) return _amount / (10 ** (_decimals - 18));
    }

    function _getCollateralManager(address token) private view returns (ICollateralManager) {
        return ICollateralManager(tokenRegistry[token].deployedAt);
    }
}
