//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AccountManager} from "../src/core/AccountManager.sol";
import {IAccountManager} from "../src/interfaces/core/IAccountManager.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract DeployAccountManager is Script {
    address initialOwner = vm.envAddress("INITIAL_OWNER");
    address manager = vm.envAddress("MANAGER");

    function run() external {
        vm.startBroadcast();
        IAccountManager accountManager = new AccountManager(initialOwner, manager);
        vm.stopBroadcast();

        console.log("AccountManager deployed at:", address(accountManager));
    }
}
