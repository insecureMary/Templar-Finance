// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IManager} from "../../src/interfaces/core/IManager.sol";
import {Setup} from "../setup/Setup.t.sol";

contract ManagerTest is Setup {
    function setUp() public {
        initialize();
        token1Oracle.setUpdated(true);
        tUSDOracle.setUpdated(true);
    }

    function testManagerContractConstructorWorks() public view {
        assert(address(manager.tUsdOracle()) == address(tUSDOracle));
    }

    function testManagerContractSetups() public {
        assert(address(receiptTokenFactory) == address(manager.receiptTokenFactory()));
        assert(address(accountManager) == address(manager.accountManager()));
        assert(address(liquidationManager) == address(manager.liquidationManager()));
        assert(address(tusdManager) == address(manager.templarUsdManager()));
        assert(address(strategyManager) == address(manager.strategyManager()));
        assert(feeRecipient == manager.feeRecipient());
        assertTrue(manager.isTokenWhitelisted(address(token1)));
        assertTrue(manager.isTokenWhitelisted(address(token2)));
        //for the oracle data
        vm.startPrank(owner);
        manager.setOracleData(bytes("This is oracle data"));
        vm.stopPrank();
        assertEq(keccak256(manager.oracleData()), keccak256(bytes("This is oracle data")));
    }

    function testCheckBlacklistContractWorks() public {
        //arrange
        assertTrue(manager.isContractWhitelisted(address(accountManager)));
        //act
        vm.prank(owner);
        manager.blacklistContract(address(accountManager));
        //assrt
        assertFalse(manager.isContractWhitelisted(address(accountManager)));
    }

    function testCheckBlacklistTokenWorks() public {
        //arrange
        assertTrue(manager.isTokenWhitelisted(address(token1)));
        //act
        vm.prank(owner);
        manager.removeTokenFromWhitelist(address(token1));
        //assrt
        assertFalse(manager.isTokenWhitelisted(address(token1)));
    }

    function testCheckOnlyOwnerCanBlacklistContract() public {
        //arrange
        assertTrue(manager.isContractWhitelisted(address(accountManager)));
        //act
        vm.startPrank(alice);
        vm.expectRevert();
        manager.blacklistContract(address(accountManager));
        vm.stopPrank();
        assertTrue(manager.isContractWhitelisted(address(accountManager)));
    }

    function testCheckOnlyOwnerCanBlacklistToken() public {
        //arrange
        assertTrue(manager.isTokenWhitelisted(address(token1)));
        //act
        vm.startPrank(alice);
        vm.expectRevert();
        manager.removeTokenFromWhitelist(address(token1));
        //assrt
        assertTrue(manager.isTokenWhitelisted(address(token1)));
    }

    function testCanAddAndRemoveWithdrawableToken() public {
        assertTrue(manager.canWithdrawToken(address(token1)));
        //arrange
        //removing the token as a withdrawable token
        vm.prank(owner);
        manager.removeWithdrawableToken(address(token1));
        //first assert
        assertFalse(manager.canWithdrawToken(address(token1)));
        //lets add the token back now
        vm.prank(owner);
        manager.addWithdrawableToken(address(token1));
        //second assert
        assertTrue(manager.canWithdrawToken(address(token1)));
    }

    function testOnlyOwnerCanAddOrRemoveWithdrawableToken() public {
        //arrange
        assertTrue(manager.canWithdrawToken(address(token1)));
        //act
        //trying to remove the token as a withdrawable token
        vm.startPrank(alice);
        vm.expectRevert();
        manager.removeWithdrawableToken(address(token1));
        vm.stopPrank();
        //assert
        assertTrue(manager.canWithdrawToken(address(token1)));
        //let the actual owner remove the token
        vm.prank(owner);
        manager.removeWithdrawableToken(address(token1));
        //assert
        assertFalse(manager.canWithdrawToken(address(token1)));
        //let random user try to add the token back
        vm.startPrank(alice);
        vm.expectRevert();
        manager.addWithdrawableToken(address(token1));
        vm.stopPrank();
        //checking if the token still stayed as a non withdrawable one
        assertFalse(manager.canWithdrawToken(address(token1)));
        //lets have the owner add it back
        vm.prank(owner);
        manager.addWithdrawableToken(address(token1));
        //confirming that it worked
        assertTrue(manager.canWithdrawToken(address(token1)));
    }

    function testSetInvoker() public {
        //check that the address is not a previous invoker
        assertFalse(manager.isInvoker(bob));
        //act
        vm.prank(owner);
        manager.setInvoker(bob, true);
        //assert
        assertTrue(manager.isInvoker(bob));
        //lets remove and check again
        vm.prank(owner);
        manager.setInvoker(bob, false);
        //final assert
        assertFalse(manager.isInvoker(bob));
    }

    function testOnlyOwnerCanSetInvoker() public {
        //check that the address is not a previous invoker
        assertFalse(manager.isInvoker(bob));
        //act
        vm.startPrank(alice);
        vm.expectRevert();
        manager.setInvoker(bob, true);
        //assert that it did not work
        assertFalse(manager.isInvoker(bob));
    }

    function testNonOwnerCannotSetContracts(address dummyContract, address dummySetter) public {
        vm.assume(dummyContract != address(0));
        vm.assume(dummySetter != address(0) && dummySetter != owner);

        vm.startPrank(dummySetter);
        vm.expectRevert();
        manager.setAccountManager(dummyContract);
        vm.stopPrank();

        vm.startPrank(dummySetter);
        vm.expectRevert();
        manager.setLiquidationManager(dummyContract);
        vm.stopPrank();

        vm.startPrank(dummySetter);
        vm.expectRevert();
        manager.setTemplarUsdManager(dummyContract);
        vm.stopPrank();

        vm.startPrank(dummySetter);
        vm.expectRevert();
        manager.setStrategyManager(dummyContract);
        vm.stopPrank();

        vm.startPrank(dummySetter);
        vm.expectRevert();
        manager.setExchangeManager(dummyContract);
        vm.stopPrank();

        vm.startPrank(dummySetter);
        vm.expectRevert();
        manager.setReceiptTokenFactory(dummyContract);
        vm.stopPrank();

        vm.startPrank(dummySetter);
        vm.expectRevert();
        manager.setOracle(dummyContract);
        vm.stopPrank();

        vm.startPrank(dummySetter);
        vm.expectRevert();
        manager.setfeeRecipient(dummyContract);
        vm.stopPrank();

        vm.startPrank(dummySetter);
        vm.expectRevert();
        manager.setOracleData(bytes("Invalid contract"));
        vm.stopPrank();

        //asserts
        testManagerContractSetups();
    }

    function testSetNumberVariablesPositive() public {
        //assert the previous values of the variables, and check that they are 0 as they have not been set before
        assertEq(manager.performanceFee(), 0);
        assertEq(manager.minDebtAmount(), 0);
        assertEq(manager.withdrawalFeeRate(), 0);
        uint256 newPerformanceFee = 100;
        uint256 newMinDebtAmount = 1e5;
        uint256 newWithdrawalFeeRate = 200;

        //act
        vm.startPrank(owner);
        manager.setwithdrawalFeeRate(newWithdrawalFeeRate);
        manager.setMinDebtAmount(newMinDebtAmount);
        manager.setPerformanceFee(newPerformanceFee);
        vm.stopPrank();

        //assert
        assertEq(manager.performanceFee(), newPerformanceFee);
        assertEq(manager.minDebtAmount(), newMinDebtAmount);
        assertEq(manager.withdrawalFeeRate(), newWithdrawalFeeRate);
    }

    function testCannotSetBeyondMaxNumberLimits(uint256 badPerformanceFee, uint256 badWithdrawalFeeRate) public {
        vm.assume(badPerformanceFee > manager.MAX_PERFORMANCE_FEE());
        vm.assume(badWithdrawalFeeRate > manager.MAX_WITHDRAWAL_FEE());
        //checking for the performance fee
        vm.startPrank(owner);
        vm.expectRevert(IManager.IManager__FeeExceedsMaximum.selector);
        manager.setPerformanceFee(badPerformanceFee);
        vm.stopPrank();
        //checking for the withdrawal fee rate
        vm.startPrank(owner);
        vm.expectRevert(IManager.IManager__FeeExceedsMaximum.selector);
        manager.setwithdrawalFeeRate(badWithdrawalFeeRate);
        vm.stopPrank();
        //assert that no changes were made
        assertEq(manager.performanceFee(), 0);
        assertEq(manager.withdrawalFeeRate(), 0);
    }

    function testOnlyOwnerCanSetFeeValues(address randomAddress) public {
        vm.assume(randomAddress != address(0) && randomAddress != owner);
        assertEq(manager.performanceFee(), 0);
        assertEq(manager.minDebtAmount(), 0);
        assertEq(manager.withdrawalFeeRate(), 0);
        uint256 newPerformanceFee = 100;
        uint256 newMinDebtAmount = 1e5;
        uint256 newWithdrawalFeeRate = 200;
        //checking that setting performance fee reverts
        vm.startPrank(randomAddress);
        vm.expectRevert();
        manager.setPerformanceFee(newPerformanceFee);
        vm.stopPrank();
        //checking that setting withdrawalfee rate reverts
        vm.startPrank(randomAddress);
        vm.expectRevert();
        manager.setwithdrawalFeeRate(newWithdrawalFeeRate);
        vm.stopPrank();
        //checking that setting min debt amount reverts
        vm.startPrank(randomAddress);
        vm.expectRevert();
        manager.setMinDebtAmount(newMinDebtAmount);
        vm.stopPrank();
        //assert that it remained the same after trying to set it
        assertEq(manager.performanceFee(), 0);
        assertEq(manager.minDebtAmount(), 0);
        assertEq(manager.withdrawalFeeRate(), 0);
    }

    function testCheckTusdOracle(bool updated) public {
        uint256 price = tUSDOracle.price();
        tUSDOracle.setUpdated(updated);
        if (!updated) {
            vm.expectRevert(IManager.IManager__Stale.selector);
            uint256 staleRate = manager.getTusdExchangeRate();
            assertEq(staleRate, 0);
        } else {
            uint256 goodRate = manager.getTusdExchangeRate();
            assertEq(goodRate, price);
        }
    }

    function testTusdOracleWhenPriceIsZero() public {
        tUSDOracle.setPrice(0);
        vm.expectRevert(IManager.IManager__ZeroRate.selector);
        uint256 badRate = manager.getTusdExchangeRate();
        assertEq(badRate, 0);
    }
}
