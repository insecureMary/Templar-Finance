// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ICollateralManager} from "../interfaces/core/ICollateralManager.sol";

contract collateralManager is ICollateralManager {
    //MAPPINGS
    mapping(address account => uint256 amount) public collateralDeposited;

    function depositCollateral(address account, uint256 amount) external {
        collateralDeposited[account] += amount;
        emit CollateralDeposited(account, amount, address(this));
    }
}
