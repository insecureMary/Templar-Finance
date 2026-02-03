// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IManager} from "./IManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITemplarUsd {
    //EVENTS
    event MaxMintLimitUpdated(uint256 oldMaxMintLimit, uint256 newMaxMintLimit);
    event ManagerChangeRequested(address indexed newManager);
    event ManagerChanged(address indexed oldManager, address indexed newManager);

    //ERRORS
    error ITemplarUsd__ZeroInputNotAllowed();
    error ITemplarUsd__InvalidAmount();
    error ITemplarUsd__UnauthorizedCall();
    error ITemplarUsd__InvalidManagerAddress();
    error ITemplarUsd__TempManagerAlreadySet();
    error ITemplarUsd__SupplyCapExceeded();

    // VIEW FUNCTIONS
    function manager() external view returns (IManager);
    function maxMintLimit() external view returns (uint256);

    // STATE MODIFYING FUNCTIONS
    function updateMaxMintLimit(uint256 newMaxMintLimit) external;
    function mint(address account, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}
