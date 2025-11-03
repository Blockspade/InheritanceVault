// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/* This program is free software. It comes without any warranty, to
the extent permitted by applicable law. You can redistribute it
and/or modify it under the terms of the Do What The Fuck You Want
To Public License, Version 2, as published by Sam Hocevar. See
http://www.wtfpl.net/ for more details. */


/**
 * @title InheritanceVault
 * @author vasu
 * @notice A secure vault contract that allows ETH inheritance after a period of inactivity
 * @dev Implements a dead man's switch mechanism where an heir can claim ownership
 *      if the current owner doesn't interact with the contract for 30 days
 */
contract InheritanceVault {

    // Errors
    error OnlyOwner();
    error OnlyHeir();
    error InactivityPeriodNotReached();
    error InvalidHeirAddress();
    error WithdrawalFailed();
    error InsufficientBalance();

    // Events
    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event HeirUpdated(address indexed oldHeir, address indexed newHeir);
    event OwnershipClaimed(address indexed oldOwner, address indexed newOwner, address indexed newHeir);
    event HeartbeatUpdated(address indexed owner, uint256 timestamp);

    // State variables
    address public owner;
    address public heir;
    uint256 public lastWithdrawal;
    
    // Inactivity period after which heir can claim ownership (30 days)
    uint256 public constant INACTIVITY_PERIOD = 30 days;

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyHeir() {
        if (msg.sender != heir) revert OnlyHeir();
        _;
    }


    /**
     * @dev Constructor
     * @param _heir The address that can claim ownership after inactivity period
     */
    constructor(address _heir) {
        if (_heir == address(0)) revert InvalidHeirAddress();
        if (_heir == msg.sender) revert InvalidHeirAddress();
        
        owner = msg.sender;
        heir = _heir;
        // set the last withdrawal timestamp to the current block timestamp
        lastWithdrawal = block.timestamp;

        emit HeirUpdated(address(0), _heir);
    }


    /**
     * @notice Withdraw ETH from the vault (only owner)
     * @dev Can withdraw 0 ETH to reset the inactivity timer (heartbeat)
     * @param amount The amount of ETH to withdraw (in wei)
     */
    function withdraw(uint256 amount) external onlyOwner {
        if (amount > address(this).balance) revert InsufficientBalance();

        // Update the last withdrawal timestamp (heartbeat mechanism)
        lastWithdrawal = block.timestamp;

        // If amount is 0, this is just a heartbeat to reset the timer
        if (amount == 0) {
            emit HeartbeatUpdated(msg.sender, block.timestamp);
            return;
        }

        // Perform the withdrawal
        (bool success, ) = payable(owner).call{value: amount}("");
        if (!success) revert WithdrawalFailed();

        emit Withdrawn(owner, amount);
    }

    /**
     * @notice Update the heir address (only owner)
     * @param _newHeir The new heir address
     */
    function updateHeir(address _newHeir) external onlyOwner {
        if (_newHeir == address(0)) revert InvalidHeirAddress();
        if (_newHeir == owner) revert InvalidHeirAddress();
        
        address oldHeir = heir;
        heir = _newHeir;

        emit HeirUpdated(oldHeir, _newHeir);
    }

    /**
     * @notice Claim ownership of the vault after inactivity period
     * @dev Can only be called by the current heir after 30 days of owner inactivity
     * @param _newHeir The address to set as the new heir
     */
    function claimOwnership(address _newHeir) external onlyHeir {
        if (block.timestamp < lastWithdrawal + INACTIVITY_PERIOD) {
            revert InactivityPeriodNotReached();
        }
        if (_newHeir == address(0)) revert InvalidHeirAddress();

        address oldOwner = owner;
        address oldHeir = heir;

        // Transfer ownership
        owner = msg.sender;
        heir = _newHeir;
        lastWithdrawal = block.timestamp;

        emit OwnershipClaimed(oldOwner, msg.sender, _newHeir);
        emit HeirUpdated(oldHeir, _newHeir);
    }

     // receive function to deposit ETH into the vault
    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    // get balance of the vault
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // get time until heir can claim ownership
    function getTimeUntilClaimable() external view returns (uint256) {
        uint256 claimableTime = lastWithdrawal + INACTIVITY_PERIOD;
        
        if (block.timestamp >= claimableTime) {
            return 0;
        }
        
        return claimableTime - block.timestamp;
    }

    // check if heir can claim ownership
    function canHeirClaim() external view returns (bool) {
        return block.timestamp >= lastWithdrawal + INACTIVITY_PERIOD;
    }
}

