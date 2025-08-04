// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import { Address } from "openzeppelin-contracts/utils/Address.sol";
import { IBeacon } from "openzeppelin-contracts/proxy/beacon/IBeacon.sol";

/// @title ExchangeBeacon
/// @notice Centralized beacon contract for managing proxy wallet implementations
/// @dev Provides upgrade control for all beacon-based proxy wallets
contract ExchangeBeacon is IBeacon, Ownable {
    address private _implementation;
    bool private _paused;
    uint256 private _upgradeTimelock;
    address private _pendingImplementation;
    uint256 private _pendingUpgradeTime;
    address private _rollbackImplementation;
    
    // Events
    event ImplementationUpgraded(address indexed oldImplementation, address indexed newImplementation);
    event UpgradeScheduled(address indexed newImplementation, uint256 upgradeTime);
    event UpgradeCancelled(address indexed cancelledImplementation);
    event BeaconPaused(address indexed by);
    event BeaconUnpaused(address indexed by);
    event RollbackSet(address indexed rollbackImplementation);
    event RollbackExecuted(address indexed fromImplementation, address indexed toImplementation);

    // Errors
    error BeaconPausedError();
    error UpgradeNotScheduled();
    error TimelockNotExpired();
    error InvalidImplementation();
    error UpgradeInProgress();

    /// @notice Constructor sets initial implementation and owner
    /// @param implementation_ Initial implementation address
    /// @param owner_ Owner address for beacon control
    constructor(address implementation_, address owner_) {
        _setImplementation(implementation_);
        _transferOwnership(owner_);
    }

    /// @notice Returns the current implementation address
    /// @return Current implementation address
    function implementation() public view virtual override returns (address) {
        if (_paused) revert BeaconPausedError();
        return _implementation;
    }

    /// @notice Schedules an upgrade to a new implementation
    /// @param newImplementation New implementation address
    /// @param timelockDuration Duration to wait before upgrade can be executed
    function scheduleUpgrade(address newImplementation, uint256 timelockDuration) external onlyOwner {
        if (!Address.isContract(newImplementation)) revert InvalidImplementation();
        if (_pendingImplementation != address(0)) revert UpgradeInProgress();
        
        _pendingImplementation = newImplementation;
        _upgradeTimelock = timelockDuration;
        _pendingUpgradeTime = block.timestamp + timelockDuration;
        
        emit UpgradeScheduled(newImplementation, _pendingUpgradeTime);
    }

    /// @notice Executes the scheduled upgrade
    function executeUpgrade() external onlyOwner {
        if (_pendingImplementation == address(0)) revert UpgradeNotScheduled();
        if (block.timestamp < _pendingUpgradeTime) revert TimelockNotExpired();
        
        address oldImplementation = _implementation;
        _setImplementation(_pendingImplementation);
        
        // Store rollback implementation
        _rollbackImplementation = oldImplementation;
        
        // Clear pending upgrade
        _pendingImplementation = address(0);
        _upgradeTimelock = 0;
        _pendingUpgradeTime = 0;
        
        emit ImplementationUpgraded(oldImplementation, _implementation);
    }

    /// @notice Cancels the scheduled upgrade
    function cancelUpgrade() external onlyOwner {
        if (_pendingImplementation == address(0)) revert UpgradeNotScheduled();
        
        address cancelledImplementation = _pendingImplementation;
        _pendingImplementation = address(0);
        _upgradeTimelock = 0;
        _pendingUpgradeTime = 0;
        
        emit UpgradeCancelled(cancelledImplementation);
    }

    /// @notice Rolls back to the previous implementation
    function rollback() external onlyOwner {
        if (_rollbackImplementation == address(0)) revert InvalidImplementation();
        
        address currentImplementation = _implementation;
        _setImplementation(_rollbackImplementation);
        
        emit RollbackExecuted(currentImplementation, _rollbackImplementation);
        
        // Clear rollback implementation after use
        _rollbackImplementation = address(0);
    }

    /// @notice Pauses the beacon (prevents proxy wallets from working)
    function pause() external onlyOwner {
        _paused = true;
        emit BeaconPaused(msg.sender);
    }

    /// @notice Unpauses the beacon
    function unpause() external onlyOwner {
        _paused = false;
        emit BeaconUnpaused(msg.sender);
    }

    /// @notice Emergency upgrade without timelock (only in emergencies)
    /// @param newImplementation New implementation address
    function emergencyUpgrade(address newImplementation) external onlyOwner {
        if (!Address.isContract(newImplementation)) revert InvalidImplementation();
        
        address oldImplementation = _implementation;
        _setImplementation(newImplementation);
        
        // Clear any pending upgrade
        _pendingImplementation = address(0);
        _upgradeTimelock = 0;
        _pendingUpgradeTime = 0;
        
        emit ImplementationUpgraded(oldImplementation, _implementation);
    }

    /// @notice Sets a rollback implementation for future use
    /// @param rollbackImplementation Address to rollback to
    function setRollbackImplementation(address rollbackImplementation) external onlyOwner {
        if (!Address.isContract(rollbackImplementation)) revert InvalidImplementation();
        _rollbackImplementation = rollbackImplementation;
        emit RollbackSet(rollbackImplementation);
    }

    /// @notice Returns the pending upgrade information
    /// @return pendingImplementation Address of pending implementation
    /// @return upgradeTime When the upgrade can be executed
    /// @return timelockDuration Duration of the timelock
    function getPendingUpgrade() external view returns (address pendingImplementation, uint256 upgradeTime, uint256 timelockDuration) {
        return (_pendingImplementation, _pendingUpgradeTime, _upgradeTimelock);
    }

    /// @notice Returns the rollback implementation address
    /// @return Rollback implementation address
    function getRollbackImplementation() external view returns (address) {
        return _rollbackImplementation;
    }

    /// @notice Returns whether the beacon is paused
    /// @return True if paused, false otherwise
    function isPaused() external view returns (bool) {
        return _paused;
    }

    /// @notice Sets the implementation address
    /// @param newImplementation New implementation address
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ExchangeBeacon: implementation is not a contract");
        _implementation = newImplementation;
    }
} 