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

    function testOnlyMinterOrOwnerCanMintAndUpdatesBalances() public {
        address newReceiptToken = testCanCloneReceiptToken();

        // unauthorized caller cannot mint
        vm.startPrank(bob);
        vm.expectRevert(IReceiptToken.IReceiptToken__UnauthorizedCall.selector);
        IReceiptToken(newReceiptToken).mint(bob, 1 * ETHER);
        vm.stopPrank();

        // minter can mint
        uint256 amt1 = 10 * ETHER;
        uint256 supplyBefore = IERC20Metadata(newReceiptToken).totalSupply();
        vm.prank(alice);
        IReceiptToken(newReceiptToken).mint(bob, amt1);
        assertEq(IERC20Metadata(newReceiptToken).balanceOf(bob), amt1);
        assertEq(IERC20Metadata(newReceiptToken).totalSupply(), supplyBefore + amt1);

        // owner can also mint
        uint256 amt2 = 5 * ETHER;
        vm.prank(owner);
        IReceiptToken(newReceiptToken).mint(alice, amt2);
        assertEq(IERC20Metadata(newReceiptToken).balanceOf(alice), amt2);
    }

    function testOnlyMinterOrOwnerCanBurnAndUpdatesBalances() public {
        address newReceiptToken = testCanCloneReceiptToken();

        // mint some tokens to bob first
        uint256 starting = 20 * ETHER;
        vm.prank(alice);
        IReceiptToken(newReceiptToken).mint(bob, starting);
        assertEq(IERC20Metadata(newReceiptToken).balanceOf(bob), starting);

        // unauthorized cannot burn
        vm.startPrank(bob);
        vm.expectRevert(IReceiptToken.IReceiptToken__UnauthorizedCall.selector);
        IReceiptToken(newReceiptToken).burn(bob, 1 * ETHER);
        vm.stopPrank();

        // minter can burn from bob
        uint256 burn1 = 5 * ETHER;
        uint256 supplyBefore = IERC20Metadata(newReceiptToken).totalSupply();
        vm.prank(alice);
        IReceiptToken(newReceiptToken).burn(bob, burn1);
        assertEq(IERC20Metadata(newReceiptToken).balanceOf(bob), starting - burn1);
        assertEq(IERC20Metadata(newReceiptToken).totalSupply(), supplyBefore - burn1);

        // owner can burn the rest
        vm.prank(owner);
        IReceiptToken(newReceiptToken).burn(bob, starting - burn1);
        assertEq(IERC20Metadata(newReceiptToken).balanceOf(bob), 0);
    }
}
