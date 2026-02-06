// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;
import {Test} from "../../lib/forge-std/src/Test.sol";
import {CollateralManager} from "../../src/core/collateralManager.sol";
import {ICollateralManager} from "../../src/interfaces/core/ICollateralManager.sol";
import {ITUSDManager} from "../../src/interfaces/core/ITUSDManager.sol";
import {Setup} from "../setup/Setup.t.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract TusdManagerTest is Test, Setup {
    function setUp() public {
        Setup.initialize();
    }

    function _deposithelper(address user, address asset, uint256 amount) internal {
        token1Oracle.setUpdated(true);
        depositForUser(user, asset, amount);
    }

    function _depositAndBorrowHelper(uint256 amount) internal {
        _deposithelper(alice, address(token1), ETHER);
        tUSDOracle.setUpdated(true);
        vm.prank(address(alice));
        accountManager.borrow(address(token1), amount, amount, true);
    }

    function testDepositWillPassWhenSetupIsCorrect() public {
        //arrange
        uint256 balanceBefore = collateralManager.collateralDeposited(aliceAccount);
        //first make oracle updated
        token1Oracle.setUpdated(true);
        //deal and deposit straightup
        depositForUser(alice, address(token1), ETHER);

        //assert
        uint256 balanceAfter = collateralManager.collateralDeposited(aliceAccount);
        uint256 balanceDiff = balanceAfter - balanceBefore;
        assertEq(balanceDiff, ETHER);
    }

    function testDepositWillRevertWhenTokenIsNotActive() public {
        //arrange
        //first let us make token 1 inactive
        vm.prank(owner);
        tusdManager.addNewCollateralManager(address(collateralManager), address(token1), false);
        (bool isActive,) = tusdManager.tokenRegistryInfo(address(token1));
        assertEq(isActive, false);

        //acts
        token1Oracle.setUpdated(true);
        IERC20Metadata collateralContract = IERC20Metadata(address(token1));
        uint256 collateralValueInUSd = _getCollateralAmountForUSDValue(address(token1), ETHER, collateralManager.getExchangeRate());

        vm.startPrank(alice);
        collateralContract.approve(address(accountManager), collateralValueInUSd);
        vm.expectRevert(abi.encodeWithSelector(ITUSDManager.InactiveToken.selector));
        accountManager.deposit(address(token1), collateralValueInUSd);
        vm.stopPrank();
    }

    function testDepositCollateralWillRevertWhenNotManager() public {
        //alice tries to call deposit directly from tusd manager
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(ITUSDManager.UnAuthorized.selector));
        tusdManager.depositCollateral(aliceAccount, address(token1), ETHER);
    }

    function testWithdrawWillPassWhenSetupIsCorrect() public {
        //arrange
        //first let us deposit
        _deposithelper(alice, address(token1), ETHER);
        uint256 preAccountBalance = collateralManager.collateralDeposited(aliceAccount);
        uint256 preUserBalance = token1.balanceOf(alice);

        //act
        vm.prank(alice);
        accountManager.withdraw(address(token1), ETHER);

        //assert
        uint256 postAccountBalance = collateralManager.collateralDeposited(aliceAccount);
        uint256 postUserBalance = token1.balanceOf(alice);
        assertEq(preAccountBalance - postAccountBalance, ETHER);
        assertEq(postUserBalance - preUserBalance, ETHER);
    }

    function testWithdrawWillPassEvenWhenTokenIsInactive() public {
        //arrange
        //first let us deposit
        _deposithelper(alice, address(token1), ETHER);
        uint256 preAccountBalance = collateralManager.collateralDeposited(aliceAccount);
        uint256 preUserBalance = token1.balanceOf(alice);
        //make token manager inactive
        vm.prank(owner);
        tusdManager.addNewCollateralManager(address(collateralManager), address(token1), false);
        (bool isActive,) = tusdManager.tokenRegistryInfo(address(token1));
        assertEq(isActive, false);

        //act
        vm.prank(alice);
        accountManager.withdraw(address(token1), ETHER);

        //assert
        uint256 postAccountBalance = collateralManager.collateralDeposited(aliceAccount);
        uint256 postUserBalance = token1.balanceOf(alice);
        assertEq(preAccountBalance - postAccountBalance, ETHER);
        assertEq(postUserBalance - preUserBalance, ETHER);
    }

    function testForceWithdrawWillPassWhensetUpIsCorrect() public {
        //arrange
        //first let us deposit
        _deposithelper(alice, address(token1), ETHER);
        uint256 preAccountBalance = collateralManager.collateralDeposited(aliceAccount);

        //act
        vm.prank(address(liquidationManager));
        tusdManager.forceWithdrawCollateral(aliceAccount, address(token1), ETHER);

        //assert
        uint256 postAccountBalance = collateralManager.collateralDeposited(aliceAccount);
        assertEq(preAccountBalance - postAccountBalance, ETHER);
    }

    function testForceWithdrawWillFailWhenUnauthorized() public {
        //arrange
        //first let us deposit
        _deposithelper(alice, address(token1), ETHER);
        uint256 preAccountBalance = collateralManager.collateralDeposited(aliceAccount);

        //act
        //We are pranking with alice instead, to check if she can force withdraw by herself
        vm.prank(address(alice));
        vm.expectRevert();
        tusdManager.forceWithdrawCollateral(aliceAccount, address(token1), ETHER);
    }

    function testWithdrawWillFailWhenNotDeposited() public {
        vm.prank(alice);
        vm.expectRevert();
        accountManager.withdraw(address(token1), ETHER);
    }

    function testUserCanBorrowAfterDepositing() public {
        //arrange
        //first let us deposit
        _deposithelper(alice, address(token1), ETHER);
        uint256 preTusdBalance = tUSD.balanceOf(alice);
        uint256 preManagerBorrowed = collateralManager.borrowed(aliceAccount);
        uint256 preTotalBorrowed = tusdManager.totalBorrowedTUSD(address(token1));

        uint256 amount = ETHER / 2;
        tUSDOracle.setUpdated(true);
        vm.prank(address(alice));
        accountManager.borrow(address(token1), amount, amount, true);
        uint256 postTusdBalance = tUSD.balanceOf(alice);
        uint256 postManagerBorrowed = collateralManager.borrowed(aliceAccount);
        uint256 postTotalBorrowed = tusdManager.totalBorrowedTUSD(address(token1));

        assertEq(postTusdBalance - preTusdBalance, amount);
        assertEq(postManagerBorrowed - preManagerBorrowed, amount);
        assertEq(postTotalBorrowed - preTotalBorrowed, amount);
    }

    function testUserCanBorrowToAccount() public {
        //arrange
        //first let us deposit
        _deposithelper(alice, address(token1), ETHER);
        uint256 preTusdBalance = tUSD.balanceOf(address(aliceAccount));
        uint256 preManagerBorrowed = collateralManager.borrowed(aliceAccount);
        uint256 preTotalBorrowed = tusdManager.totalBorrowedTUSD(address(token1));

        uint256 amount = ETHER / 2;
        tUSDOracle.setUpdated(true);
        vm.prank(address(alice));
        //borrowing to account instead
        accountManager.borrow(address(token1), amount, amount, false);
        uint256 postTusdBalance = tUSD.balanceOf(address(aliceAccount));
        uint256 postManagerBorrowed = collateralManager.borrowed(aliceAccount);
        uint256 postTotalBorrowed = tusdManager.totalBorrowedTUSD(address(token1));

        assertEq(postTusdBalance - preTusdBalance, amount);
        assertEq(postManagerBorrowed - preManagerBorrowed, amount);
        assertEq(postTotalBorrowed - preTotalBorrowed, amount);
    }

    function testBorrowWillFailWhenInsolvent() public {
        _deposithelper(alice, address(token1), ETHER);

        uint256 amount = ETHER;
        tUSDOracle.setUpdated(true);
        vm.prank(address(alice));
        vm.expectRevert();
        accountManager.borrow(address(token1), amount, amount, true);
    }

    function testBorrowWillFailWhenslippageChecked() public {
        _deposithelper(alice, address(token1), ETHER);

        uint256 amount = ETHER;
        tUSDOracle.setUpdated(true);
        vm.prank(address(alice));
        vm.expectRevert();
        accountManager.borrow(address(token1), amount, amount, true);
    }

    function testBorrowWillFailWhenInactiveToken() public {
        _deposithelper(alice, address(token1), ETHER);

        uint256 amount = ETHER;
        tUSDOracle.setUpdated(true);
        vm.prank(address(owner));
        tusdManager.addNewCollateralManager(address(collateralManager), address(token1), false);
        vm.prank(address(alice));
        vm.expectRevert();
        accountManager.borrow(address(token1), amount, amount + 1, true);
    }

    function testBorrowWillFailWhenNotDeposited() public {
        uint256 amount = ETHER / 2;
        tUSDOracle.setUpdated(true);
        vm.prank(address(alice));
        vm.expectRevert();
        accountManager.borrow(address(token1), amount, amount, true);
    }

    function testBorrowWillFailWhenNotCalledFromManager() public {
        uint256 amount = ETHER / 2;
        tUSDOracle.setUpdated(true);
        vm.prank(address(alice));
        vm.expectRevert();
        tusdManager.borrow(alice, address(token1), amount, amount, true);
    }

    function testWithdrawWillFailWhenBorrowAtLimit() public {
        _deposithelper(alice, address(token1), ETHER);

        uint256 amount = ETHER / 2;
        tUSDOracle.setUpdated(true);
        vm.prank(address(alice));
        accountManager.borrow(address(token1), amount, amount, true);

        vm.prank(alice);
        vm.expectRevert();
        accountManager.withdraw(address(token1), ETHER);
    }

    function testRepayWillPasssWhenSetupIsCorrect() public {
        //deposit and borrow
        uint256 amount = ETHER / 2;
        _depositAndBorrowHelper(amount);

        //repay
        uint256 preRepayTusd = tUSD.balanceOf(alice);
        vm.prank(address(alice));
        accountManager.repay(address(token1), amount, true);
        uint256 postRepayTusd = tUSD.balanceOf(address(alice));

        assertEq(preRepayTusd - postRepayTusd, amount);
    }

    function testRepayWillFailWhenAmountIsZero() public {
        //deposit and borrow
        uint256 amount = ETHER / 2;
        _depositAndBorrowHelper(amount);

        vm.prank(address(alice));
        vm.expectRevert();
        accountManager.repay(address(token1), amount - amount, true);
    }

    function testRepayWillFailWhenNoBorrow() public {
        //just deposit
        uint256 amount = ETHER / 2;
        _deposithelper(alice, address(token1), ETHER);

        vm.prank(address(alice));
        vm.expectRevert();
        accountManager.repay(address(token1), amount - amount, true);
    }

    function testaddNewCollateralManagerWillFailWhenNotCalledByOwner() public {
        vm.prank(address(manager));
        vm.expectRevert();
        tusdManager.addNewCollateralManager(address(collateralManager), address(token1), false);
    }

    function testAddNewCollateralWithNoDeployedAt() public {
        //setup

        ICollateralManager newCollateralManager = new CollateralManager(
            owner,
            address(manager),
            address(token3),
            address(token1Oracle),
            bytes(""),
            ICollateralManager.CollateralManagerConfig({collateralizationRate: 50000, liquidationBuffer: 5e3, liquidatorBonus: 8e3})
        );
        vm.prank(address(owner));

        tusdManager.addNewCollateralManager(address(newCollateralManager), address(token3), true);
        (, address colManager) = tusdManager.tokenRegistry(address(token3));
        assertEq(colManager, address(newCollateralManager));
    }

    function testTusdPauseAndUnpause() public {
        vm.startPrank(address(owner));
        tusdManager.pause();

        vm.expectRevert();
        tusdManager.pause();

        tusdManager.unpause();
        tusdManager.pause();
    }

    function testAccountIsolventReturnTrueWhenNoBorrow() public {
        tusdManager.isAccountSolvent(address(token1), aliceAccount);
    }
}

