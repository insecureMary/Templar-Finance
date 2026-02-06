// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;
import {Test} from "../../lib/forge-std/src/Test.sol";
import {ITUSDManager} from "../../src/interfaces/core/ITUSDManager.sol";
import {Setup} from "../setup/Setup.t.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract TusdManagerTest is Test, Setup {
    function setUp() public {
        Setup.initialize();
    }

    function testDepositWillPassWhenSetupIsCorrect() public {
        //arrange
        uint256 balanceBefore = collateralManager.collateralDeposited(aliceAccount);
        //first make oracle updated
        token1Oracle.setUpdated(true);
        //deal and deposit straightup
        depositForUser(alice, address(token1), ETHER);

        //assert
        uint256 balanceAfter = collateralManager.collateralDeposited(aliceAccount);
        uint256 balanceDiff = balanceAfter - balanceBefore;
        assertEq(balanceDiff, ETHER);
    }

    function testDepositWillRevertWhenTokenIsNotActive() public {
        //arrange
        //first let us make token 1 inactive
        vm.prank(owner);
        tusdManager.addNewCollateralManager(address(collateralManager), address(token1), false);
        (bool isActive,) = tusdManager.tokenRegistryInfo(address(token1));
        assertEq(isActive, false);

        //acts
        token1Oracle.setUpdated(true);
        IERC20Metadata collateralContract = IERC20Metadata(address(token1));
        uint256 collateralValueInUSd = _getCollateralAmountForUSDValue(address(token1), ETHER, collateralManager.getExchangeRate());

        vm.startPrank(alice);
        collateralContract.approve(address(accountManager), collateralValueInUSd);
        vm.expectRevert(abi.encodeWithSelector(ITUSDManager.InactiveToken.selector));
        accountManager.deposit(address(token1), collateralValueInUSd);
        vm.stopPrank();
    }
}

