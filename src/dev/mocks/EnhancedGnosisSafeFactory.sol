// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import { Address } from "openzeppelin-contracts/utils/Address.sol";

/// @title EnhancedGnosisSafeFactory
/// @notice Enhanced Gnosis Safe factory that mimics Polymarket's approach
/// @dev Creates 1-of-1 multisig wallets for MetaMask users
contract EnhancedGnosisSafeFactory is Ownable {
    address public immutable masterCopyAddress;
    
    // Events
    event SafeCreated(address indexed safe, address indexed owner, uint256 indexed salt);
    event BatchSafeCreated(address[] safes, address[] owners, uint256[] salts);
    event FactoryPaused(address indexed by);
    event FactoryUnpaused(address indexed by);
    
    // Errors
    error FactoryPausedError();
    error InvalidOwner();
    error InvalidMasterCopy();
    error SafeAlreadyExists();
    error ArraysLengthMismatch();
    error InvalidSalt();

    bool private _paused;

    /// @notice Constructor sets the master copy and owner
    /// @param masterCopy_ Master copy address for Safe contracts
    /// @param owner_ Factory owner address
    constructor(address masterCopy_, address owner_) {
        if (masterCopy_ == address(0)) revert InvalidMasterCopy();
        if (owner_ == address(0)) revert InvalidOwner();
        
        masterCopyAddress = masterCopy_;
        _transferOwnership(owner_);
    }

    /// @notice Creates a 1-of-1 multisig Safe for an owner
    /// @param owner The owner of the Safe (1-of-1 multisig)
    /// @param salt Unique salt for deterministic address
    /// @return safe The address of the created Safe
    function createSafe(address owner, uint256 salt) external returns (address safe) {
        if (_paused) revert FactoryPausedError();
        if (owner == address(0)) revert InvalidOwner();
        if (salt == 0) revert InvalidSalt();
        
        // Check if Safe already exists
        address predictedSafe = predictSafeAddress(owner, salt);
        if (Address.isContract(predictedSafe)) revert SafeAlreadyExists();
        
        // Create 1-of-1 multisig setup
        address[] memory owners = new address[](1);
        owners[0] = owner;
        
        uint256 threshold = 1; // 1-of-1 multisig
        
        // For mock purposes, we'll create a deterministic address
        // In a real implementation, this would deploy an actual Gnosis Safe
        safe = _computeSafeAddress(owner, salt);
        
        emit SafeCreated(safe, owner, salt);
        return safe;
    }

    /// @notice Creates multiple Safes in a batch
    /// @param owners Array of owner addresses
    /// @param salts Array of unique salts
    /// @return safes Array of created Safe addresses
    function createSafeBatch(
        address[] memory owners,
        uint256[] memory salts
    ) external returns (address[] memory safes) {
        if (_paused) revert FactoryPausedError();
        if (owners.length != salts.length) revert ArraysLengthMismatch();
        
        safes = new address[](owners.length);
        
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == address(0)) revert InvalidOwner();
            if (salts[i] == 0) revert InvalidSalt();
            
            // Check if Safe already exists
            address predictedSafe = predictSafeAddress(owners[i], salts[i]);
            if (Address.isContract(predictedSafe)) revert SafeAlreadyExists();
            
            // Create deterministic address
            safes[i] = _computeSafeAddress(owners[i], salts[i]);
        }
        
        emit BatchSafeCreated(safes, owners, salts);
    }

    /// @notice Predicts the Safe address for an owner and salt
    /// @param owner The owner address
    /// @param salt The salt used for creation
    /// @return The predicted Safe address
    function predictSafeAddress(address owner, uint256 salt) public view returns (address) {
        return _computeSafeAddress(owner, salt);
    }

    /// @notice Checks if a Safe exists at the predicted address
    /// @param owner The owner address
    /// @param salt The salt used for creation
    /// @return True if Safe exists, false otherwise
    function safeExists(address owner, uint256 salt) external view returns (bool) {
        address predictedSafe = predictSafeAddress(owner, salt);
        return Address.isContract(predictedSafe);
    }

    /// @notice Pauses the factory
    function pause() external onlyOwner {
        _paused = true;
        emit FactoryPaused(msg.sender);
    }

    /// @notice Unpauses the factory
    function unpause() external onlyOwner {
        _paused = false;
        emit FactoryUnpaused(msg.sender);
    }

    /// @notice Gets the master copy address (required by interfaces)
    /// @return The master copy address
    function masterCopy() external view returns (address) {
        return masterCopyAddress;
    }

    /// @notice Checks if factory is paused
    /// @return True if paused, false otherwise
    function paused() external view returns (bool) {
        return _paused;
    }

    /// @notice Internal function to compute Safe address
    /// @param owner The owner address
    /// @param salt The salt used for creation
    /// @return The computed Safe address
    function _computeSafeAddress(address owner, uint256 salt) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(owner, salt)))));
    }
} 