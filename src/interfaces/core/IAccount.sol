// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IManager} from "./IManager.sol";

/**
 * @title IAccount
 * @notice Interface for the Account contract.
 */
interface IAccount {
    //ERRORS
    error IAccount__ZeroAddressInput();
    error IAccount__FailedToApprove();

    //VIEW FUNCTIONS
    function manager() external view returns (IManager);

    //STATE-CHANGING FUNCTIONS
    /**
     * @notice Approves a spender to spend a specified amount of a token on behalf of the account.
     * @param _token The address of the token to approve.
     * @param _spender The address of the spender to approve.
     * @param _amount The amount of the token to approve.
     */
    function approve(address _token, address _spender, uint256 _amount) external;
    function transfer(address _token, address _to, uint256 _amount) external;
    function genericCall(address _contract, bytes calldata _call) external payable returns (bool success, bytes memory result);
}
