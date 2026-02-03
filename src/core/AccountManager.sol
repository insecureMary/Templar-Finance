// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IAccount} from "../interfaces/core/IAccount.sol";
import {IAccountManager} from "../interfaces/core/IAccountManager.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {ITUSDManager} from "../interfaces/core/ITUSDManager.sol";
import {MathOperations} from "../libraries/MathOperations.sol";
import {Account} from "./Account.sol";

contract AccountManager is IAccountManager, Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    //STATE VARIABLES
    IManager public immutable override manager;
    address public immutable override accountDummyImpl;
    mapping(address user => address account) public userToAccount;
    mapping(address account => address user) public accountToUser;
    mapping(address account => bool exists) public isAccount;

    //CONSTRUCTOR
    constructor(address _initialOwner, address _manager) Ownable(_initialOwner) {
        if (_initialOwner == address(0) || _manager == address(0)) {
            revert IAccountManager__ZeroAddressInput();
        }
        accountDummyImpl = address(new Account());
        manager = IManager(_manager);
    }

    //MODIFIERS
    modifier isValidAddress(address addressToCheck) {
        require(addressToCheck != address(0), IAccountManager__ZeroAddressInput());
        _;
    }

    modifier isValidAmount(uint256 amountToCheck) {
        require(amountToCheck > 0, IAccountManager__ZeroAmountInput());
        _;
    }

    modifier isValidAccount(address accountToCheck) {
        require(isAccount[accountToCheck] == true, IAccountManager__AccountDoesNotExist());
        _;
    }

    modifier isValidToken(address tokenToCheck) {
        require(manager.isTokenWhitelisted(tokenToCheck), IAccountManager__TokenNotWhitelisted());
        _;
    }

    //USER STATE-CHANGING FUNCTIONS

    function createAccount() external override nonReentrant whenNotPaused returns (address) {
        require(userToAccount[msg.sender] == address(0), IAccountManager__AccountAlreadyExists());
        if (msg.sender != tx.origin) {
            require(manager.isContractWhitelisted(msg.sender), IAccountManager__ContractNotWhitelisted());
        }
        address newAccountAddress = Clones.clone(accountDummyImpl);
        isAccount[newAccountAddress] = true;
        userToAccount[msg.sender] = newAccountAddress;
        accountToUser[newAccountAddress] = msg.sender;

        Account newAccount = Account(newAccountAddress);
        newAccount.initialize(address(manager));
        emit AccountCreated(newAccountAddress, msg.sender);
        return newAccountAddress;
    }

    function deposit(address _token, uint256 _amount) external nonReentrant whenNotPaused isValidToken(_token) isValidAmount(_amount) isValidAccount(userToAccount[msg.sender]) {
        address sender = msg.sender;
        address account = userToAccount[sender];
        _getTUSDManager().depositCollateral(account, _token, _amount);
        IERC20(_token).safeTransferFrom(sender, account, _amount);
        emit Deposit(account, _token, _amount);
    }

    function withdraw(address _token, uint256 _amount) external nonReentrant whenNotPaused isValidToken(_token) isValidAmount(_amount) isValidAccount(userToAccount[msg.sender]) {
        address sender = msg.sender;
        address account = userToAccount[sender];
        require(manager.canWithdrawToken(_token), IAccountManager__CannotWithdrawToken());
        //checking if this token was airdropped or user has actual collateral for the token
        // (, address _tokenRegistry) = _getTUSDManager().sharesRegistryInfo(
        //     _token
        // );
        // if (
        //     _tokenRegistry != address(0) &&
        //     ICollateralManager(_tokenRegistry).collateral(account) > 0
        // ) {
        //     _getTUSDManager().withdrawCollateral(account, _token, _amount);
        // }
        uint256 withdrawalFeeRate = manager.withdrawalFeeRate();
        if (withdrawalFeeRate > 0) {
            uint256 withdrawalFeeAmount = MathOperations.getFeeAbsolute(_amount, withdrawalFeeRate, manager.PRECISION_FACTOR());
            if (withdrawalFeeAmount > 0) {
                //transfer fee to fee recipient
                IERC20(_token).safeTransferFrom(sender, manager.feeRecipient(), withdrawalFeeAmount);
            }
            //transfer net amount to user
            IERC20(_token).safeTransfer(sender, _amount - withdrawalFeeAmount);

            emit Withdrawal(account, _token, _amount, withdrawalFeeAmount);
        } else {
            //transfer full amount to user
            IERC20(_token).safeTransfer(sender, _amount);
            emit Withdrawal(account, _token, _amount, 0);
        }
    }

    function borrow(address _token, uint256 _amount, uint256 _minTusdToMint, bool mintToUserDirectly)
        external
        nonReentrant
        whenNotPaused
        isValidToken(_token)
        isValidAccount(userToAccount[msg.sender])
    {
        address account = userToAccount[msg.sender];
        _getTUSDManager().borrow(account, _token, _amount, _minTusdToMint, mintToUserDirectly);
        emit Borrowed(account, _token, _amount, mintToUserDirectly);
    }

    function repay(address _token, uint256 _amount, bool repayFromUserDirectly) external nonReentrant whenNotPaused isValidToken(_token) isValidAccount(userToAccount[msg.sender]) {
        address sender = msg.sender;
        address account = userToAccount[sender];
        address _burnFrom = repayFromUserDirectly ? sender : account;
        _getTUSDManager().repay(account, _token, _amount, _burnFrom);
        emit Repaid(account, _token, _amount, repayFromUserDirectly);
    }

    //ADMIN FUNCTIONS
    function togglePause() external onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }

    //PRIVATE FUNCTIONS
    function _getTUSDManager() private view returns (ITUSDManager) {
        return ITUSDManager(manager.templarUsdManager());
    }
}
