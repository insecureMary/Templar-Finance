// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IManager} from "../../src/interfaces/core/IManager.sol";
import {Setup} from "../setup/Setup.t.sol";

contract ManagerTest is Setup {
    function setUp() public {
        initialize();
        token1Oracle.setUpdated(true);
    }

    function testManagerContractConstructorWorks() public view {
        assert(address(manager.tUsdOracle()) == address(tUSDOracle));
    }

    function testManagerContractSetups() public view {
        assert(address(receiptTokenFactory) == address(manager.receiptTokenFactory()));
        assert(address(accountManager) == address(manager.accountManager()));
        assert(address(liquidationManager) == address(manager.liquidationManager()));
        assert(address(tusdManager) == address(manager.templarUsdManager()));
        assert(address(strategyManager) == address(manager.strategyManager()));
        assert(feeRecipient == manager.feeRecipient());
        assertTrue(manager.isTokenWhitelisted(address(token1)));
        assertTrue(manager.isTokenWhitelisted(address(token2)));
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

    // function testNonOwnerCannotSetContracts(
    //     address dummyContract,
    //     address dummySetter
    // ) public {
    //     vm.assume(dummyContract != address(0));
    //     vm.assume(dummySetter != address(0) && dummySetter != owner);
    //     vm.startPrank(dummySetter);
    //     vm.expectRevert();
    //     manager.setAccountManager(dummyContract);
    //     vm.stopPrank();
    //     vm.startPrank(dummySetter);
    //     vm.expectRevert();
    //     manager.setAccountManager(dummyContract);
    //     vm.stopPrank();
    //     vm.startPrank(dummySetter);
    //     vm.expectRevert();
    //     manager.setAccountManager(dummyContract);
    //     vm.stopPrank();
    //     vm.startPrank(dummySetter);
    //     vm.expectRevert();
    //     manager.setAccountManager(dummyContract);
    //     vm.stopPrank();
    //     vm.startPrank(dummySetter);
    //     vm.expectRevert();
    //     manager.setAccountManager(dummyContract);
    //     vm.stopPrank();
    // }
}
