// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface ILiquidationManager {
    //errors
    error ZeroAmountToLiq();
    error ZeroAddress();
    error InactiveToken();
    error Insolvent();
    error InvalidAmount();
    error InvalidSlippage();
    error ZeroAmount();
    error SlippageRevert();
    error NotEnoughCollateral();

    struct Swapdata {
        bytes swapPath;
        uint256 deadline;
        uint256 amountInMaximum;
        uint256 slippage;
    }

    struct Strategiesdata {
        bool useAccountBalance;
        address[] strategies;
        bytes[] strategiesData;
    }
}
