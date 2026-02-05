// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IOracle} from "../oracle/IOracle.sol";

interface IManager {
    //EVENTS
    event ContractWhitelisted(address indexed contractAddress);
    event ContractBlacklisted(address indexed contractAddress);
    event TokenWhitelisted(address indexed tokenAddress);
    event TokenRemovedFromWhitelist(address indexed tokenAddress);
    event WithdrawableTokenAdded(address indexed tokenAdded);
    event WithdrawableTokenRemoved(address indexed tokenAdded);
    event InvokerStatusUpdated(address indexed invoker, bool allowed);
    event AccountManagerUpdated(address indexed newAccountManager);
    event LiquidationManagerUpdated(address indexed newLiquidationManager);
    event TemplarUsdManagerUpdated(address indexed newTemplarUsdManager);
    event StrategyManagerUpdated(address indexed newStrategyManager);
    event ExchangeManagerUpdated(address indexed newExchangeManager);
    event PerformanceFeeUpdated(uint256 indexed newFee);
    event withdrawalFeeRateUpdated(uint256 indexed newFee);
    event feeRecipientUpdated(address indexed newAddress);
    event ReceiptTokenFactoryUpdated(address indexed newFactory);
    event OracleUpdated(address indexed newOracle);
    event OracleDataUpdated(bytes indexed newData);
    event MinDebtAmountUpdated(uint256 indexed newMinDebtAmount);

    //ERRORS
    error IManager__ZeroAddressInput();
    error IManager__ContractAlreadyWhitelisted();
    error IManager__ContractNotWhitelisted();
    error IManager__TokenAlreadyWhitelisted();
    error IManager__TokenNotWhitelisted();
    error IManager__UnauthorisedCaller();
    error IManager__TokenAlreadyWithdrawable();
    error IManager__TokenNotWithdrawable();
    error IManager__FeeExceedsMaximum();
    error IManager__Stale();
    error IManager__ZeroRate();

    //STATE MAPPINGS
    function isContractWhitelisted(address _contractAddress) external view returns (bool);
    function isTokenWhitelisted(address _tokenAddress) external view returns (bool);
    function canWithdrawToken(address _tokenAddress) external view returns (bool);
    function isInvoker(address _invoker) external view returns (bool);

    //ORACLE VARIABLES
    function tUsdOracle() external view returns (IOracle);
    function oracleData() external view returns (bytes memory);

    //MANAGER VARIABLES
    function accountManager() external view returns (address);
    function liquidationManager() external view returns (address);
    function templarUsdManager() external view returns (address);
    function strategyManager() external view returns (address);
    function exchangeManager() external view returns (address);

    //FEE VARIABLES
    function feeRecipient() external view returns (address);
    function performanceFee() external view returns (uint256);
    function MAX_PERFORMANCE_FEE() external view returns (uint256);
    function withdrawalFeeRate() external view returns (uint256);
    function MAX_WITHDRAWAL_FEE() external view returns (uint256);

    //FACTORY VARIABLES
    function receiptTokenFactory() external view returns (address);

    //UTILITY VARIABLES
    function minDebtAmount() external view returns (uint256);
    function PRECISION_FACTOR() external view returns (uint256);
    function EXCHANGE_RATE_PRECISION() external view returns (uint256);

    //STATE-CHANGING FUNCTIONS
    function whitelistContract(address _contractAddress) external;
    function blacklistContract(address _contractAddress) external;
    function whitelistToken(address _tokenAddress) external;
    function removeTokenFromWhitelist(address _tokenAddress) external;
    function addWithdrawableToken(address _tokenAddress) external;
    function removeWithdrawableToken(address _tokenAddress) external;
    function setInvoker(address _invoker, bool _status) external;
    function setAccountManager(address _newAccountManager) external;
    function setLiquidationManager(address _newLiquidationManager) external;
    function setTemplarUsdManager(address _newTemplarUsdManager) external;
    function setStrategyManager(address _newStrategyManager) external;
    function setExchangeManager(address _newExchangeManager) external;
    function setPerformanceFee(uint256 _newFee) external;
    function setwithdrawalFeeRate(uint256 _newFee) external;
    function setfeeRecipient(address _newfeeRecipient) external;
    function setReceiptTokenFactory(address _newFactory) external;
    function setOracle(address _newOracle) external;
    function setOracleData(bytes memory _newData) external;
    function setMinDebtAmount(uint256 _newMinDebtAmount) external;
    function getTusdExchangeRate() external view returns (uint256);
}
