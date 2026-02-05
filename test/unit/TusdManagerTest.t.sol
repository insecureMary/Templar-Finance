// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;
import {Test} from "../../lib/forge-std/src/Test.sol";
import {Setup} from "../setup/Setup.t.sol";

contract TusdManagerTest is Test, Setup {
    function setUp() public {
        Setup.initialize();
    }

    function testDepositWillPassWhenSetupIsCorrect() public {
        //deal alice some collateral and deposit straightup
        token1Oracle.setUpdated(true);
        depositForUser(alice, address(token1), 1e18);
        token1Oracle.setUpdated(true);
    }
}
