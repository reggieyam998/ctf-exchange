// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import { Address } from "openzeppelin-contracts/utils/Address.sol";
import { BeaconProxy } from "./BeaconProxy.sol";
import { ExchangeBeacon } from "./ExchangeBeacon.sol";

/// @title PolymarketCompatibleProxyFactory
/// @notice Factory for creating beacon-based proxy wallets with Polymarket compatibility
/// @dev Combines Polymarket's proven patterns with our beacon upgrade improvements
contract PolymarketCompatibleProxyFactory is Ownable {
    ExchangeBeacon public immutable beacon;
    BeaconProxy public immutable proxyImplementation;
    
    // Events (matching Polymarket's pattern)
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

    /// @notice Creates a new beacon proxy for an owner (Polymarket-compatible)
    /// @param owner Owner address for the proxy
    /// @param salt Unique salt for deterministic address (Polymarket uses keccak256(owner))
    /// @param data Initialization data (optional)
    /// @return proxy Address of the created proxy
    function createProxy(address owner, bytes32 salt, bytes memory data) external returns (address proxy) {
        if (_paused) revert FactoryPausedError();
        if (owner == address(0)) revert InvalidOwner();
        if (salt == bytes32(0)) revert InvalidSalt();
        
        // Check if proxy already exists
        address predictedProxy = predictProxyAddress(owner, salt);
        if (Address.isContract(predictedProxy)) revert ProxyAlreadyExists();
        
        // Create proxy using CREATE2 (Polymarket's approach)
        bytes memory bytecode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(address(beacon), owner, data)
        );
        
        assembly {
            proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        if (proxy == address(0)) revert("PolymarketCompatibleProxyFactory: proxy creation failed");
        
        emit ProxyCreated(owner, proxy, salt);
    }

    /// @notice Creates multiple proxies in a batch (Polymarket-compatible)
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
            
            bytes32 salt = salts[i];
            address proxy;
            assembly {
                proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            }
            proxies[i] = proxy;
        }
        
        emit BatchProxyCreated(owners, proxies, salts);
    }

    /// @notice Predicts the proxy address for an owner and salt (Polymarket-compatible)
    /// @param owner The owner address
    /// @param salt The salt used for creation
    /// @return The predicted proxy address
    function predictProxyAddress(address owner, bytes32 salt) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(address(beacon), owner, "")
        );
        
        bytes32 hash = keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(bytecode)
        ));
        
        return address(uint160(uint256(hash)));
    }

    /// @notice Checks if a proxy exists at the predicted address
    /// @param owner The owner address
    /// @param salt The salt used for creation
    /// @return True if proxy exists, false otherwise
    function proxyExists(address owner, bytes32 salt) external view returns (bool) {
        address predictedProxy = predictProxyAddress(owner, salt);
        return Address.isContract(predictedProxy);
    }

    /// @notice Gets the salt for a user (Polymarket's pattern)
    /// @param user The user address
    /// @return The salt for the user
    function getSalt(address user) public pure returns (bytes32) {
        return keccak256(abi.encode(user));
    }

    /// @notice Computes proxy address for a user (Polymarket-compatible)
    /// @param user The user address
    /// @return The computed proxy address
    function computeProxyAddress(address user) external view returns (address) {
        bytes32 salt = getSalt(user);
        return predictProxyAddress(user, salt);
    }

    /// @notice Creates a proxy for a user if it doesn't exist (Polymarket's maybeMakeWallet pattern)
    /// @param user The user address
    /// @param data Initialization data
    /// @return proxy The proxy address (existing or newly created)
    function maybeCreateProxy(address user, bytes memory data) external returns (address proxy) {
        bytes32 salt = getSalt(user);
        address predictedProxy = predictProxyAddress(user, salt);
        
        if (Address.isContract(predictedProxy)) {
            return predictedProxy;
        }
        
        // Create the proxy using internal logic
        if (_paused) revert FactoryPausedError();
        if (user == address(0)) revert InvalidOwner();
        if (salt == bytes32(0)) revert InvalidSalt();
        
        // Create proxy using CREATE2
        bytes memory bytecode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(address(beacon), user, data)
        );
        
        assembly {
            proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        if (proxy == address(0)) revert("PolymarketCompatibleProxyFactory: proxy creation failed");
        
        emit ProxyCreated(user, proxy, salt);
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

    /// @notice Gets the beacon address
    /// @return The beacon address
    function getBeacon() external view returns (address) {
        return address(beacon);
    }

    /// @notice Gets the proxy implementation address
    /// @return The proxy implementation address
    function getProxyImplementation() external view returns (address) {
        return address(proxyImplementation);
    }

    /// @notice Checks if factory is paused
    /// @return True if paused, false otherwise
    function paused() external view returns (bool) {
        return _paused;
    }
} 