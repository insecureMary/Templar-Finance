// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IManager} from "./IManager.sol";

/**
 * @title IAccountManager
 * @notice Interface for the AccountManager contract.
 */

interface IAccountManager {
    //EVENTS
    event AccountCreated(address indexed account, address indexed owner);

    event Deposit(address indexed account, address indexed token, uint256 indexed amountDeposited);

    event Borrowed(address indexed account, address indexed token, uint256 indexed amountBorrowed, bool mintedToUser);

    event Repaid(address indexed account, address indexed token, uint256 indexed amountBorrowed, bool repaidFromUser);

    event Withdrawal(address indexed account, address indexed token, uint256 indexed amountWithdrawn, uint256 withdrawFee);

    //ERRORS
    error IAccountManager__ZeroAddressInput();
    error IAccountManager__AccountAlreadyExists();
    error IAccountManager__ContractNotWhitelisted();
    error IAccountManager__ZeroAmountInput();
    error IAccountManager__AccountDoesNotExist();
    error IAccountManager__TokenNotWhitelisted();
    error IAccountManager__InsufficientBalance();
    error IAccountManager__BorrowLimitExceeded();
    error IAccountManager__CannotWithdrawToken();

    //USER VIEW FUNCTIONS
    function userToAccount(address _user) external view returns (address);
    function accountToUser(address _account) external view returns (address);
    function isAccount(address _account) external view returns (bool);
    function accountDummyImpl() external view returns (address);
    function manager() external view returns (IManager);

    //USER STATE-CHANGING FUNCTIONS
    /**
     * @notice Creates an account for the msg.sender or on behalf of the msg.sender by a whitelisted contract
     * @return address The address of the newly created account
     * @dev Reverts if the msg.sender already has an account, msg.sender must be EOA or a whitelisted contracts
     */
    function createAccount() external returns (address);

    /**
     * @notice Deposits collateral into the user's account
     * @param _token The address of the token to deposit
     * @param _amount The amount of the token to deposit
     * @dev Reverts if the token is not whitelisted or amount is zero, or if the user does not have an account
     */
    function deposit(address _token, uint256 _amount) external;

    /**
     * @notice Withdraws collateral from the user's account
     * @param _token The address of the token to withdraw
     * @param _amount The amount of the token to withdraw
     * @dev Reverts if the token is not whitelisted, amount is zero, user does not have an account, or if withdrawal would violate borrow limits or trigger liquidation
     */
    function withdraw(address _token, uint256 _amount) external;

    /**
     * @notice Borrows TUSD against the user's collateral
     * @param _token The address of the token to borrow
     * @param _amount The amount of the token to borrow
     * @param _minTusdToMint The minimum amount of TUSD to mint
     * @param mintToUserDirectly If true, mints TUSD directly to the user, else to the account
     * @dev Reverts if the token is not whitelisted, amount is zero, user does not have an account, or if borrowing would violate borrow limits
     */
    function borrow(address _token, uint256 _amount, uint256 _minTusdToMint, bool mintToUserDirectly) external;

    /**
     * @notice Repays borrowed TUSD from the user's account
     * @param _token The address of the token to repay
     * @param _amount The amount of the token to repay
     * @param repayFromUserDirectly If true, collects TUSD directly from the user, else from the account
     * @dev Reverts if the token is not whitelisted, amount is zero, user does not have an account, or if there is insufficient borrowed balance to repay the specified amount
     */
    function repay(address _token, uint256 _amount, bool repayFromUserDirectly) external;

    //ADMIN FUNCTIONS
    /**
     * @notice Toggles the paused state of the AccountManager contract
     */
    function togglePause() external;
}
