// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IOracle {
    function underlyingAsset() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function peek(bytes calldata data) external view returns (bool, uint256);
    function price() external view returns (uint256);
}
