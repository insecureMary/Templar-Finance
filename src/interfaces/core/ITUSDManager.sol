// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface ITUSDManager {
    //errors
    error InactiveToken();

    struct tokenRegistryInfo {
        bool isActive;
        address deployedat;
    }
}
