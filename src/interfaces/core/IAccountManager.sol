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
    function createAccount() external returns (address);

    function deposit(address _token, uint256 _amount) external;

    function withdraw(address _token, uint256 _amount) external;

    function borrow(address _token, uint256 _amount, uint256 _minTusdToMint, bool mintToUserDirectly) external returns (uint256 tUsdMinted);

    function repay(address _token, uint256 _amount, bool repayFromUserDirectly) external;

    //ADMIN FUNCTIONS
    function togglePause() external;
}
