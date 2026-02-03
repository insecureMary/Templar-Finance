// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAccountManager} from "../interfaces/core/IAccountManager.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {IStrategy} from "../interfaces/core/IStrategy.sol";
import {IStrategyManager} from "../interfaces/core/IStrategyManager.sol";
import {ITUSDManager} from "../interfaces/core/ITUSDManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract StrategyManager is IStrategyManager, Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address strategy => StrategyInfo info) public strategyInfo;
    mapping(address account => EnumerableSet.AddressSet strategies) private accountToStrategy;
    IManager public immutable appManager;

    constructor(address owner, address manager) Ownable(owner) {
        appManager = IManager(manager);
    }

    function invest(address strategy, address token, uint256 amount, uint256 minSharesAmountOut, bytes calldata data) external nonReentrant returns (uint256 tokenOutAmount, uint256 tokenInAmount) {
        //sanity checks
        require(strategy != address(0), ZeroAddress());
        require(token != address(0), ZeroAddress());
        require(amount > 0, ZeroAmount());
        address account = getAccountManager().userToAccount(msg.sender);
        require(account != address(0), ZeroAddress());
        require(strategyInfo[strategy].active, InactiveStrategy());
        require(IStrategy(strategy).tokenIn() == token, InvalidToken());

        (tokenOutAmount, tokenInAmount) = _invest(account, token, strategy, amount, minSharesAmountOut, data);
        emit Invested(account, msg.sender, token, strategy, amount, tokenOutAmount, tokenInAmount);
        return (tokenOutAmount, tokenInAmount);
    }

    function moveInvestment(address token, MoveInvestmentData calldata data) external nonReentrant returns (uint256 tokenOutAmount, uint256 tokenInAmount) {
        //sanity checks
        address account = getAccountManager().userToAccount(msg.sender);
        require(account != address(0), ZeroAddress());
        require(data.strategyFrom != data.strategyTo, SameData());
        require(strategyInfo[data.strategyTo].active, InactiveStrategy());
        require(IStrategy(data.strategyFrom).tokenIn() == token, InvalidToken());
        require(IStrategy(data.strategyTo).tokenIn() == token, InvalidToken());

        //first claim from the from strategy
        (uint256 claimResult,,,) = _claimInvestment(account, token, data.strategyFrom, data.shares, data.dataFrom);
        //Then invest in the other
        (tokenOutAmount, tokenInAmount) = _invest(account, token, data.strategyTo, claimResult, data.strategyToMinSharesAmountOut, data.dataTo);
    }

    function claimInvestment(
        address account,
        address token,
        address strategy,
        uint256 shares,
        bytes calldata strategyData
    )
        external
        nonReentrant
        onlyManagers(account)
        returns (uint256 withdrawnAmount, uint256 initialInvestment, int256 yield, uint256 fee)
    {
        address _account = getAccountManager().userToAccount(msg.sender);
        require(_account != address(0), ZeroAddress());

        (withdrawnAmount, initialInvestment, yield, fee) = _claimInvestment(account, token, strategy, shares, strategyData);

        //TO - DO: add event
    }

    function claimReward(address strategy, bytes calldata data) external nonReentrant returns (uint256[] memory rewards, address[] memory tokens) {
        address account = getAccountManager().userToAccount(msg.sender);
        require(account != address(0), ZeroAddress());

        (rewards, tokens) = IStrategy(strategy).claimRewards(account, data);

        for (uint256 i = 0; i < rewards.length; i++) {
            _accrueRewards(tokens[i], rewards[i], account);
        }
    }

    function addStrategy(address _strategy) public onlyOwner {
        require(!strategyInfo[_strategy].whitelisted, AlreadyWhitelisted());
        StrategyInfo memory info = StrategyInfo(0, false, false);
        info.performanceFee = appManager.performanceFee();
        info.active = true;
        info.whitelisted = true;

        strategyInfo[_strategy] = info;
    }

    function updateStrategy(address _strategy, StrategyInfo calldata _info) external onlyOwner {
        strategyInfo[_strategy] = _info;
    }

    function _invest(address account, address token, address strategy, uint256 amount, uint256 minShareAmountOut, bytes calldata data)
        internal
        returns (uint256 tokenOutAmount, uint256 tokenInAmount)
    {
        (tokenOutAmount, tokenInAmount) = IStrategy(strategy).deposit(token, amount, account, data);
        require(tokenOutAmount != 0 && tokenOutAmount >= minShareAmountOut, SlippageRevert());
        require(!getTusdManager().isLiquidatable(token, account), AccountIsLiquidatable());
        accountToStrategy[account].add(strategy);
    }

    function _accrueRewards(address token, uint256 amount, address account) internal {
        if (amount > 0) {
            ITUSDManager manager = getTusdManager();
            (bool active, address tokenRegistry) = manager.tokenRegistryInfo(token);

            if (tokenRegistry != address(0) && active) {
                manager.depositCollateral(account, token, amount);
            }
        }
    }

    function _claimInvestment(address account, address token, address strategy, uint256 amount, bytes calldata data) internal returns (uint256, uint256, int256, uint256) {
        (uint256 withdrawnAmount, uint256 initialInvestment, int256 yield, uint256 fee) = IStrategy(strategy).withdraw(amount, account, token, data);
        require(withdrawnAmount > 0, ZeroAmount());

        ITUSDManager manager = getTusdManager();

        //ascertain yield
        if (yield > 0) {
            manager.depositCollateral(account, token, uint256(yield));
        } else if (yield < 0) {
            manager.withdrawCollateral(account, token, uint256(-yield));
        }

        if (appManager.liquidationManager() != msg.sender) {
            require(!manager.isLiquidatable(token, account), AccountIsLiquidatable());
        }

        uint256 remainingShares = 0;
        (, remainingShares) = IStrategy(strategy).recipients(account);
        if (remainingShares == 0) accountToStrategy[account].remove(strategy);

        return (withdrawnAmount, initialInvestment, yield, fee);
    }

    function getAccountManager() private view returns (IAccountManager) {
        return IAccountManager(appManager.accountManager());
    }

    function getTusdManager() private view returns (ITUSDManager) {
        return ITUSDManager(appManager.templarUsdManager());
    }

    modifier onlyManagers(address account) {
        require(appManager.liquidationManager() == msg.sender || getAccountManager().userToAccount(account) == msg.sender, UnAuthorized());
        _;
    }

    function renounceOwnership() public pure override {
        revert();
    }
}
