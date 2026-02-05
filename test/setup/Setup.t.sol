// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {ICollateralManager} from "../../src/interfaces/core/ICollateralManager.sol";
import {IManager} from "../../src/interfaces/core/IManager.sol";
import {IReceiptToken} from "../../src/interfaces/core/IReceiptToken.sol";
import {IStrategy} from "../../src/interfaces/core/IStrategy.sol";
import {IStrategyManager} from "../../src/interfaces/core/IStrategyManager.sol";

// Core contract imports
import {AccountManager} from "../../src/core/AccountManager.sol";
import {LiquidationManager} from "../../src/core/LiquidationManager.sol";
import {Manager} from "../../src/core/Manager.sol";
import {ReceiptToken, ReceiptTokenFactory} from "../../src/core/ReceiptToken.sol";
import {StrategyManager} from "../../src/core/StrategyManager.sol";
import {TUSDManager} from "../../src/core/TUSDManager.sol";
import {TemplarUsd} from "../../src/core/TemplarUsd.sol";
import {CollateralManager} from "../../src/core/collateralManager.sol";

//setup helpers
import {DummyOracle} from "./DummyOracle.sol";
import {TestToken} from "./TestToken.sol";

abstract contract Setup is Test {
    //Core contracts
    IReceiptToken public receiptTokenImpl;
    TestToken public token1;
    TestToken public token2;
    DummyOracle public token2Oracle;
    Manager internal manager;
    AccountManager internal accountManager;
    CollateralManager internal collateralManager;
    CollateralManager internal collateralManager2;
    TUSDManager internal tusdManager;
    ReceiptTokenFactory internal receiptTokenFactory;
    StrategyManager internal strategyManager;
    LiquidationManager internal liquidationManager;
    TemplarUsd internal tUSD;
    DummyOracle internal token1Oracle;
    DummyOracle internal tUSDOracle;

    //Admins
    address internal owner = makeAddr("owner");
    address internal feeRecipient = makeAddr("feeRecipient");

    //Users
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    //mapping of asset/collateral to collateral manager
    mapping(address => address) public assetManager;

    function initialize() public {
        vm.startPrank(owner);
        token1 = new TestToken();
        token2 = new TestToken();
        token1Oracle = new DummyOracle("TestTokenOracle", "TTO");
        token2Oracle = new DummyOracle("token2Oracle", "TTO2");
        tUSDOracle = new DummyOracle("TemplarUsdOracle", "TUO");
        manager = new Manager(owner, address(tUSDOracle), bytes(""));
        tUSD = new TemplarUsd(owner, address(manager));
        tUSD.updateMaxMintLimit(type(uint256).max);
        accountManager = new AccountManager(owner, address(manager));
        liquidationManager = new LiquidationManager(owner, address(manager));
        tusdManager = new TUSDManager(address(tUSD), address(manager), owner);
        strategyManager = new StrategyManager(owner, address(manager));

        collateralManager = new CollateralManager(
            owner,
            address(manager),
            address(token1),
            address(token1Oracle),
            bytes(""),
            ICollateralManager.CollateralManagerConfig({collateralizationRate: 50000, liquidationBuffer: 5e3, liquidatorBonus: 8e3})
        );

        collateralManager2 = new CollateralManager(
            owner,
            address(manager),
            address(token2),
            address(token2Oracle),
            bytes(""),
            ICollateralManager.CollateralManagerConfig({collateralizationRate: 70000, liquidationBuffer: 7e3, liquidatorBonus: 1e4})
        );

        receiptTokenImpl = IReceiptToken(new ReceiptToken());
        receiptTokenFactory = new ReceiptTokenFactory(owner, address(receiptTokenImpl));

        //manager setups
        manager.setReceiptTokenFactory(address(receiptTokenFactory));
        manager.setAccountManager(address(accountManager));
        manager.setLiquidationManager(address(liquidationManager));
        manager.setTemplarUsdManager(address(tusdManager));
        manager.setStrategyManager(address(strategyManager));

        manager.setfeeRecipient(feeRecipient);
        manager.whitelistToken(address(token1));
        manager.whitelistToken(address(token2));

        //Updating strategies
        tusdManager.addNewCollateralManager(address(collateralManager), address(token1), true);
        assetManager[address(token1)] = address(collateralManager);
        tusdManager.addNewCollateralManager(address(collateralManager2), address(token2), true);
        assetManager[address(token2)] = address(collateralManager2);

        vm.stopPrank();
    }

    function assumeNotOwnerOrAddressZero(address _user) internal {
        vm.assume(_user != owner || _user != feeRecipient || _user != address(0));
    }

    // function initUser(
    //     address _user,
    //     address _assetToDeposit,
    //     uint256 _amountToMint
    // ) public returns (address userAccount) {
    //     IERC20Metadata collateralContract = IERC20Metadata(_assetToDeposit);
    //     uint256 collateralValueInUSd = _getCollateralAmountForUSDValue(
    //         _assetToDeposit,
    //         _amountToMint,
    //         collateralManager.getExchangeRate()
    //     ) * 2;
    //     console.log(
    //         "collateral value in usd initially gotten",
    //         collateralValueInUSd
    //     );
    //     deal(_assetToDeposit, _user, collateralValueInUSd);
    //     vm.startPrank(_user);
    //     userAccount = accountManager.createAccount();
    //     collateralContract.approve(
    //         address(accountManager),
    //         collateralValueInUSd
    //     );
    //     accountManager.deposit(_assetToDeposit, collateralValueInUSd);
    //     vm.stopPrank();
    // }

    function createAccount(address _user) internal returns (address userAccount) {
        vm.startPrank(_user);
        userAccount = accountManager.createAccount();
        vm.stopPrank();
    }

    function depositForUser(address _user, address _assetToDeposit, uint256 _amountToMint) public returns (address newUserAccount) {
        newUserAccount = createAccount(_user);
        IERC20Metadata collateralContract = IERC20Metadata(_assetToDeposit);
        uint256 collateralValueInUSd = _getCollateralAmountForUSDValue(_assetToDeposit, _amountToMint, collateralManager.getExchangeRate()) * 2;
        console.log("collateral value in usd initially gotten for user", collateralValueInUSd);
        deal(_assetToDeposit, _user, collateralValueInUSd);
        vm.startPrank(_user);
        collateralContract.approve(address(accountManager), collateralValueInUSd);
        accountManager.deposit(_assetToDeposit, collateralValueInUSd);
        vm.stopPrank();
    }

    function _getCollateralAmountForUSDValue(address _collateral, uint256 _tUSDAmount, uint256 _exchangeRate) private view returns (uint256 totalCollateral) {
        // calculate based on the USD value
        totalCollateral = (1e18 * _tUSDAmount * manager.EXCHANGE_RATE_PRECISION()) / (_exchangeRate * 1e18);

        // transform from 18 decimals to collateral's decimals
        uint256 collateralDecimals = IERC20Metadata(_collateral).decimals();

        if (collateralDecimals > 18) {
            totalCollateral = totalCollateral * (10 ** (collateralDecimals - 18));
        } else if (collateralDecimals < 18) {
            totalCollateral = totalCollateral / (10 ** (18 - collateralDecimals));
        }
    }
}
