// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;
import {Test} from "../../lib/forge-std/src/Test.sol";
import {Setup} from "../setup/Setup.t.sol";

contract TusdManagerTest is Test, Setup {
    function setUp() public {
        Setup.initialize();
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
}
