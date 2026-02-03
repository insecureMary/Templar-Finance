// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IAccountManager} from "../interfaces/core/IAccountManager.sol";
import {ICollateralManager} from "../interfaces/core/ICollateralManager.sol";
import {IExchangeManager} from "../interfaces/core/IExchangeManager.sol";
import {ILiquidationManager} from "../interfaces/core/ILiquidationManager.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {IStrategyManager} from "../interfaces/core/IStrategyManager.sol";
import {ITUSDManager} from "../interfaces/core/ITUSDManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LiquidationManager is ILiquidationManager, Ownable, ReentrancyGuard {
    using Math for uint256;

    IManager appManager;
    uint256 public constant LIQUIDATION_PRECISION = 1e5;
    uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;

    constructor(address owner, address _manager) Ownable(owner) {
        appManager = IManager(_manager);
    }

    function selfLiquidate(uint256 tusdAmountToLiq, address collateral, Swapdata calldata swap, Strategiesdata calldata strategies) public nonReentrant {
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
    }

    function _getCollateralInTusd(address collateral, uint256 tusdAmountToLiq, uint256 tusdRateInUsd, ITUSDManager tusdManager) internal returns (uint256) {
        //first convert to collateral based on usd
        uint256 collateralAmount = tusdAmountToLiq.mulDiv(EXCHANGE_RATE_PRECISION, tusdRateInUsd);
        //now put it in jusd term
        collateralAmount = collateralAmount.mulDiv(appManager.getTusdExchangeRate(), EXCHANGE_RATE_PRECISION);

        require(collateralAmount > 0, ZeroAmount());
        return tusdManager.transformTo18Decimals(collateral, collateralAmount);
    }

    function getManagers() public view returns (IAccountManager accountManager, IExchangeManager exchangeManager, ITUSDManager tusdManager, IStrategyManager strategyManager) {
        //To avoid reading from storage
        IManager manager = appManager;
        accountManager = IAccountManager(manager.accountManager());
        exchangeManager = IExchangeManager(manager.exchangeManager());
        tusdManager = ITUSDManager(manager.templarUsdManager());
        strategyManager = IStrategyManager(manager.strategyManager());
    }
}
