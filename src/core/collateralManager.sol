// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ICollateralManager} from "../interfaces/core/ICollateralManager.sol";
import {IManager} from "../interfaces/core/IManager.sol";
import {IOracle} from "../interfaces/oracle/IOracle.sol";

contract collateralManager is ICollateralManager, Ownable {
    //MAPPINGS
    mapping(address account => uint256 amount) public collateralDeposited;
    mapping(address account => uint256 amount) public borrowed;

    address public immutable token;
    CollateralManagerConfig private config;
    IManager public appManager;
    IOracle public oracle;
    bytes public oracleData;

    constructor(address _initialOwner, address _manager, address _token, address _oracle, bytes memory _oracleData, CollateralManagerConfig memory _config) Ownable(_initialOwner) {
        require(_manager != address(0), "3065");
        require(_token != address(0), "3001");
        require(_oracle != address(0), "3034");

        token = _token;
        oracle = IOracle(_oracle);
        oracleData = _oracleData;
        appManager = IManager(_manager);
        config = _config;
    }

    function depositCollateral(address account, uint256 amount) external {
        collateralDeposited[account] += amount;
        emit CollateralDeposited(account, amount, address(this));
    }

    function withdrawCollateral(address account, uint256 amount) external {
        collateralDeposited[account] -= amount;
        emit CollateralWithdrawn(account, amount, address(this));
    }

    function borrow(address account, uint256 amount) external {
        borrowed[account] += amount;
        emit TUSDBorrowed(account, amount, address(this));
    }

    function repay(address account, uint256 amount) external {
        borrowed[account] -= amount;
        emit TUSDRepayed(account, amount, address(this));
    }

    function getExchangeRate() external view returns (uint256) {
        (bool updated, uint256 rate) = oracle.peek(oracleData);
        require(updated, StateData());
        require(rate > 0, ZeroRate());

        return rate;
    }

    function updateConfig(CollateralManagerConfig memory _config) public onlyOwner {
        config = _config;
    }

    function getConfig() public view returns (CollateralManagerConfig memory) {
        return config;
    }
}
