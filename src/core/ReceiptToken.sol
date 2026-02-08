// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IReceiptTokenFactory} from "../interfaces/core/IReceiptToken.sol";
import {IReceiptToken} from "../interfaces/core/IReceiptToken.sol";

contract ReceiptTokenFactory is IReceiptTokenFactory, Ownable2Step {
    address public referenceImpl;

    //Constructor
    constructor(address _initialOwner, address _referenceImpl) Ownable(_initialOwner) {
        require(_referenceImpl.code.length > 0, IReceiptTokenFactory__InvalidReceiptTokenImplementation());
        referenceImpl = _referenceImpl;
    }

    //STATE-CHANGING FUNCTIONS
    function changeReferenceImpl(address _newImpl) external onlyOwner {
        if (_newImpl == address(0)) {
            revert IReceiptTokenFactory__ZeroAddressInput();
        }
        if (_newImpl.code.length == 0) {
            revert IReceiptTokenFactory__InvalidReceiptTokenImplementation();
        }
        referenceImpl = _newImpl;
        emit ReceiptTokenImplUpdated(_newImpl);
    }

    function cloneReceiptToken(string memory _name, string memory _symbol, address _minter, address _owner) external returns (address newReceiptToken) {
        newReceiptToken = Clones.cloneDeterministic(referenceImpl, bytes32(keccak256(abi.encode(msg.sender))));
        IReceiptToken(newReceiptToken).initialize(_name, _symbol, _minter, _owner);

        emit ReceiptTokenCreated(newReceiptToken, msg.sender, _name, _symbol);
    }
}

contract ReceiptToken is IReceiptToken, OwnableUpgradeable, ERC20Upgradeable, ReentrancyGuard {
    address public override minter;

    constructor() {
        _disableInitializers();
    }

    //MODIFIERS
    modifier onlyOwnerOrMinter() {
        if (msg.sender != minter && msg.sender != owner()) {
            revert IReceiptToken__UnauthorizedCall();
        }
        _;
    }

    //INITIALIZER
    function initialize(string memory _name, string memory _symbol, address _minter, address _owner) external override initializer {
        __ERC20_init(_name, _symbol);
        minter = _minter;
        _transferOwnership(_owner);
    }

    //STATE-CHANGING FUNCTIONS
    function mint(address _owner, uint256 _amount) external override onlyOwnerOrMinter nonReentrant {
        _mint(_owner, _amount);
    }

    function burn(address _owner, uint256 _amount) external override onlyOwnerOrMinter nonReentrant {
        _burn(_owner, _amount);
    }

    function setNewMinter(address _minter) external override onlyOwnerOrMinter {
        address oldMinter = minter;
        minter = _minter;
        emit MinterUpdated(oldMinter, _minter);
    }
}
