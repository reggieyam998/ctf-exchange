// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { IBeacon } from "openzeppelin-contracts/proxy/beacon/IBeacon.sol";
import { Proxy } from "openzeppelin-contracts/proxy/Proxy.sol";
import { ERC1967Upgrade } from "openzeppelin-contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import { Address } from "openzeppelin-contracts/utils/Address.sol";

/// @title BeaconProxy
/// @notice Upgradeable proxy wallet that reads implementation from a beacon contract
/// @dev Provides seamless upgrades for all proxy wallets through beacon pattern
contract BeaconProxy is Proxy, ERC1967Upgrade {
    address private immutable _owner;
    bool private _paused;
    uint256 private _nonce;
    
    // Events
    event ProxyPaused(address indexed by);
    event ProxyUnpaused(address indexed by);
    event NonceIncremented(address indexed by, uint256 newNonce);
    
    // Errors
    error ProxyPausedError();
    error NotOwner();
    error InvalidBeacon();
    error InvalidImplementation();

    /// @notice Constructor initializes the proxy with beacon and owner
    /// @param beacon_ Beacon contract address
    /// @param owner_ Owner address for this proxy
    /// @param data Initialization data (optional)
    constructor(address beacon_, address owner_, bytes memory data) payable {
        if (beacon_ == address(0)) revert InvalidBeacon();
        if (owner_ == address(0)) revert InvalidImplementation();
        
        _owner = owner_;
        _upgradeBeaconToAndCall(beacon_, data, false);
    }

    /// @notice Returns the current beacon address
    /// @return Current beacon address
    function _beacon() internal view virtual returns (address) {
        return _getBeacon();
    }

    /// @notice Returns the current implementation address from the beacon
    /// @return Current implementation address
    function _implementation() internal view virtual override returns (address) {
        if (_paused) revert ProxyPausedError();
        
        address beacon = _getBeacon();
        if (beacon == address(0)) revert InvalidBeacon();
        
        address implementation = IBeacon(beacon).implementation();
        if (implementation == address(0)) revert InvalidImplementation();
        
        return implementation;
    }

    /// @notice Returns the owner of this proxy
    /// @return Owner address
    function owner() public view returns (address) {
        return _owner;
    }

    /// @notice Returns the current nonce for replay protection
    /// @return Current nonce
    function getNonce() public view returns (uint256) {
        return _nonce;
    }

    /// @notice Increments the nonce for replay protection
    /// @dev Only owner can increment nonce
    function incrementNonce() external {
        if (msg.sender != _owner) revert NotOwner();
        _nonce++;
        emit NonceIncremented(msg.sender, _nonce);
    }

    /// @notice Pauses this proxy (prevents all operations)
    /// @dev Only owner can pause
    function pause() external {
        if (msg.sender != _owner) revert NotOwner();
        _paused = true;
        emit ProxyPaused(msg.sender);
    }

    /// @notice Unpauses this proxy
    /// @dev Only owner can unpause
    function unpause() external {
        if (msg.sender != _owner) revert NotOwner();
        _paused = false;
        emit ProxyUnpaused(msg.sender);
    }

    /// @notice Returns whether this proxy is paused
    /// @return True if paused, false otherwise
    function isPaused() external view returns (bool) {
        return _paused;
    }

    /// @notice Returns the beacon address
    /// @return Beacon address
    function getBeacon() external view returns (address) {
        return _getBeacon();
    }

    /// @notice Returns the current implementation address
    /// @return Implementation address
    function getImplementation() external view returns (address) {
        return _implementation();
    }

    /// @notice Checks if the caller is the owner
    /// @param caller Address to check
    /// @return True if caller is owner, false otherwise
    function isOwner(address caller) external view returns (bool) {
        return caller == _owner;
    }

    /// @notice Validates a signature for this proxy
    /// @param messageHash Hash of the message to validate
    /// @param signature Signature to validate
    /// @return True if signature is valid, false otherwise
    function isValidSignature(bytes32 messageHash, bytes memory signature) external view returns (bool) {
        // This is a placeholder for signature validation
        // In a real implementation, this would validate ECDSA signatures
        // For now, we'll just check if the signer is the owner
        if (signature.length != 65) return false;
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        // Recover signer
        address signer = ecrecover(messageHash, v, r, s);
        return signer == _owner;
    }

    /// @notice Executes a transaction through this proxy
    /// @param target Target address to call
    /// @param data Data to send with the call
    /// @param value ETH value to send with the call
    /// @return Result of the call
    function execute(address target, bytes memory data, uint256 value) external payable returns (bytes memory) {
        if (msg.sender != _owner) revert NotOwner();
        if (_paused) revert ProxyPausedError();
        
        // Validate target is a contract
        if (!Address.isContract(target)) revert InvalidImplementation();
        
        // Execute the call
        (bool success, bytes memory result) = target.call{value: value}(data);
        
        if (!success) {
            // Revert with the error message
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        
        return result;
    }

    /// @notice Batch executes multiple transactions
    /// @param targets Array of target addresses
    /// @param dataArray Array of data to send with each call
    /// @param values Array of ETH values to send with each call
    /// @return Array of results
    function executeBatch(
        address[] memory targets,
        bytes[] memory dataArray,
        uint256[] memory values
    ) external returns (bytes[] memory) {
        if (msg.sender != _owner) revert NotOwner();
        if (_paused) revert ProxyPausedError();
        
        require(
            targets.length == dataArray.length && dataArray.length == values.length,
            "BeaconProxy: arrays length mismatch"
        );
        
        bytes[] memory results = new bytes[](targets.length);
        
        for (uint256 i = 0; i < targets.length; i++) {
            if (!Address.isContract(targets[i])) revert InvalidImplementation();
            
            (bool success, bytes memory result) = targets[i].call{value: values[i]}(dataArray[i]);
            
            if (!success) {
                // Revert with the error message
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            
            results[i] = result;
        }
        
        return results;
    }

    /// @notice Receives ETH
    receive() external payable override {
        // Allow receiving ETH
    }

    /// @notice Fallback function for unknown calls
    fallback() external payable override {
        _fallback();
    }
} 