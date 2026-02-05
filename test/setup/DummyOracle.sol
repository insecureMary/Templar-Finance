// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IOracle} from "../../src/interfaces/oracle/IOracle.sol";

contract DummyOracle is IOracle {
    address public underlyingAsset;
    string public name;
    string public symbol;
    uint256 public price;
    bool public updated;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        price = 1e18;
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function setPriceForLiquidation() external {
        price = 1e6;
    }

    function setUpdated(bool _updated) external {
        updated = _updated;
    }

    function peek(bytes calldata data) external view returns (bool, uint256) {
        return (updated, price);
    }
}
