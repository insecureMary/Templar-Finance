// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IStrategyManager {
    function claimInvestment(
        address account,
        address collateral,
        address strategy,
        uint256 shares,
        bytes memory strategyData
    )
        external
        returns (uint256 withdrawnAmount, uint256 initialInvestment, int256 yield, uint256 fee);
}
