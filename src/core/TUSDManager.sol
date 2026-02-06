// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Pausable} from "../../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IAccountManager} from "../interfaces/core/IAccountManager.sol";
import {ICollateralManager} from "../interfaces/core/ICollateralManager.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {ITUSDManager} from "../interfaces/core/ITUSDManager.sol";
import {ITemplarUsd} from "../interfaces/core/ITemplarUsd.sol";

contract TUSDManager is ITUSDManager, Ownable, Pausable {
    using Math for uint256;
    //This maps token address to it's own specific tokenManager registry info
    mapping(address => TokenRegistryInfo) public tokenRegistry;

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

    constructor(address _TUSD, address _manager, address owner) Ownable(owner) {
        TUSD = ITemplarUsd(_TUSD);
        appManager = IManager(_manager);
    }

    modifier onlyManagers() {
        require(msg.sender == appManager.accountManager() || msg.sender == appManager.liquidationManager() || msg.sender == appManager.strategyManager(), UnAuthorized());
        _;
    }

    //CORE FUNCTIONS
    /**
     * @notice Deposit collateral into the collateral manager linked to the token
     *
     * @param account The depositor account
     * @param token  Token address that is linked to collateral manager
     * @param amount amount to deposit
     *
     * @dev only callable by authorized managers and checks that token is active
     *
     */
    function depositCollateral(address account, address token, uint256 amount) external onlyManagers {
        require(tokenRegistry[token].isActive, InactiveToken());
        _getCollateralManager(token).depositCollateral(account, amount);
    }

    /**
     * @notice Withdraw collateral from the collateral manager linked to the token
     *
     * @param account The withdrawer account
     * @param token  Token address that is linked to collateral manager
     * @param amount amount to withdraw
     *
     * @dev only callable by authorized managers and checks that token is active and account remains solvent after withdraw
     *
     */
    function withdrawCollateral(address account, address token, uint256 amount) external onlyManagers whenNotPaused {
        //Still deciding, but currently not sure to check active status when withdrawing
        //require(tokenRegistry[token].isActive, InactiveToken());
        _getCollateralManager(token).withdrawCollateral(account, amount);
        require(isAccountSolvent(token, account), Insolvent());
    }

    /**
     * @notice Force withdraw collateral from the collateral manager linked to the token
     *
     * @param account The withdrawer account
     * @param token  Token address that is linked to collateral manager
     * @param amount amount to withdraw
     *
     * @dev only callable by liquidation manager during liquidations and checks that token is active
     *
     */
    function forceWithdrawCollateral(address account, address token, uint256 amount) external whenNotPaused {
        //sanity checks
        require(msg.sender == appManager.liquidationManager(), Unauthorized());
        // require(tokenRegistry[token].isActive, InactiveToken());
        _getCollateralManager(token).withdrawCollateral(account, amount);
    }

    /**
     * @notice Borrow TUSD against collateral deposited
     *
     * @param account The borrower account
     * @param token  Token address that is linked to collateral manager
     * @param amount amount to borrow
     * @param minAmountOut minimum amount expected after slippage
     * @param mintToSender boolean to indicate if minted TUSD should go to sender or the account
     *
     * @dev only callable by authorized managers and checks that token is active and account remains solvent after borrow
     *
     */
    function borrow(address account, address token, uint256 amount, uint256 minAmountOut, bool mintToSender) external onlyManagers whenNotPaused {
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
        address receiver = mintToSender ? IAccountManager(account).accountToUser(account) : account;
        TUSD.mint(receiver, mintAmount);
        totalBorrowedTUSD[token] += mintAmount;
        _getCollateralManager(token).borrow(account, amount);
        //solvency check
        require(isAccountSolvent(token, account), Insolvent());
    }

    /**
     * @notice Repay borrowed TUSD
     *
     * @param account The borrower account
     * @param token  Token address that is linked to collateral manager
     * @param amount amount to repay
     * @param burnFrom address from which TUSD will be burned
     *
     * @dev only callable by authorized managers and checks that token is active
     *
     */
    function repay(address account, address token, uint256 amount, address burnFrom) external onlyManagers {
        //get manager
        ICollateralManager collateralManager = ICollateralManager(token);
        //sanity checks
        require(amount > 0, ZeroAmount());
        require(tokenRegistry[token].isActive, InactiveToken());
        require(burnFrom != address(0), ZeroAddress());
        require(collateralManager.borrowed(account) > 0, ZeroAmount());
        require(collateralManager.borrowed(account) >= amount, WrongAmount());

        //update state and burn
        TUSD.burnFrom(burnFrom, amount);
        totalBorrowedTUSD[token] -= amount;
        _getCollateralManager(token).borrow(account, amount);
    }

    /**
     * @notice Add new collateral manager to the registry
     *
     * @param manager The collateral manager address
     * @param token  Token address that is linked to collateral manager
     * @param _isActive boolean to set if the token is active or not
     *
     * @dev only callable by owner and checks that token linked to manager is correct
     *
     */
    function addNewCollateralManager(address manager, address token, bool _isActive) external onlyOwner {
        require(ICollateralManager(manager).token() == token, InvalidManagerOrToken());
        TokenRegistryInfo memory info;
        info.isActive = _isActive;

        if (tokenRegistry[token].deployedAt == address(0)) {
            info.deployedAt = manager;
            appManager.addWithdrawableToken(token);
        } else {
            info.deployedAt = manager;
        }
        tokenRegistry[token] = info;
    }

    //HELPER FUNCTIONS
    function isAccountSolvent(address token, address account) public view returns (bool) {
        ICollateralManager manager = _getCollateralManager(token);

        //if account has not borrow, just return 0;
        if (manager.borrowed(account) == 0) {
            return true;
        }

        uint256 collateralizationRatio = getCollaterizationRatio(token, account, manager.getConfig().collateralizationRate);

        return collateralizationRatio >= manager.borrowed(account);
    }

    function isLiquidatable(address account, address token) public view returns (bool) {
        ICollateralManager manager = _getCollateralManager(token);

        //if account has not borrow, just return 0;
        if (manager.borrowed(account) == 0) {
            return true;
        }

        //get liquidation ratio
        ICollateralManager.CollateralManagerConfig memory managerConfig = manager.getConfig();
        uint256 liquidationRate = managerConfig.collateralizationRate + managerConfig.liquidationBuffer;
        return manager.borrowed(account).mulDiv(1, appManager.EXCHANGE_RATE_PRECISION()) > getCollaterizationRatio(token, account, liquidationRate);
    }

    function getCollaterizationRatio(address token, address account, uint256 rate) public view returns (uint256) {
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

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @notice Returns to normal state.
     */
    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @notice Override to avoid losing contract ownership.
     */
    function renounceOwnership() public pure override {
        revert("1000");
    }

    function tokenRegistryInfo(address token) public view returns (bool isActive, address collateralManager) {
        TokenRegistryInfo memory _tokenRegistryInfo = tokenRegistry[token];
        isActive = _tokenRegistryInfo.isActive;
        collateralManager = _tokenRegistryInfo.deployedAt;
    }

    function getTUSDAddress() external view returns (address) {
        return address(TUSD);
    }
}
