// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title MockGnosisSafeFactory
/// @notice Mock Gnosis Safe factory for local development
contract MockGnosisSafeFactory {
    address public masterCopyAddress;
    
    event SafeCreated(address indexed safe, address indexed owner);
    
    constructor(address _masterCopy) {
        masterCopyAddress = _masterCopy;
    }
    
    /// @notice Creates a mock Safe for an owner
    /// @param owner The owner of the Safe
    /// @return safe The address of the created Safe
    function createSafe(address owner) external returns (address safe) {
        // For mock purposes, we'll just return a deterministic address
        // In a real implementation, this would deploy an actual Safe
        safe = address(uint160(uint256(keccak256(abi.encodePacked(owner, block.timestamp)))));
        emit SafeCreated(safe, owner);
        return safe;
    }
    
    /// @notice Gets the master copy address (required by IPolySafeFactory interface)
    /// @return The master copy address
    function masterCopy() external view returns (address) {
        return masterCopyAddress;
    }
    
    /// @notice Predicts the Safe address for an owner
    /// @param owner The owner address
    /// @return The predicted Safe address
    function predictSafeAddress(address owner) external view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(owner, block.timestamp)))));
    }
} 