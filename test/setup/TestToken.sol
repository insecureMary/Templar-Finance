// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TTK") {
        _mint(msg.sender, 1e18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
