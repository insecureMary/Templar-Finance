// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAToken} from "../../../lib/aave-v3-core/contracts/interfaces/IAToken.sol";
import {IPool} from "../../../lib/aave-v3-core/contracts/interfaces/IPool.sol";
import {IRewardsController} from "../../../lib/aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol";
import {IStrategy} from "../../interfaces/core/IStrategy.sol";

abstract contract AaveV3Strategy is IStrategy {
    mapping(address recipient => IStrategy.RecipientInfo info) public override recipients;
    address public feeManager;
    address public tokenIn;

    constructor(address _feeManager, address _tokenIn) {
        feeManager = _feeManager;
        tokenIn = _tokenIn;
    }

    function deposit(address asset, uint256 amount, address recipient, bytes calldata data) external returns (uint256, uint256) {}
}
