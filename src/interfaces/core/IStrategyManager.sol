// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IStrategyManager {
    //errors
    error ZeroAmount();
    error ZeroAddress();
    error InactiveStrategy();
    error InvalidToken();
    error SlippageRevert();
    error AccountIsLiquidatable();
    error SameData();
    error UnAuthorized();
    error AlreadyWhitelisted();

    //events
    event Invested(address account, address investor, address token, address strategy, uint256 amount, uint256 tokenOutAmount, uint256 tokenInAmount);

    struct StrategyInfo {
        uint256 performanceFee;
        bool active;
        bool whitelisted;
    }

    struct MoveInvestmentData {
        address strategyFrom;
        address strategyTo;
        uint256 shares;
        bytes dataFrom;
        bytes dataTo;
        uint256 strategyToMinSharesAmountOut;
    }

    function claimInvestment(
        address account,
        address collateral,
        address strategy,
        uint256 shares,
        bytes memory strategyData
    )
        external
        returns (uint256 withdrawnAmount, uint256 initialInvestment, int256 yield, uint256 fee);
}
