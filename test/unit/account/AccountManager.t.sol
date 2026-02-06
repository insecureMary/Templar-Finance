// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAccountManager} from "../../../src/interfaces/core/IAccountManager.sol";
import {Setup} from "../../setup/Setup.t.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract UnapprovedCaller {
    IAccountManager public am;

    constructor(address _am) {
        am = IAccountManager(_am);
    }

    function callCreate() external returns (address) {
        return am.createAccount();
    }
}

contract AccountManagerTest is Setup {
    //This is a dummy address for simple testing in this contract, for more complex tests, will revert to alice and bob from the setup.
    address public mary = makeAddr("mary");

    function setUp() public {
        initialize();
        token1Oracle.setUpdated(true);
    }

    function testCreateAccount() public {
        //testing that all the accounts are initialised while also checking that it works
        address maryAccount = createAccount(mary);
        //assert
        assert(maryAccount != address(0));
        assertEq(accountManager.accountToUser(maryAccount), mary);
        assertEq(accountManager.userToAccount(mary), maryAccount);
        //Asserting the ones that have been created in the initialize function
        assert(aliceAccount != address(0));
        assertEq(accountManager.accountToUser(aliceAccount), alice);
        assertEq(accountManager.userToAccount(alice), aliceAccount);
        assert(bobAccount != address(0));
        assertEq(accountManager.accountToUser(bobAccount), bob);
        assertEq(accountManager.userToAccount(bob), bobAccount);
    }

    function testUserCannotCreateAlreadyExistingAccount() public {
        vm.expectRevert(IAccountManager.IAccountManager__AccountAlreadyExists.selector);
        vm.prank(alice);
        address errorAccount = accountManager.createAccount();
        //assert
        assertEq(errorAccount, address(0));
        assertEq(accountManager.accountToUser(errorAccount), address(0));
        assertEq(accountManager.userToAccount(alice), aliceAccount);
    }

    function testUnapprovedContractCannotCallCreateAccount() public {
        UnapprovedCaller caller = new UnapprovedCaller(address(accountManager));
        vm.expectRevert(IAccountManager.IAccountManager__ContractNotWhitelisted.selector);
        caller.callCreate();
    }

    function testUserCanDepositPositive(uint128 bounded) public {
        //Arrange
        uint256 amountToDeposit = uint256(bounded) + 1;

        //Act
        depositForUser(alice, address(token1), amountToDeposit);
        //Assert
        assertEq(token1.balanceOf(aliceAccount), amountToDeposit);
    }

    function testUserCannotDepositNewUnsetToken(uint128 bounded) public {
        //Arrange
        uint256 amountToDeposit = uint256(bounded) + 1;
        //Act
        IERC20Metadata collateralContract = IERC20Metadata(address(invalidToken));
        uint256 collateralValueInUSd = _getCollateralAmountForUSDValue(address(invalidToken), amountToDeposit, collateralManager.getExchangeRate());

        vm.startPrank(alice);
        collateralContract.approve(address(accountManager), collateralValueInUSd);
        vm.expectRevert(abi.encodeWithSelector(IAccountManager.IAccountManager__TokenNotWhitelisted.selector));
        accountManager.deposit(address(invalidToken), collateralValueInUSd);
        vm.stopPrank();
    }

    function testUserCannotDepositZeroAmount() public {
        //Arrange
        uint256 amountToDeposit = 0;
        IERC20Metadata collateralContract = IERC20Metadata(address(token1));
        uint256 collateralValueInUSd = _getCollateralAmountForUSDValue(address(token1), amountToDeposit, collateralManager.getExchangeRate());

        //Act
        vm.startPrank(alice);
        collateralContract.approve(address(accountManager), collateralValueInUSd);
        vm.expectRevert(IAccountManager.IAccountManager__ZeroAmountInput.selector);
        accountManager.deposit(address(token1), collateralValueInUSd);
        //Assert
        assertEq(token1.balanceOf(aliceAccount), 0);
    }
}
