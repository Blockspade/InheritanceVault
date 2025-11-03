// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {InheritanceVault} from "../src/InheritanceVault.sol";

contract InheritanceVaultTest is Test {
    InheritanceVault public vault;
    
    address public owner;
    address public heir;
    address public newHeir;
    address public attacker;
    
    uint256 constant INACTIVITY_PERIOD = 30 days;
    
    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event HeirUpdated(address indexed oldHeir, address indexed newHeir);
    event OwnershipClaimed(address indexed oldOwner, address indexed newOwner, address indexed newHeir);
    event HeartbeatUpdated(address indexed owner, uint256 timestamp);

    function setUp() public {
        owner = makeAddr("owner");
        heir = makeAddr("heir");
        newHeir = makeAddr("newHeir");
        attacker = makeAddr("attacker");
        
        vm.prank(owner);
        vault = new InheritanceVault(heir);
        
        vm.deal(owner, 100 ether);
    }


    function test_Constructor() public {
        assertEq(vault.owner(), owner);
        assertEq(vault.heir(), heir);
        assertEq(vault.lastWithdrawal(), block.timestamp);
        assertEq(vault.INACTIVITY_PERIOD(), INACTIVITY_PERIOD);
    }

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(InheritanceVault.InvalidHeirAddress.selector);
        new InheritanceVault(address(0));
    }

    function test_Constructor_RevertsWhenOwnerIsHeir() public {
        vm.prank(owner);
        vm.expectRevert(InheritanceVault.InvalidHeirAddress.selector);
        new InheritanceVault(owner);
    }

    // deposit test
    function test_Deposit_ViaReceive() public {
        uint256 depositAmount = 10 ether;
        
        vm.expectEmit(true, false, false, true);
        emit Deposited(owner, depositAmount);
        
        vm.prank(owner);
        (bool success, ) = address(vault).call{value: depositAmount}("");
        
        assertTrue(success);
        assertEq(vault.getBalance(), depositAmount);
    }

    // withdrawal test 
    function test_Withdraw_Success() public {
        // Deposit first
        vm.prank(owner);
        (bool success, ) = address(vault).call{value: 10 ether}("");
        assertTrue(success);
        
        uint256 ownerBalanceBefore = owner.balance;
        uint256 withdrawAmount = 5 ether;
        
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(owner, withdrawAmount);
        
        vm.prank(owner);
        vault.withdraw(withdrawAmount);
        
        assertEq(vault.getBalance(), 5 ether);
        assertEq(owner.balance, ownerBalanceBefore + withdrawAmount);
    }

    function test_Withdraw_RevertsWhenNotOwner() public {
        vm.prank(owner);
        (bool success, ) = address(vault).call{value: 10 ether}("");
        assertTrue(success);
        
        vm.prank(attacker);
        vm.expectRevert(InheritanceVault.OnlyOwner.selector);
        vault.withdraw(5 ether);
    }

    function test_Withdraw_UpdatesTimestamp() public {
        vm.prank(owner);
        (bool success, ) = address(vault).call{value: 10 ether}("");
        assertTrue(success);
        
        uint256 timeBefore = vault.lastWithdrawal();
        
        vm.warp(block.timestamp + 1 days);
        
        vm.prank(owner);
        vault.withdraw(1 ether);
        
        uint256 timeAfter = vault.lastWithdrawal();
        assertGt(timeAfter, timeBefore);
        assertEq(timeAfter, block.timestamp);
    }

    function test_Heartbeat_ZeroWithdrawal() public {
        uint256 initialTimestamp = vault.lastWithdrawal();
        
        vm.warp(block.timestamp + 15 days);
        
        vm.expectEmit(true, false, false, true);
        emit HeartbeatUpdated(owner, block.timestamp);
        
        vm.prank(owner);
        vault.withdraw(0);
        
        assertEq(vault.lastWithdrawal(), block.timestamp);
        assertGt(vault.lastWithdrawal(), initialTimestamp);
    }
    
    // update heir test
    function test_UpdateHeir_Success() public {
        vm.expectEmit(true, true, false, false);
        emit HeirUpdated(heir, newHeir);
        
        vm.prank(owner);
        vault.updateHeir(newHeir);
        
        assertEq(vault.heir(), newHeir);
    }


    function test_UpdateHeir_RevertsWhenNotOwner() public {
        vm.prank(attacker);
        vm.expectRevert(InheritanceVault.OnlyOwner.selector);
        vault.updateHeir(newHeir);
    }

    // claim ownership test
    function test_ClaimOwnership_Success() public {
        // Deposit some ETH
        vm.prank(owner);
        (bool success, ) = address(vault).call{value: 10 ether}("");
        assertTrue(success);
        
        // Wait for inactivity period
        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);
        
        vm.expectEmit(true, true, true, false);
        emit OwnershipClaimed(owner, heir, newHeir);
        
        vm.prank(heir);
        vault.claimOwnership(newHeir);
        
        assertEq(vault.owner(), heir);
        assertEq(vault.heir(), newHeir);
        assertEq(vault.lastWithdrawal(), block.timestamp);
    }

    function test_ClaimOwnership_RevertsBeforeInactivityPeriod() public {
        // Wait 29 days (not enough)
        vm.warp(block.timestamp + 29 days);
        
        vm.prank(heir);
        vm.expectRevert(InheritanceVault.InactivityPeriodNotReached.selector);
        vault.claimOwnership(newHeir);
    }

    function test_ClaimOwnership_RevertsWhenNotHeir() public {
        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);
        
        vm.prank(attacker);
        vm.expectRevert(InheritanceVault.OnlyHeir.selector);
        vault.claimOwnership(newHeir);
    }

    function test_ClaimOwnership_NewOwnerCanWithdraw() public {
        // Deposit
        vm.prank(owner);
        (bool success, ) = address(vault).call{value: 10 ether}("");
        assertTrue(success);
        
        // Heir claims ownership
        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);
        vm.prank(heir);
        vault.claimOwnership(newHeir);
        
        // New owner (old heir) can withdraw
        uint256 balanceBefore = heir.balance;
        
        vm.prank(heir);
        vault.withdraw(5 ether);
        
        assertEq(heir.balance, balanceBefore + 5 ether);
    }

    function test_ClaimOwnership_OldOwnerCannotWithdraw() public {
        // Heir claims ownership
        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);
        vm.prank(heir);
        vault.claimOwnership(newHeir);
        
        // Old owner cannot withdraw
        vm.prank(owner);
        vm.expectRevert(InheritanceVault.OnlyOwner.selector);
        vault.withdraw(1 ether);
    }

    function test_CannotClaimWithoutWaiting() public {
        // Test that immediate claim fails
        vm.prank(heir);
        vm.expectRevert(InheritanceVault.InactivityPeriodNotReached.selector);
        vault.claimOwnership(newHeir);
        
        // Even at the last second before the period ends
        vm.warp(block.timestamp + INACTIVITY_PERIOD - 1);
        vm.prank(heir);
        vm.expectRevert(InheritanceVault.InactivityPeriodNotReached.selector);
        vault.claimOwnership(newHeir);
    }

    function test_OwnerCannotBeSetAsHeir() public {
        // Verify owner cannot set themselves as heir
        vm.prank(owner);
        vm.expectRevert(InheritanceVault.InvalidHeirAddress.selector);
        vault.updateHeir(owner);
        
        // Original heir should remain unchanged
        assertEq(vault.heir(), heir);
    }

    // integration tests
    function test_Integration_CompleteLifecycle() public {
        // 1. Owner deposits
        vm.prank(owner);
        (bool success, ) = address(vault).call{value: 20 ether}("");
        assertTrue(success);
        assertEq(vault.getBalance(), 20 ether);
        
        // 2. Owner withdraws some
        vm.prank(owner);
        vault.withdraw(5 ether);
        assertEq(vault.getBalance(), 15 ether);
        
        // 3. Owner sends heartbeat after 20 days
        vm.warp(block.timestamp + 20 days);
        vm.prank(owner);
        vault.withdraw(0);
        
        // 4. Owner becomes inactive
        vm.warp(block.timestamp + INACTIVITY_PERIOD + 1);
        assertTrue(vault.canHeirClaim());
        
        // 5. Heir claims ownership
        vm.prank(heir);
        vault.claimOwnership(newHeir);
        assertEq(vault.owner(), heir);
        
        // 6. New owner withdraws remaining funds
        uint256 heirBalanceBefore = heir.balance;
        vm.prank(heir);
        vault.withdraw(15 ether);
        assertEq(heir.balance, heirBalanceBefore + 15 ether);
        assertEq(vault.getBalance(), 0);
    }
}

