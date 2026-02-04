// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IManager} from "./IManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title IExchangeManager
 * @notice Interface for Exchange Manager
 */
interface IExchangeManager {
    //EVENTS
    event SwapRouterUpdated(address indexed previousRouter, address indexed newRouter);
    event ExactOutputSwapExecuted(address indexed account, address indexed collateral, uint256 amountIn, uint256 amountOut, bytes swapPath);

    //ERRORS
    error IExchangeManager__ZeroAddressNotAllowed();
    error IExchangeManager__Unauthorized();

    //VARIABLES
    struct SwapExactOutputParams {
        address tokenIn; //token that user is putting in
        bytes swapRoute;
        address account;
        uint256 deadline;
        uint256 amountOut;
        uint256 maxAmountIn;
        address swapRouter;
    }

    struct TempValidPoolData {
        IERC20 TUsd;
        address tokenIn;
        address tokenOut;
        uint24 fee;
    }

    // STATE-CHANGING FUNCTIONS
    function swapExactOutputMultihop(address _tokenIn, bytes memory _swapRoute, address _account, uint256 _deadline, uint256 _amountOut, uint256 maxAmountIn) external view returns (uint256);

    // VIEW FUNCTIONS
    function swapRouter() external view returns (address);
    function uniswapFactory() external view returns (address);
    function manager() external view returns (IManager);

    // ADMIN FUNCTIONS
    function setSwapRouter(address newRouter) external;
}
