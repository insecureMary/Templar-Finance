// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {console} from "forge-std/console.sol";

import {IReceiptToken, IReceiptTokenFactory} from "../../src/interfaces/core/IReceiptToken.sol";
import {Setup} from "../setup/Setup.t.sol";

contract ReceiptTest is Setup {
    function setUp() public {
        initialize();
    }

    function testConstructorPassesCorrectly() public view {
        assertEq(address(receiptTokenImpl), receiptTokenFactory.referenceImpl());
    }

    function isClone(address _clone) public view returns (bool) {
        // Minimal proxy bytecode:
        // 363d3d373d3d3d363d73 <20 bytes> 5af43d82803e903d91602b57fd5bf3
        // The implementation address is stored after the first 10 bytes.

        bytes20 implementationAddress;
        assembly {
            // Read 20 bytes at offset 10 (bytes 10-30)
            extcodecopy(_clone, 0, 10, 20)
            implementationAddress := mload(0)
        }

        return address(implementationAddress) == receiptTokenFactory.referenceImpl();
    }

    function testCanChangeReferenceImpl() public {
        //act
        vm.prank(owner);
        receiptTokenFactory.changeReferenceImpl(address(dummyImpl));
        //assert
        assertEq(address(dummyImpl), receiptTokenFactory.referenceImpl());
        assert(address(receiptTokenImpl) != receiptTokenFactory.referenceImpl());
    }

    function testOnlyOwnerCanChangeReferenceImpl() public {
        vm.startPrank(alice);
        vm.expectRevert();
        receiptTokenFactory.changeReferenceImpl(address(dummyImpl));
        vm.stopPrank();
        assertEq(address(receiptTokenImpl), receiptTokenFactory.referenceImpl());
        assert(address(dummyImpl) != receiptTokenFactory.referenceImpl());
    }

    function testIfNewReferenceIsValidImpl() public {
        //trying to implement with address 0
        vm.startPrank(owner);
        vm.expectRevert(IReceiptTokenFactory.IReceiptTokenFactory__ZeroAddressInput.selector);
        receiptTokenFactory.changeReferenceImpl(address(0));
        vm.stopPrank();

        //trying to implement with a non-smart contract address
        vm.startPrank(owner);
        vm.expectRevert(IReceiptTokenFactory.IReceiptTokenFactory__InvalidReceiptTokenImplementation.selector);
        receiptTokenFactory.changeReferenceImpl(alice);
        vm.stopPrank();

        //assert the default value is still the same
        assertEq(address(receiptTokenImpl), receiptTokenFactory.referenceImpl());
    }

    function testCanCloneReceiptToken() public returns (address newReceiptToken) {
        //act
        vm.prank(owner);
        newReceiptToken = receiptTokenFactory.cloneReceiptToken("newReceipt", "NRCPT", alice, owner);
        //assert
        assertTrue(newReceiptToken != address(0));
        assertGt(newReceiptToken.code.length, 0);
        assertTrue(isClone(newReceiptToken));
    }

    //ReceiptToken test
    function testInitalizeWorks() public {
        address newReceiptToken = testCanCloneReceiptToken();
        assertEq(keccak256(bytes("newReceipt")), keccak256(bytes(IERC20Metadata(newReceiptToken).name())));
        assertEq(IReceiptToken(newReceiptToken).minter(), alice);
    }

    function testCanChangeMinter() public {
        address newReceiptToken = testCanCloneReceiptToken();
        vm.startPrank(owner);
        IReceiptToken(newReceiptToken).setNewMinter(bob);
        vm.stopPrank();
        assertEq(IReceiptToken(newReceiptToken).minter(), bob);
    }
}
