// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IStrategy {
    function recipients(address _recipient) external view returns (uint256 investedAmount, uint256 totalShares);
}
