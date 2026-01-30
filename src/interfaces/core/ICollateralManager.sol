// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface ICollateralManager {
    //events
    event CollateralDeposited(address indexed account, uint256 indexed amount, address token);
}
