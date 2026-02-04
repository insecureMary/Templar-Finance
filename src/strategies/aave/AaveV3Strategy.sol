// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAToken} from "../../../lib/aave-v3-core/contracts/interfaces/IAToken.sol";
import {IPool} from "../../../lib/aave-v3-core/contracts/interfaces/IPool.sol";
import {IRewardsController} from "../../../lib/aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol";
import {IStrategy} from "../../interfaces/core/IStrategy.sol";

abstract contract AaveV3Strategy is IStrategy {
    mapping(address recipient => IStrategy.RecipientInfo info) public override recipients;
    address public feemanager;
}
