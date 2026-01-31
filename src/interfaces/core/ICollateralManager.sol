// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface ICollateralManager {
    //events
    event CollateralDeposited(address indexed account, uint256 indexed amount, address token);
    event CollateralWithdrawn(address indexed account, uint256 indexed amount, address token);
    event TUSDBorrowed(address indexed account, uint256 indexed amount, address token);
    event TUSDRepayed(address indexed account, uint256 indexed amount, address token);

    //variables
    struct CollateralManagerConfig {
        uint256 collateralizationRate;
        uint256 liquidationBuffer;
        uint256 liquidatorBonus;
    }

    function collateralDeposited(address account) external returns (uint256 amount);
    function depositCollateral(address, uint256) external;
    function withdrawCollateral(address account, uint256 amount) external;
    function getExchangeRate() external view returns (uint256);
    function borrowed(address account) external returns (uint256 amount);
    function getConfig() external returns (CollateralManagerConfig memory);
    function token() external returns (address);
    function borrow(address account, uint256 amount) external;
}
