// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import { Address } from "openzeppelin-contracts/utils/Address.sol";
import { BeaconProxy } from "./BeaconProxy.sol";
import { ExchangeBeacon } from "./ExchangeBeacon.sol";

/// @title BeaconProxyFactory
/// @notice Factory for creating beacon-based proxy wallets with deterministic addresses
/// @dev Uses CREATE2 for deterministic deployment and minimal proxy pattern for gas efficiency
contract BeaconProxyFactory is Ownable {
    ExchangeBeacon public immutable beacon;
    BeaconProxy public immutable proxyImplementation;
    
    // Events
    event ProxyCreated(address indexed owner, address indexed proxy, bytes32 indexed salt);
    event BatchProxyCreated(address[] owners, address[] proxies, bytes32[] salts);
    event FactoryPaused(address indexed by);
    event FactoryUnpaused(address indexed by);
    
    // Errors
    error FactoryPausedError();
    error InvalidOwner();
    error InvalidBeacon();
    error ProxyAlreadyExists();
    error ArraysLengthMismatch();
    error InvalidSalt();

    bool private _paused;

    /// @notice Constructor sets the beacon and creates proxy implementation
    /// @param beacon_ Beacon contract address
    /// @param owner_ Factory owner address
    constructor(address beacon_, address owner_) {
        if (beacon_ == address(0)) revert InvalidBeacon();
        if (owner_ == address(0)) revert InvalidOwner();
        
        beacon = ExchangeBeacon(beacon_);
        _transferOwnership(owner_);
        
        // Deploy proxy implementation for minimal proxy pattern
        proxyImplementation = new BeaconProxy(beacon_, address(this), "");
    }

    /// @notice Creates a new beacon proxy for an owner
    /// @param owner Owner address for the proxy
    /// @param salt Unique salt for deterministic address
    /// @param data Initialization data (optional)
    /// @return proxy Address of the created proxy
    function createProxy(address owner, bytes32 salt, bytes memory data) external returns (address proxy) {
        if (_paused) revert FactoryPausedError();
        if (owner == address(0)) revert InvalidOwner();
        if (salt == bytes32(0)) revert InvalidSalt();
        
        // Check if proxy already exists
        address predictedProxy = predictProxyAddress(owner, salt);
        if (Address.isContract(predictedProxy)) revert ProxyAlreadyExists();
        
        // Create proxy using CREATE2
        bytes memory bytecode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(address(beacon), owner, data)
        );
        
        assembly {
            proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        if (proxy == address(0)) revert("BeaconProxyFactory: proxy creation failed");
        
        emit ProxyCreated(owner, proxy, salt);
    }

    /// @notice Creates multiple proxies in a batch
    /// @param owners Array of owner addresses
    /// @param salts Array of unique salts
    /// @param dataArray Array of initialization data
    /// @return proxies Array of created proxy addresses
    function createProxyBatch(
        address[] memory owners,
        bytes32[] memory salts,
        bytes[] memory dataArray
    ) external returns (address[] memory proxies) {
        if (_paused) revert FactoryPausedError();
        if (owners.length != salts.length || salts.length != dataArray.length) revert ArraysLengthMismatch();
        
        proxies = new address[](owners.length);
        
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == address(0)) revert InvalidOwner();
            if (salts[i] == bytes32(0)) revert InvalidSalt();
            
            // Check if proxy already exists
            address predictedProxy = predictProxyAddress(owners[i], salts[i]);
            if (Address.isContract(predictedProxy)) revert ProxyAlreadyExists();
            
            // Create proxy using CREATE2
            bytes memory bytecode = abi.encodePacked(
                type(BeaconProxy).creationCode,
                abi.encode(address(beacon), owners[i], dataArray[i])
            );
            
            address proxy;
            bytes32 salt = salts[i];
            assembly {
                proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            }
            
            if (proxy == address(0)) revert("BeaconProxyFactory: proxy creation failed");
            
            proxies[i] = proxy;
        }
        
        emit BatchProxyCreated(owners, proxies, salts);
    }

    /// @notice Predicts the address of a proxy before creation
    /// @param owner Owner address
    /// @param salt Unique salt
    /// @return Predicted proxy address
    function predictProxyAddress(address owner, bytes32 salt) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(address(beacon), owner, "")
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );
        
        return address(uint160(uint256(hash)));
    }

    /// @notice Checks if a proxy exists at the predicted address
    /// @param owner Owner address
    /// @param salt Unique salt
    /// @return True if proxy exists, false otherwise
    function proxyExists(address owner, bytes32 salt) external view returns (bool) {
        address predictedAddress = predictProxyAddress(owner, salt);
        return Address.isContract(predictedAddress);
    }

    /// @notice Returns the beacon address
    /// @return Beacon address
    function getBeacon() external view returns (address) {
        return address(beacon);
    }

    /// @notice Returns the proxy implementation address
    /// @return Proxy implementation address
    function getProxyImplementation() external view returns (address) {
        return address(proxyImplementation);
    }

    /// @notice Pauses the factory (prevents new proxy creation)
    /// @dev Only owner can pause
    function pause() external onlyOwner {
        _paused = true;
        emit FactoryPaused(msg.sender);
    }

    /// @notice Unpauses the factory
    /// @dev Only owner can unpause
    function unpause() external onlyOwner {
        _paused = false;
        emit FactoryUnpaused(msg.sender);
    }

    /// @notice Returns whether the factory is paused
    /// @return True if paused, false otherwise
    function isPaused() external view returns (bool) {
        return _paused;
    }

    /// @notice Returns the current implementation from the beacon
    /// @return Current implementation address
    function getCurrentImplementation() external view returns (address) {
        return beacon.implementation();
    }

    /// @notice Returns the pending upgrade information from the beacon
    /// @return pendingImplementation Address of pending implementation
    /// @return upgradeTime When the upgrade can be executed
    /// @return timelockDuration Duration of the timelock
    function getPendingUpgrade() external view returns (address pendingImplementation, uint256 upgradeTime, uint256 timelockDuration) {
        return beacon.getPendingUpgrade();
    }

    /// @notice Returns whether the beacon is paused
    /// @return True if beacon is paused, false otherwise
    function isBeaconPaused() external view returns (bool) {
        return beacon.isPaused();
    }

    /// @notice Returns the rollback implementation from the beacon
    /// @return Rollback implementation address
    function getRollbackImplementation() external view returns (address) {
        return beacon.getRollbackImplementation();
    }

    /// @notice Computes the bytecode hash for proxy creation
    /// @param owner Owner address
    /// @param data Initialization data
    /// @return Bytecode hash
    function getProxyBytecodeHash(address owner, bytes memory data) public view returns (bytes32) {
        bytes memory bytecode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(address(beacon), owner, data)
        );
        return keccak256(bytecode);
    }

    /// @notice Returns the factory version
    /// @return Version string
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
} 