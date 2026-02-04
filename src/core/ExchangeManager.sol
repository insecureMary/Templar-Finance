// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ISwapRouter} from "@v3-periphery/interfaces/ISwapRouter.sol";

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAccount} from "../interfaces/core/IAccount.sol";
import {IExchangeManager} from "../interfaces/core/IExchangeManager.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {ITUSDManager} from "../interfaces/core/ITUSDManager.sol";

contract ExchangeManager is IExchangeManager, Ownable2Step {
    using SafeERC20 for IERC20;

    //STATE VARIABLES
    address public override swapRouter;
    address public override uniswapFactory;
    IManager public immutable manager;

    bytes32 internal constant POOL_CREATION_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    //CONSTRUCTOR
    constructor(address _initialOwner, address _swapRouter, address _uniswapFactory, address _manager) Ownable(_initialOwner) {
        require(_swapRouter != address(0), IExchangeManager__ZeroAddressNotAllowed());
        require(_uniswapFactory != address(0), IExchangeManager__ZeroAddressNotAllowed());
        require(_manager != address(0), IExchangeManager__ZeroAddressNotAllowed());
        swapRouter = _swapRouter;
        uniswapFactory = _uniswapFactory;
        manager = IManager(_manager);
    }

    //STATE-CHANGING FUNCTIONS

    function swapExactOutputMultihop(address _tokenIn, bytes memory _swapRoute, address _account, uint256 _deadline, uint256 _amountOut, uint256 maxAmountIn) external view override returns (uint256) {
        require(msg.sender == manager.liquidationManager(), IExchangeManager__Unauthorized());

        SwapExactOutputParams memory tempData =
            SwapExactOutputParams({tokenIn: _tokenIn, swapRoute: _swapRoute, account: _account, deadline: _deadline, amountOut: _amountOut, maxAmountIn: maxAmountIn, swapRouter: swapRouter});
    }

    function setSwapRouter(address newRouter) external override onlyOwner {
        require(newRouter != address(0), IExchangeManager__ZeroAddressNotAllowed());
        address previousRouter = swapRouter;
        swapRouter = newRouter;
        emit SwapRouterUpdated(previousRouter, newRouter);
    }
}
