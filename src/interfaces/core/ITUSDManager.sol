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
    error InvalidManagerOrToken();
    error UnAuthorized();

    struct TokenRegistryInfo {
        bool isActive;
        address deployedAt;
    }

    //functions
    function depositCollateral(address account, address token, uint256 amount) external;
    function isAccountSolvent(address token, address account) external view returns (bool);
    function tokenRegistryInfo(address token) external view returns (bool, address);
    function transformTo18Decimals(address token, uint256 amount) external view returns (uint256);
    function borrow(address account, address token, uint256 amount, uint256 minAmountOut, bool mintToSender) external;
    function repay(address account, address token, uint256 amount, address burnFrom) external;
    function withdrawCollateral(address account, address token, uint256 amount) external;
    function isLiquidatable(address account, address token) external view returns (bool);
    function forceWithdrawCollateral(address account, address token, uint256 amount) external;

    //view functions
    function getTUSDAddress() external view returns (address);
}
