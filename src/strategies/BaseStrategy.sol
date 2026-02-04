// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;
import {IReceiptToken} from "../interfaces/core/IReceiptToken.sol";
import {IStrategy} from "../interfaces/core/IStrategy.sol";

contract BaseStrategy {
    function _mint(IReceiptToken _token, address recipient, uint256 amount, uint256 decimal) internal {}

    function _burn(IReceiptToken receiptToken, address recipient, uint256 shares, uint256 totalShares, uint256 sharesDecimal) internal {}
}
