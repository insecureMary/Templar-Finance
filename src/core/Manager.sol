// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {ILiquidationManager} from "../interfaces/core/ILiquidationManager.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {IOracle} from "../interfaces/oracle/IOracle.sol";
import {MathOperations} from "../libraries/MathOperations.sol";

contract Manager is IManager, Ownable2Step {
    // IMMUTABLE VARIABLES
    uint256 public constant override MAX_PERFORMANCE_FEE = 2000; // 20
    uint256 public constant MAX_WITHDRAWAL_FEE = 500; // 5
    uint256 public constant override PRECISION_FACTOR = 1e5;
    uint256 public constant override EXCHANGE_RATE_PRECISION = 1e18;
    // STATE VARIABLES
    mapping(address => bool) public override isContractWhitelisted;
    mapping(address => bool) public override isTokenWhitelisted;
    mapping(address => bool) public override isWithdrawableToken;
    mapping(address => bool) public override isInvoker;
    IOracle public override tUsdOracle;
    bytes32 public override oracleData;
    address public override accountManager;
    address public override liquidationManager;
    address public override templarUsdManager;
    address public override strategyManager;
    address public override swapManager;
    address public override feeAddress;
    address public override receiptTokenFactory;
    uint256 public override performanceFee;
    uint256 public override minDebtAmount;
    uint256 public override withdrawalFee;

    //CONSTRUCTOR
    constructor(address _initialOwner, address _oracle, bytes memory _oracleData) Ownable(_initialOwner) isValidAddress(_oracle) {
        tUsdOracle = IOracle(_oracle);
        oracleData = bytes32(_oracleData);
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
    }
}
