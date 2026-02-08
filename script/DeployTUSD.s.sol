//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {TemplarUsd} from "../src/core/TemplarUsd.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract DeployTUSD is Script {
    address initialOwner = vm.envAddress("INITIAL_OWNER");
    address manager = vm.envAddress("MANAGER");

    function run() external {
        vm.startBroadcast();
        TemplarUsd tusd = new TemplarUsd(initialOwner, manager);
        vm.stopBroadcast();

        console.log("Templar USD deployed at:", address(tusd));
    }
}
