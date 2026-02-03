// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface ILiquidationManager {
    //errors
    error ZeroAmountToLiq();
    error ZeroAddress();
    error InactiveToken();
    error Insolvent();

    struct Swapdata {
        bytes swapPath;
        uint256 deadline;
        uint256 amountInMaximum;
        uint256 slippage;
    }

    struct Strategiesdata {
        bool useHoldingBalance;
        address[] strategies;
        bytes[] strategiesData;
    }
}
