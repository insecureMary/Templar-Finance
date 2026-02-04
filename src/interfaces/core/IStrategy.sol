// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IStrategy {
    function recipients(address _recipient) external view returns (uint256 investedAmount, uint256 totalShares);

    function tokenIn() external view returns (address);
    function deposit(address token, uint256 amount, address account, bytes calldata data) external returns (uint256, uint256);
    function withdraw(uint256, address, address, bytes calldata) external returns (uint256, uint256, int256, uint256);
    function claimRewards(address account, bytes calldata data) external returns (uint256[] memory rewards, address[] memory token);

    struct RecipientInfo {
        uint256 investedAmount;
        uint256 totalShares;
    }
}
