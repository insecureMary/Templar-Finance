// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

library MathOperations {
    enum Rounding {
        Floor,
        Ceil
    }

    function getFeeAbsolute(uint256 amount, uint256 feeRate, uint256 precision) internal pure returns (uint256) {
        return (amount * feeRate) / precision;
    }

    function getRatio(uint256 numerator, uint256 denominator, uint256 precision, Rounding rounding) internal pure returns (uint256) {
        if (numerator == 0 || denominator == 0) {
            return 0;
        }

        uint256 _numerator = numerator * 10 ** precision;
        uint256 _quotient = _numerator / denominator;

        // Round up if necessary
        if (rounding == Rounding.Ceil && _numerator % denominator > 0) {
            _quotient += 1;
        }

        return (_quotient);
    }

    function getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the return data length is less than 68, then the transaction failed without a specific revert message
        if (_returnData.length < 68) return "Transaction reverted silently";
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // Return the revert string message
    }
}
