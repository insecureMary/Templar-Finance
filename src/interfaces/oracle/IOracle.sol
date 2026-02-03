// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IOracle {
    //function getPriceInUSD(address asset) external view returns (uint256);

    function peek(bytes32 data) external view returns (bool, uint256);
}
