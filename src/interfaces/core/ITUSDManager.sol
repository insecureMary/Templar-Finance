// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface ITUSDManager {
    //errors
    error InactiveToken();
    error Insolvent();
    error Unauthorized();
    error ZeroAmount();
    error MintAmountIsLessThanSlippage();
    error ZeroAddress();
    error WrongAmount();

    struct tokenRegistryInfo {
        bool isActive;
        address deployedAt;
    }

    //functions
    function depositCollateral(address account, address token, uint256 amount) external;
}
