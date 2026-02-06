// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAccount} from "../interfaces/core/IAccount.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {IStrategyManager} from "../interfaces/core/IStrategyManager.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Account is IAccount, Initializable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    //STATE VARIABLES
    IManager public manager;

    constructor() {
        _disableInitializers();
    }

    //INITIALIZER
    function initialize(address _manager) public initializer {
        if (_manager == address(0)) {
            revert IAccount__ZeroAddressInput();
        }
        manager = IManager(_manager);
    }

    //STATE-CHANGING FUNCTIONS
    function approve(address _token, address _spender, uint256 _amount) external {
        bool success = IERC20(_token).approve(_spender, _amount);
        require(success, IAccount__FailedToApprove());
    }

    function transfer(address _token, address _to, uint256 _amount) external onlyAllowed {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function genericCall(address _contract, bytes calldata _call) external payable nonReentrant onlyAllowed returns (bool success, bytes memory result) {
        (success, result) = _contract.call{value: msg.value}(_call);
    }

    modifier onlyAllowed() {
        (,, bool isStrategyWhitelisted) = IStrategyManager(manager.strategyManager()).strategyInfo(msg.sender);

        require(msg.sender == manager.accountManager() || msg.sender == manager.liquidationManager() || msg.sender == manager.exchangeManager() || isStrategyWhitelisted, "1000");
        _;
    }
}
