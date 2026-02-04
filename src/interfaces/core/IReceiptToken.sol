// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IReceiptTokenFactory {
    //EVENTS
    event ReceiptTokenImplUpdated(address indexed newImplementation);
    event ReceiptTokenCreated(address indexed receiptTokenAddress, address indexed receiptTokenCreator, string name, string symbol);

    //ERRORS
    error IReceiptTokenFactory__ZeroAddressInput();
    error IReceiptTokenFactory__ReceiptTokenAlreadyExists();
    error IReceiptTokenFactory__InvalidReceiptTokenImplementation();

    //VIEWS
    function referenceImpl() external view returns (address);

    //STATE-CHANGING FUNCTIONS
    function changeReferenceImpl(address _newImpl) external;
    function cloneReceiptToken(string memory _name, string memory _symbol, address _minter, address _owner) external returns (address);
}

interface IReceiptToken is IERC20, IERC20Metadata, IERC20Errors {
    //EVENTS
    event MinterUpdated(address oldMinter, address newMinter);

    //ERRORS
    error IReceiptToken__UnauthorizedCall();

    //STATE-CHANGING FUNCTIONS
    function initialize(string memory _name, string memory _symbol, address _minter, address _owner) external;

    function mint(address _owner, uint256 _amount) external;
    function burn(address _owner, uint256 _amount) external;
    function setNewMinter(address _minter) external;
}
