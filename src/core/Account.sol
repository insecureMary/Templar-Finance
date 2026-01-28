// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAccount} from "../interfaces/core/IAccount.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {IStrategyManager} from "../interfaces/core/IStrategyManager.sol";
import {MathOperations} from "../libraries/MathOperations.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Account {}
