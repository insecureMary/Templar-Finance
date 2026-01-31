// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ICollateralManager} from "../interfaces/core/ICollateralManager.sol";

contract collateralManager is ICollateralManager {
    //MAPPINGS
    mapping(address account => uint256 amount) public collateralDeposited;
    mapping(address account => uint256 amount) public borrowed;

    CollateralManagerConfig private config;

    function depositCollateral(address account, uint256 amount) external {
        collateralDeposited[account] += amount;
        emit CollateralDeposited(account, amount, address(this));
    }

    function withdrawCollateral(address account, uint256 amount) external {
        collateralDeposited[account] -= amount;
        emit CollateralWithdrawn(account, amount, address(this));
    }

    function borrow(address account, uint256 amount) external {
        borrowed[account] += amount;
        emit TUSDBorrowed(account, amount, address(this));
    }

    function repay(address account, uint256 amount) external {
        borrowed[account] -= amount;
        emit TUSDRepayed(account, amount, address(this));
    }

    function getExchangeRate() public view returns (uint256 rate) {}

    function getConfig() public returns (CollateralManagerConfig memory) {}
}
