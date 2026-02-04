// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;
import {IAccount} from "../interfaces/core/IAccount.sol";
import {IReceiptToken} from "../interfaces/core/IReceiptToken.sol";
import {IStrategy} from "../interfaces/core/IStrategy.sol";
import {MathOperations} from "../libraries/MathOperations.sol";

contract BaseStrategy {
    function _mint(IReceiptToken _token, address recipient, uint256 amount, uint256 decimal) internal {}

    function _burn(IReceiptToken receiptToken, address recipient, uint256 shares, uint256 totalShares, uint256 sharesDecimal) internal {}

    function _genericCall(address account, address to, bytes memory call) internal returns (bool success, bytes memory returnData) {
        (success, returnData) = IAccount(account).genericCall(to, call);
        if (!success) revert(MathOperations.getRevertMsg(returnData));
    }

    function _takePerformanceFee(address tokenIn, address recipient, uint256 yield) internal returns (uint256 fees) {}
}
