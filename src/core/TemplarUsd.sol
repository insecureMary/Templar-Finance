// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import {IManager} from "../interfaces/core/IManager.sol";
import {ITemplarUsd} from "../interfaces/core/ITemplarUsd.sol";

contract TemplarUsd is ITemplarUsd, ERC20, ERC20Permit, Ownable2Step {
    //STATE VARIABLES
    IManager public override manager;
    uint256 public override maxMintLimit;
    address public tempManager;

    constructor(address _initialOwner, address _manager) Ownable(_initialOwner) ERC20("Templar USD", "TUSD") ERC20Permit("Templar USD") {
        require(_manager != address(0), ITemplarUsd__ZeroInputNotAllowed());
        manager = IManager(_manager);
        maxMintLimit = 1_000_000 * 10 ** decimals(); //Equivalent to 1 million TUSD
    }

    //MODIFIERS
    modifier validAmount(uint256 _amount) {
        if (_amount == 0) {
            revert ITemplarUsd__ZeroInputNotAllowed();
        }
        _;
    }

    modifier onlyTusdManager() {
        if (msg.sender != address(manager.templarUsdManager())) {
            revert ITemplarUsd__UnauthorizedCall();
        }
        _;
    }

    //STATE CHANGERS
    function updateMaxMintLimit(uint256 _newMaxMintLimit) external override onlyOwner validAmount(_newMaxMintLimit) {
        uint256 oldMaxMintLimit = maxMintLimit;
        maxMintLimit = _newMaxMintLimit;
        emit MaxMintLimitUpdated(oldMaxMintLimit, _newMaxMintLimit);
    }

    function requestChangeManager(address _newManager) external onlyOwner {
        require(_newManager != address(manager), ITemplarUsd__InvalidManagerAddress());
        require(_newManager != address(0), ITemplarUsd__ZeroInputNotAllowed());
        require(tempManager == address(0), ITemplarUsd__TempManagerAlreadySet());

        tempManager = _newManager;
        emit ManagerChangeRequested(_newManager);
    }

    function acceptChangeManager() external {
        require(msg.sender == tempManager || msg.sender == owner(), ITemplarUsd__UnauthorizedCall());
        require(tempManager != address(0), ITemplarUsd__InvalidManagerAddress());
        address oldManager = address(manager);
        manager = IManager(tempManager);
        tempManager = address(0);
        emit ManagerChanged(oldManager, address(manager));
    }

    function mint(address _account, uint256 _amount) external override onlyTusdManager validAmount(_amount) {
        uint256 currentSupply = totalSupply();
        uint256 newSupply = currentSupply + _amount;
        if (newSupply > maxMintLimit) {
            revert ITemplarUsd__SupplyCapExceeded();
        }
        _mint(_account, _amount);
    }

    function burn(uint256 _amount) external override onlyTusdManager validAmount(_amount) {
        _burn(msg.sender, _amount);
    }

    function burnFrom(address _account, uint256 _amount) external override onlyTusdManager validAmount(_amount) {
        _burn(_account, _amount);
    }
}
