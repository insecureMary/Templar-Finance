// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

library MathOperations {
    function getFeeAbsolute(uint256 amount, uint256 feeRate, uint256 precision) internal pure returns (uint256) {
        return (amount * feeRate) / precision;
    }
}
