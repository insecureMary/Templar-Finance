// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAToken} from "../../../lib/aave-v3-core/contracts/interfaces/IAToken.sol";
import {IPool} from "../../../lib/aave-v3-core/contracts/interfaces/IPool.sol";
import {IRewardsController} from "../../../lib/aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol";
import {IAccount} from "../../interfaces/core/IAccount.sol";
import {IReceiptToken} from "../../interfaces/core/IReceiptToken.sol";
import {IStrategy} from "../../interfaces/core/IStrategy.sol";
import {BaseStrategy} from "../BaseStrategy.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract AaveV3Strategy is IStrategy, BaseStrategy {
    using SafeERC20 for IERC20;

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
    }
}
