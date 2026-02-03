// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IAccount} from "../interfaces/core/IAccount.sol";
import {IAccountManager} from "../interfaces/core/IAccountManager.sol";
import {ICollateralManager} from "../interfaces/core/ICollateralManager.sol";
import {IExchangeManager} from "../interfaces/core/IExchangeManager.sol";
import {ILiquidationManager} from "../interfaces/core/ILiquidationManager.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {IStrategy} from "../interfaces/core/IStrategy.sol";
import {IStrategyManager} from "../interfaces/core/IStrategyManager.sol";
import {ITUSDManager} from "../interfaces/core/ITUSDManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LiquidationManager is ILiquidationManager, Ownable, ReentrancyGuard {
    using Math for uint256;

    IManager appManager;
    uint256 public constant LIQUIDATION_PRECISION = 1e5;
    uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;
    uint256 public selfLiquidationFee = 1e4;

    constructor(address owner, address _manager) Ownable(owner) {
        appManager = IManager(_manager);
    }

    /**
     * @notice Self-liquidate to avoid getting liquidated by others. You can choose to pull from your strategies and pay a fee to reduce the amount of collateral you lose.
     *
     * @param tusdAmountToLiq The amount of TUSD you want to get liquidated for
     * @param collateral The collateral you want to get liquidated
     * @param swap The swap data for the exchange manager to execute the swap
     * @param strategies The strategies data to withdraw collateral from
     *
     */
    function selfLiquidate(uint256 tusdAmountToLiq, address collateral, Swapdata memory swap, Strategiesdata memory strategies) public nonReentrant {
        //Get neccessary details and contracts
        (IAccountManager accountManager, IExchangeManager exchangeManager, ITUSDManager tusdManager, IStrategyManager strategyManager) = getManagers();
        (bool isCollateralActive, address collateralManagerAddress) = tusdManager.tokenRegistryInfo(collateral);
        address account = accountManager.userToAccount(msg.sender);
        uint256 totalBorrowed = ICollateralManager(collateralManagerAddress).borrowed(account);
        uint256 tusdRateInUsd = ICollateralManager(collateralManagerAddress).getExchangeRate();

        //sanity checks
        require(tusdAmountToLiq != 0, ZeroAmountToLiq());
        require(collateral != address(0), ZeroAddress());
        require(isCollateralActive, InactiveToken());
        require(tusdManager.isAccountSolvent(collateral, account), Insolvent());
        require(tusdAmountToLiq <= totalBorrowed, InvalidAmount());
        require(swap.slippage <= LIQUIDATION_PRECISION, InvalidSlippage());

        //Get how much collateral is needed to get tusdAmountToLiq accounting for fees
        uint256 collateralInTusd = _getCollateralInTusd(collateral, tusdAmountToLiq, tusdRateInUsd, tusdManager);

        //check slippage
        uint256 slippageCollateral = collateralInTusd.mulDiv(swap.slippage, LIQUIDATION_PRECISION);
        require(swap.amountInMaximum <= slippageCollateral, SlippageRevert());

        //calculate fee and get total collateral
        uint256 fee = collateralInTusd.mulDiv(selfLiquidationFee, LIQUIDATION_PRECISION);
        uint256 totalCollateralInTusd = collateralInTusd + fee;

        //withdraw from strategies
        uint256 collateralInStrategies;
        if (strategies.strategies.length > 0) {
            collateralInStrategies = _retrieveCollateral(collateral, account, totalCollateralInTusd, strategies.strategies, strategies.strategiesData, strategies.useAccountBalance, strategyManager);
        }
        //what is the total collateral???
        uint256 availableCollateral = strategies.useAccountBalance ? IERC20Metadata(collateral).balanceOf(account) : collateralInStrategies;
        require(availableCollateral >= totalCollateralInTusd, NotEnoughCollateral());

        //swap initial param to actual Tusd
        uint256 collateralUsedForSwap = exchangeManager.swapExactOutputMultihop(collateral, swap.swapPath, account, swap.deadline, tusdAmountToLiq, swap.amountInMaximum);

        uint256 finalFeeCollateral = collateralUsedForSwap.mulDiv(selfLiquidationFee, EXCHANGE_RATE_PRECISION);

        // Transfer fees to fee address.
        if (finalFeeCollateral != 0) {
            IAccount(account).transfer(collateral, appManager.feeRecipient(), finalFeeCollateral);
        }
        uint256 totalCollateralUsed = collateralUsedForSwap + finalFeeCollateral;

        //repay the debt and remove collateral(incl fees)
        tusdManager.repay(account, collateral, tusdAmountToLiq, account);
        tusdManager.withdrawCollateral(account, collateral, totalCollateralUsed);

        // Emit event indicating self-liquidation.
        emit SelfLiquidated(account, collateral, tusdAmountToLiq, totalCollateralUsed);
    }

    /**
     * @notice Liquidate an undercollateralized account
     *
     * @param collateral The collateral to liquidate
     * @param user The user to liquidate
     * @param amount The amount of TUSD to liquidate
     * @param minCollateralToReceive The minimum amount of collateral to receive after liquidation
     * @param data The liquidation data including strategies to withdraw from
     *
     */
    function liquidate(address collateral, address user, uint256 amount, uint256 minCollateralToReceive, LiqData calldata data) external {
        //Get neccessary details and contracts
        (IAccountManager accountManager, IExchangeManager exchangeManager, ITUSDManager tusdManager, IStrategyManager strategyManager) = getManagers();
        (bool isCollateralActive, address collateralManagerAddress) = tusdManager.tokenRegistryInfo(collateral);
        address account = accountManager.userToAccount(msg.sender);
        uint256 totalBorrowed = ICollateralManager(collateralManagerAddress).borrowed(account);
        uint256 tusdRateInUsd = ICollateralManager(collateralManagerAddress).getExchangeRate();

        //sanity checks
        require(amount != 0, ZeroAmountToLiq());
        require(collateral != address(0), ZeroAddress());
        require(isCollateralActive, InactiveToken());
        require(tusdManager.isLiquidatable(collateral, account), NotLiquidatable());
        require(amount <= totalBorrowed, InvalidAmount());

        //Get how much collateral is needed to get tusdAmountToLiq accounting for fees
        uint256 collateralInTusd = _getCollateralInTusd(collateral, amount, tusdRateInUsd, tusdManager);

        //calculate bonus and add if there is, but none if its msg.sender
        collateralInTusd += user == msg.sender ? 0 : collateralInTusd.mulDiv(ICollateralManager(collateralManagerAddress).getConfig().liquidatorBonus, LIQUIDATION_PRECISION);

        //withdraw from strategies
        uint256 collateralInStrategies;
        if (data.strategies.length > 0) {
            collateralInStrategies = _retrieveCollateral(collateral, account, collateralInTusd, data.strategies, data.strategiesData, true, strategyManager);
        }

        //slippage check
        collateralInTusd = Math.min(IERC20(collateral).balanceOf(account), collateralInTusd);
        require(collateralInTusd >= minCollateralToReceive, InvalidSlippage());

        //repay the debt, remove collateral and transfer to msg.sender
        tusdManager.repay(account, collateral, amount, msg.sender);
        tusdManager.forceWithdrawCollateral(account, collateral, collateralInTusd);
        IAccount(account).transfer(collateral, msg.sender, collateralInTusd);

        // Emit event indicating liquidation.
        emit Liquidated(account, collateral, amount, collateralInTusd);
    }

    /**
     * @notice Liquidate an account that has bad debt (no collateral left)
     *
     * @param collateral The collateral to liquidate
     * @param user The user to liquidate
     * @param data The liquidation data including strategies to withdraw from
     *
     */
    function liquidateBadDebt(address collateral, address user, LiqData calldata data) external nonReentrant onlyOwner {
        //Get neccessary details and contracts
        (IAccountManager accountManager,, ITUSDManager tusdManager, IStrategyManager strategyManager) = getManagers();
        (bool isCollateralActive, address collateralManagerAddress) = tusdManager.tokenRegistryInfo(collateral);
        address account = accountManager.userToAccount(user);
        uint256 totalBorrowed = ICollateralManager(collateralManagerAddress).borrowed(account);
        uint256 totalCollateral = ICollateralManager(collateralManagerAddress).collateralDeposited(account);
        uint256 tusdRateInUsd = ICollateralManager(collateralManagerAddress).getExchangeRate();

        //sanity checks
        require(collateral != address(0), ZeroAddress());
        require(isCollateralActive, InactiveToken());
        require(tusdManager.isLiquidatable(collateral, account), NotLiquidatable());

        //withdraw from strategies
        uint256 collateralInStrategies;
        if (data.strategies.length > 0) {
            collateralInStrategies = _retrieveCollateral(collateral, account, totalCollateral, data.strategies, data.strategiesData, true, strategyManager);
        }
        totalCollateral = ICollateralManager(collateralManagerAddress).collateralDeposited(account);

        if (totalCollateral >= _getCollateralInTusd(collateral, totalCollateral, tusdRateInUsd, tusdManager)) revert();

        //repay the debt, remove collateral and transfer to msg.sender
        tusdManager.repay(account, collateral, totalBorrowed, msg.sender);
        tusdManager.forceWithdrawCollateral(account, collateral, totalCollateral);
        IAccount(account).transfer(collateral, msg.sender, totalCollateral);

        // Emit event indicating liquidation.
        emit BadDebtLiquidated(account, collateral, totalBorrowed, totalCollateral);
    }

    function _getCollateralInTusd(address collateral, uint256 tusdAmountToLiq, uint256 tusdRateInUsd, ITUSDManager tusdManager) internal view returns (uint256) {
        //first convert to collateral based on usd
        uint256 collateralAmount = tusdAmountToLiq.mulDiv(EXCHANGE_RATE_PRECISION, tusdRateInUsd);
        //now put it in jusd term
        collateralAmount = collateralAmount.mulDiv(appManager.getTusdExchangeRate(), EXCHANGE_RATE_PRECISION);

        require(collateralAmount > 0, ZeroAmount());
        return tusdManager.transformTo18Decimals(collateral, collateralAmount);
    }

    function _retrieveCollateral(
        address collateral,
        address account,
        uint256 amount,
        address[] memory strategies,
        bytes[] memory data,
        bool useBalance,
        IStrategyManager strategyManager
    )
        internal
        returns (uint256 retrievedCollateral)
    {
        if (useBalance && (IERC20(collateral).balanceOf(account) >= amount)) {
            return amount;
        }
        require(strategies.length == data.length, DifferentLength());

        //iterate over strategies and retrieve their collateral
        for (uint256 i = 0; i < strategies.length; i++) {
            (, uint256 shares) = IStrategy(strategies[i]).recipients(account);

            (uint256 withdrawResult,,,) = strategyManager.claimInvestment(account, collateral, strategies[i], shares, data[i]);
            retrievedCollateral += withdrawResult;

            if (useBalance && IERC20(collateral).balanceOf(account) >= amount) {
                break;
            }
        }
    }

    function getManagers() public view returns (IAccountManager accountManager, IExchangeManager exchangeManager, ITUSDManager tusdManager, IStrategyManager strategyManager) {
        //To avoid reading from storage
        IManager manager = appManager;
        accountManager = IAccountManager(manager.accountManager());
        exchangeManager = IExchangeManager(manager.exchangeManager());
        tusdManager = ITUSDManager(manager.templarUsdManager());
        strategyManager = IStrategyManager(manager.strategyManager());
    }

    function setSelfLiquidationFee(uint256 amount) external onlyOwner {
        selfLiquidationFee = amount;
    }

    function renounceOwnership() public pure override {
        revert();
    }
}
