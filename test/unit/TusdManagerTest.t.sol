// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;
import {Test} from "../../lib/forge-std/src/Test.sol";
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
}

