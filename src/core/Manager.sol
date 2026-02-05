// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IManager} from "../interfaces/core/IManager.sol";
import {IOracle} from "../interfaces/oracle/IOracle.sol";

contract Manager is IManager, Ownable2Step {
    // IMMUTABLE VARIABLES
    uint256 public constant override MAX_PERFORMANCE_FEE = 2000; // 20
    uint256 public constant MAX_WITHDRAWAL_FEE = 500; // 5
    uint256 public constant override PRECISION_FACTOR = 1e5;
    uint256 public constant override EXCHANGE_RATE_PRECISION = 1e18;
    // STATE VARIABLES
    mapping(address => bool) public override isContractWhitelisted;
    mapping(address => bool) public override isTokenWhitelisted;
    mapping(address => bool) public override canWithdrawToken;
    mapping(address => bool) public override isInvoker;
    IOracle public override tUsdOracle;
    bytes public override oracleData;
    address public override accountManager;
    address public override liquidationManager;
    address public override templarUsdManager;
    address public override strategyManager;
    address public override exchangeManager;
    address public override feeRecipient;
    address public override receiptTokenFactory;
    uint256 public override performanceFee;
    uint256 public override minDebtAmount;
    uint256 public override withdrawalFeeRate;

    //CONSTRUCTOR
    constructor(address _initialOwner, address _oracle, bytes memory _oracleData) Ownable(_initialOwner) isValidAddress(_oracle) {
        tUsdOracle = IOracle(_oracle);
        oracleData = bytes(_oracleData);
    }

    //MODIFIERS
    modifier isValidAddress(address addressToCheck) {
        require(addressToCheck != address(0), IManager__ZeroAddressInput());
        _;
    }

    //SETTERS
    function whitelistContract(address _contractAddress) external onlyOwner isValidAddress(_contractAddress) {
        require(!isContractWhitelisted[_contractAddress], IManager__ContractAlreadyWhitelisted());
        isContractWhitelisted[_contractAddress] = true;
        emit ContractWhitelisted(_contractAddress);
    }

    function blacklistContract(address _contractAddress) external onlyOwner {
        require(isContractWhitelisted[_contractAddress], IManager__ContractNotWhitelisted());
        isContractWhitelisted[_contractAddress] = false;
        emit ContractBlacklisted(_contractAddress);
    }

    function whitelistToken(address _tokenAddress) external onlyOwner isValidAddress(_tokenAddress) {
        require(!isTokenWhitelisted[_tokenAddress], IManager__TokenAlreadyWhitelisted());
        isTokenWhitelisted[_tokenAddress] = true;
        emit TokenWhitelisted(_tokenAddress);
    }

    function removeTokenFromWhitelist(address _tokenAddress) external onlyOwner {
        require(isTokenWhitelisted[_tokenAddress], IManager__TokenNotWhitelisted());
        isTokenWhitelisted[_tokenAddress] = false;
        emit TokenRemovedFromWhitelist(_tokenAddress);
    }

    function addWithdrawableToken(address _tokenAddress) external isValidAddress(_tokenAddress) {
        require(msg.sender == owner() || msg.sender == templarUsdManager, IManager__UnauthorisedCaller());
        require(!canWithdrawToken[_tokenAddress], IManager__TokenAlreadyWithdrawable());
        canWithdrawToken[_tokenAddress] = true;
        emit WithdrawableTokenAdded(_tokenAddress);
    }

    function removeWithdrawableToken(address _tokenAddress) external onlyOwner {
        require(canWithdrawToken[_tokenAddress], IManager__TokenNotWithdrawable());
        canWithdrawToken[_tokenAddress] = false;
        emit WithdrawableTokenRemoved(_tokenAddress);
    }

    function setInvoker(address _invoker, bool _status) external onlyOwner isValidAddress(_invoker) {
        isInvoker[_invoker] = _status;
        emit InvokerStatusUpdated(_invoker, _status);
    }

    function setAccountManager(address _newAccountManager) external onlyOwner isValidAddress(_newAccountManager) {
        accountManager = _newAccountManager;
        emit AccountManagerUpdated(_newAccountManager);
    }

    function setLiquidationManager(address _newLiquidationManager) external onlyOwner isValidAddress(_newLiquidationManager) {
        liquidationManager = _newLiquidationManager;
        emit LiquidationManagerUpdated(_newLiquidationManager);
    }

    function setTemplarUsdManager(address _newTemplarUsdManager) external onlyOwner isValidAddress(_newTemplarUsdManager) {
        templarUsdManager = _newTemplarUsdManager;
        emit TemplarUsdManagerUpdated(_newTemplarUsdManager);
    }

    function setStrategyManager(address _newStrategyManager) external onlyOwner isValidAddress(_newStrategyManager) {
        strategyManager = _newStrategyManager;
        emit StrategyManagerUpdated(_newStrategyManager);
    }

    function setExchangeManager(address _newExchangeManager) external onlyOwner isValidAddress(_newExchangeManager) {
        exchangeManager = _newExchangeManager;
        emit ExchangeManagerUpdated(_newExchangeManager);
    }

    function setPerformanceFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= MAX_PERFORMANCE_FEE, IManager__FeeExceedsMaximum());
        performanceFee = _newFee;
        emit PerformanceFeeUpdated(_newFee);
    }

    function setwithdrawalFeeRate(uint256 _newFeeRate) external onlyOwner {
        require(_newFeeRate <= MAX_WITHDRAWAL_FEE, IManager__FeeExceedsMaximum());
        withdrawalFeeRate = _newFeeRate;
        emit withdrawalFeeRateUpdated(_newFeeRate);
    }

    function setfeeRecipient(address _newfeeRecipient) external onlyOwner isValidAddress(_newfeeRecipient) {
        feeRecipient = _newfeeRecipient;
        emit feeRecipientUpdated(_newfeeRecipient);
    }

    function setReceiptTokenFactory(address _newFactory) external onlyOwner isValidAddress(_newFactory) {
        receiptTokenFactory = _newFactory;
        emit ReceiptTokenFactoryUpdated(_newFactory);
    }

    function setOracle(address _newOracle) external onlyOwner isValidAddress(_newOracle) {
        tUsdOracle = IOracle(_newOracle);
        emit OracleUpdated(_newOracle);
    }

    function setOracleData(bytes memory _newData) external onlyOwner {
        oracleData = _newData;
        emit OracleDataUpdated(_newData);
    }

    function setMinDebtAmount(uint256 _newMinDebtAmount) external onlyOwner {
        minDebtAmount = _newMinDebtAmount;
        emit MinDebtAmountUpdated(_newMinDebtAmount);
    }

    function getTusdExchangeRate() external view returns (uint256) {
        (bool updated, uint256 rate) = tUsdOracle.peek(oracleData);
        require(updated, IManager__Stale());
        require(rate > 0, IManager__ZeroRate());
        return rate;
    }
}
