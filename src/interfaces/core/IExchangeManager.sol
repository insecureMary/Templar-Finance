// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IExchangeManager {
    function swapExactOutputMultihop(address collateral, bytes memory swapPath, address account, uint256 deadline, uint256 amount, uint256 slippage) external view returns (uint256);
}
