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
}
