// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IManager} from "../interfaces/core/IManager.sol";
import {ITUSDManager} from "../interfaces/core/ITUSDManager.sol";
import {ITemplarUsd} from "../interfaces/core/ITemplarUsd.sol";

contract TUSDManager is ITUSDManager {
    //This maps token address to it's own specific tokenManager registry info
    mapping(address token => tokenRegistryInfo) public tokenRegistry;

    /* This maps token address to total borrowed TUSD against that token as collateral
     */
    mapping(address token => uint256 totalBorrowedTUSD) public totalBorrowedTUSD;

    /**
     * @notice The Templar USD contract address
     */
    ITemplarUsd public immutable TUSD;

    /**
     * @notice The Manager contract address, control all protocol wide settings
     */
    IManager public manager;

    constructor(address _TUSD, address _manager) {
        TUSD = ITemplarUsd(_TUSD);
        manager = IManager(_manager);
    }
}
