// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

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
    IManager appManager;

    constructor(address owner, address _manager) Ownable(owner) {
        appManager = IManager(_manager);
    }

    function selfLiquidate(uint256 tusdAmountToLiq, address collateral, Swapdata calldata swap, Strategiesdata calldata strategies) public nonReentrant {
        //Get neccessary details and contracts
        (IAccountManager accountManager, IExchangeManager exchangeManager, ITUSDManager tusdManager, IStrategyManager strategyManager) = getManagers();
        (bool isCollateralActive, address collateralManagerAddress) = tusdManager.tokenRegistryInfo(collateral);
        address account = accountManager.userToAccount(msg.sender);
        uint256 totalBorrowed = ICollateralManager(collateralManagerAddress).borrowed(account);

        //sanity checks
        require(tusdAmountToLiq != 0, ZeroAmountToLiq());
        require(collateral != address(0), ZeroAddress());
        require(isCollateralActive, InactiveToken());
        require(tusdManager.isAccountSolvent(collateral, account), Insolvent());
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
