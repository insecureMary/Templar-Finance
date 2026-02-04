// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAToken} from "../../../lib/aave-v3-core/contracts/interfaces/IAToken.sol";
import {IPool} from "../../../lib/aave-v3-core/contracts/interfaces/IPool.sol";
import {IRewardsController} from "../../../lib/aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol";
import {IAccount} from "../../interfaces/core/IAccount.sol";
import {IReceiptToken} from "../../interfaces/core/IReceiptToken.sol";
import {IStrategy} from "../../interfaces/core/IStrategy.sol";
import {MathOperations} from "../../libraries/MathOperations.sol";
import {BaseStrategy} from "../BaseStrategy.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

abstract contract AaveV3Strategy is IStrategy, BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    mapping(address recipient => IStrategy.RecipientInfo info) public override recipients;
    address public feeManager;
    address public tokenIn;
    address public tokenOut;
    IPool public lendingPool;
    IReceiptToken public receiptToken;
    uint256 tokenOutDecimal;

    constructor(address _feeManager, address _tokenIn, address _pool, address _tokenOut, address _receiptToken, uint256 _tokenOutDecimal) {
        feeManager = _feeManager;
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
        tokenOutDecimal = _tokenOutDecimal;
        lendingPool = IPool(_pool);
        receiptToken = IReceiptToken(_receiptToken);
    }

    function deposit(address asset, uint256 amount, address recipient, bytes calldata data) external returns (uint256, uint256) {
        require(tokenIn == asset, IncompatibleAsset());
        uint256 balanceBefore = IAToken(tokenOut).scaledBalanceOf(recipient);
        uint16 refCode = data.length > 0 ? abi.decode(data, (uint16)) : 0;

        IAccount(recipient).transfer(asset, address(this), amount);

        //supply to aave and update parameters
        IERC20(asset).forceApprove(address(lendingPool), amount);
        lendingPool.supply(asset, amount, recipient, refCode);
        uint256 shares = IAToken(tokenOut).scaledBalanceOf(recipient) - balanceBefore;
        recipients[recipient].investedAmount += amount;
        recipients[recipient].totalShares += shares;

        //mint receipt token for user
        _mint(receiptToken, recipient, shares, tokenOutDecimal);

        emit Deposit(asset, tokenIn, amount, shares, recipient);
        return (shares, amount);
    }

    function withdraw(uint256 shares, address recipient, address asset, bytes calldata data) external returns (uint256, uint256, int256, uint256) {
        uint256 totalShares = recipients[recipient].totalShares;
        uint256 shareDecimal = tokenOutDecimal;
        require(shares <= totalShares, NotEnoughShares());
        require(tokenIn == asset, IncompatibleAsset());

        uint256 shareRatio = MathOperations.getRatio(shares, totalShares, tokenOutDecimal, MathOperations.Rounding.Floor);
        _burn(receiptToken, recipient, shares, totalShares, shareDecimal);

        //get the asset amount to withdraw, this include yield
        uint256 assetsToWithdraw = shareRatio == 10 ** shareDecimal ? type(uint256).max : IAToken(tokenOut).balanceOf(recipient) * shareRatio / 10 ** shareDecimal;
        uint256 investment = (recipients[recipient].investedAmount * shareRatio) / (10 ** shareDecimal);

        uint256 balanceBefore = IERC20(tokenIn).balanceOf(recipient);
        _genericCall(recipient, address(lendingPool), abi.encodeCall(IPool.withdraw, (asset, assetsToWithdraw, recipient)));

        uint256 withdrawnAmount = IERC20(tokenIn).balanceOf(recipient) - balanceBefore;
        int256 yield = withdrawnAmount.toInt256() - investment.toInt256();
        uint256 fee;
        if (yield > 0) {
            fee = _takePerformanceFee(tokenIn, recipient, uint256(yield));
            if (fee > 0) {
                withdrawnAmount -= fee;
                yield -= fee.toInt256();
            }
        }
        recipients[recipient].totalShares -= shares;
        recipients[recipient].investedAmount = investment > recipients[recipient].investedAmount ? 0 : recipients[recipient].investedAmount - investment;
        return (withdrawnAmount, investment, yield, fee);

        //TO-DO add event
    }
}
