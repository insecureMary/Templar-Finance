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

    //MODIFIERS
    modifier isValidAddress(address addr) {
        require(addr != address(0), IExchangeManager__ZeroAddressNotAllowed());
        _;
    }

    modifier validPool(bytes calldata path, uint256 amount) {
        isValidPool(path, amount);
        _;
    }

    //STATE-CHANGING FUNCTIONS

    function swapExactOutputMultihop(
        address _tokenIn,
        bytes calldata _swapRoute,
        address _account,
        uint256 _deadline,
        uint256 _amountOut,
        uint256 maxAmountIn
    )
        external
        override
        validPool(_swapRoute, _amountOut)
        returns (uint256 amountIn)
    {
        require(msg.sender == manager.liquidationManager(), IExchangeManager__Unauthorized());

        SwapExactOutputParams memory varData =
            SwapExactOutputParams({tokenIn: _tokenIn, swapRoute: _swapRoute, account: _account, deadline: _deadline, amountOut: _amountOut, maxAmountIn: maxAmountIn, swapRouter: swapRouter});
        //Transferring the maxAmountIn param from the user to this contract
        IAccount(varData.account).transfer(varData.tokenIn, address(this), varData.maxAmountIn);
        //Approve the swap router to spend/transfer tokens on behalf of the user account, from address(this)
        IERC20(varData.tokenIn).forceApprove(address(varData.swapRouter), varData.maxAmountIn);
        //Populating the exact output swap parameters, to be able to extract as must output with as minimal input
        ISwapRouter.ExactOutputParams memory outputParams =
            ISwapRouter.ExactOutputParams({path: varData.swapRoute, recipient: varData.account, deadline: varData.deadline, amountOut: varData.amountOut, amountInMaximum: varData.maxAmountIn});

        //Logic for the actual swapping
        try ISwapRouter(varData.swapRouter).exactOutput(outputParams) returns (uint256 amountInFinal) {
            amountIn = amountInFinal;
        } catch {
            revert IExchangeManager__SwapFailed();
        }
        //Returning any leftover tokens to the user account
        if (amountIn < varData.maxAmountIn) {
            //Remove allowance of the swap router before transferring
            IERC20(varData.tokenIn).forceApprove(address(varData.swapRouter), 0);
            //Transfer
            IERC20(varData.tokenIn).safeTransfer(varData.account, varData.maxAmountIn - amountIn);
        }

        //Emit event after successful swap
        emit ExactOutputSwapExecuted(varData.account, varData.tokenIn, amountIn, varData.amountOut, varData.swapRoute);
    }

    //ADMIN FUNCTIONS
    function setSwapRouter(address newRouter) external override onlyOwner {
        require(newRouter != address(0), IExchangeManager__ZeroAddressNotAllowed());
        address previousRouter = swapRouter;
        swapRouter = newRouter;
        emit SwapRouterUpdated(previousRouter, newRouter);
    }

    //PRIVATE AND INTERNAL FUNCTIONS
    function _getPool(address tokenA, address tokenB, uint24 fee) internal view returns (address pool) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pool = address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", uniswapFactory, keccak256(abi.encode(token0, token1, fee)), POOL_CREATION_CODE_HASH)))));
    }

    function isValidPool(bytes calldata _path, uint256 _amount) internal view {
        //Checking that the path length is valid, using x > 42 as check because the shortest path possible is tokenIn(20) + fee(3) + tokenOut(20) = 43 bytes
        require(_path.length > 42, IExchangeManager__InvalidSwapRoute());
        TempIsValidPoolData memory varData = TempIsValidPoolData({
            TUsd: IERC20(ITUSDManager(manager.templarUsdManager()).getTUSDAddress()),
            tokenIn: address(bytes20(_path[0:20])),
            fee: uint24(bytes3(_path[20:23])),
            tokenOut: address(bytes20(_path[23:43]))
        });

        require(varData.tokenIn == address(varData.TUsd), IExchangeManager__InvalidSwapRoute());

        require(varData.TUsd.balanceOf(_getPool(varData.tokenIn, varData.tokenOut, varData.fee)) >= _amount, IExchangeManager__InsufficientBalanceInPool());
    }
}
