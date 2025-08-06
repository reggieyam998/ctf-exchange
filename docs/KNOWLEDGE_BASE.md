# CTF Exchange Knowledge Base

## Overview

This knowledge base documents the architecture, design decisions, and implementation details for the CTF Exchange deployment project.

## Table of Contents

1. [Proxy Wallet Architecture](#proxy-wallet-architecture)
2. [Beacon Pattern Implementation](#beacon-pattern-implementation)
3. [Gnosis Safe Integration](#gnosis-safe-integration)
4. [Signature Types](#signature-types)
5. [Upgrade Mechanisms](#upgrade-mechanisms)
6. [Security Considerations](#security-considerations)
7. [Fee Collection System](#fee-collection-system)
8. [Bytecode Deployment Address Discrepancies](#bytecode-deployment-address-discrepancies)

---

## Proxy Wallet Architecture

### Problem Statement

When a market contract (exchange) is upgraded to a new address, existing proxy wallets become obsolete because they still point to the old implementation. This creates a critical user experience issue where users lose access to their trading capabilities.

### Proxy Wallet Upgrade Approaches

#### Approach 1: Factory-Based Upgrades (Current Polymarket)

**How it works:**
```solidity
// From CTFExchange.sol
function setProxyFactory(address _newProxyFactory) external onlyAdmin {
    _setProxyFactory(_newProxyFactory);
}

function setSafeFactory(address _newSafeFactory) external onlyAdmin {
    _setSafeFactory(_newSafeFactory);
}
```

**Architecture:**
```
User Proxy → Factory → Implementation → Market Contract
```

**Upgrade Process:**
1. Admin deploys new factory with new implementation
2. Admin calls `setProxyFactory(newFactory)`
3. New proxies use new factory/implementation
4. Old proxies continue using old factory/implementation

**Pros:**
- ✅ **Proven in Production**: Used by Polymarket
- ✅ **Backwards Compatible**: Supports existing system
- ✅ **Gradual Migration**: Can migrate users over time
- ✅ **Simple Implementation**: Easy to understand and implement

**Cons:**
- ❌ **Doesn't Solve Upgrade Problem**: Existing proxies become obsolete
- ❌ **Complex User Experience**: Users need to migrate to new proxies
- ❌ **Address Changes**: New proxy addresses for all users
- ❌ **Fragmented System**: Old and new proxies coexist

#### Approach 2: Beacon Proxy Pattern (Our Solution)

**How it works:**
```solidity
// Beacon contract that can be upgraded
contract ExchangeBeacon {
    address public implementation;
    address public admin;
    
    function upgradeTo(address newImplementation) external onlyAdmin {
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }
}

// Proxy wallets that read from beacon
contract BeaconProxy {
    address public beacon;
    
    function _implementation() internal view returns (address) {
        return ExchangeBeacon(beacon).implementation();
    }
}
```

**Architecture:**
```
User Proxy → Beacon → Implementation → Market Contract
```

**Upgrade Process:**
1. Admin deploys new implementation
2. Admin calls `beacon.upgradeTo(newImplementation)`
3. All proxies automatically use new implementation
4. No user action required

**Pros:**
- ✅ **Seamless Upgrades**: All proxies upgrade automatically
- ✅ **No User Action**: Users don't need to migrate
- ✅ **Address Stability**: Proxy addresses remain the same
- ✅ **Unified System**: All proxies use same implementation
- ✅ **Future-Proof**: Supports unlimited upgrades

**Cons:**
- ❌ **Complex Implementation**: More complex than factory pattern
- ❌ **New Pattern**: Less battle-tested than factory pattern
- ❌ **Beacon Dependency**: Proxies depend on beacon contract

### Implementation Details

#### Beacon Contract:
```solidity
// From ExchangeBeacon.sol
contract ExchangeBeacon {
    address public implementation;
    address public admin;
    
    event Upgraded(address indexed implementation);
    
    constructor(address _implementation, address _admin) {
        implementation = _implementation;
        admin = _admin;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Beacon: caller is not admin");
        _;
    }
    
    function upgradeTo(address newImplementation) external onlyAdmin {
        require(newImplementation != address(0), "Beacon: invalid implementation");
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }
}
```

#### Beacon Proxy:
```solidity
// From BeaconProxy.sol
contract BeaconProxy {
    address public beacon;
    
    constructor(address _beacon) {
        beacon = _beacon;
    }
    
    function _implementation() internal view returns (address) {
        return ExchangeBeacon(beacon).implementation();
    }
    
    function _delegate(address implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    fallback() external payable {
        _delegate(_implementation());
    }
    
    receive() external payable {
        _delegate(_implementation());
    }
}
```

### Migration Strategy

#### Phase 1: Deploy Beacon System
1. Deploy `ExchangeBeacon` with current implementation
2. Deploy `BeaconProxy` factory
3. Test beacon upgrade functionality

#### Phase 2: Gradual Migration
1. Deploy new proxies using beacon pattern
2. Migrate existing users to new proxies
3. Maintain backward compatibility

#### Phase 3: Full Migration
1. All users migrated to beacon proxies
2. Deprecate old factory-based proxies
3. Complete system upgrade

---

## Beacon Pattern Implementation

### Overview

The beacon pattern is a proxy upgrade pattern that allows all proxy contracts to be upgraded simultaneously by updating a single beacon contract.

### Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Proxy 1   │    │   Proxy 2   │    │   Proxy N   │
│             │    │             │    │             │
│ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │
│ │ Beacon  │ │    │ │ Beacon  │ │    │ │ Beacon  │ │
│ │ Address │ │    │ │ Address │ │    │ │ Address │ │
│ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌─────────────┐
                    │    Beacon   │
                    │             │
                    │ ┌─────────┐ │
                    │ │Implementation│ │
                    │ │ Address │ │
                    │ └─────────┘ │
                    └─────────────┘
```

### Key Components

#### 1. Beacon Contract
- **Purpose**: Stores the current implementation address
- **Upgrade Mechanism**: Can be upgraded by admin
- **Event Emission**: Emits events on upgrades

#### 2. Beacon Proxy
- **Purpose**: Delegates calls to implementation via beacon
- **Beacon Reference**: Stores beacon contract address
- **Dynamic Implementation**: Reads implementation from beacon

#### 3. Implementation Contract
- **Purpose**: Contains the actual business logic
- **Upgradeable**: Can be replaced by beacon upgrade
- **Stateless**: No state stored in implementation

### Implementation Details

#### Beacon Contract
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ExchangeBeacon {
    address public implementation;
    address public admin;
    
    event Upgraded(address indexed implementation);
    
    constructor(address _implementation, address _admin) {
        implementation = _implementation;
        admin = _admin;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Beacon: caller is not admin");
        _;
    }
    
    function upgradeTo(address newImplementation) external onlyAdmin {
        require(newImplementation != address(0), "Beacon: invalid implementation");
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }
}
```

#### Beacon Proxy
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExchangeBeacon.sol";

contract BeaconProxy {
    address public beacon;
    
    constructor(address _beacon) {
        beacon = _beacon;
    }
    
    function _implementation() internal view returns (address) {
        return ExchangeBeacon(beacon).implementation();
    }
    
    function _delegate(address implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    fallback() external payable {
        _delegate(_implementation());
    }
    
    receive() external payable {
        _delegate(_implementation());
    }
}
```

### Upgrade Process

#### 1. Deploy New Implementation
```bash
# Deploy new implementation contract
forge create NewImplementation --rpc-url $RPC_URL
```

#### 2. Upgrade Beacon
```solidity
// Call upgradeTo on beacon contract
beacon.upgradeTo(newImplementationAddress);
```

#### 3. Verify Upgrade
```solidity
// Check new implementation address
address newImpl = beacon.implementation();
require(newImpl == newImplementationAddress, "Upgrade failed");
```

### Security Considerations

#### 1. Admin Controls
- **Multi-Sig**: Use multi-signature wallet for admin
- **Timelock**: Implement timelock for upgrades
- **Access Control**: Restrict upgrade permissions

#### 2. Implementation Validation
- **Address Validation**: Ensure implementation is not zero address
- **Contract Validation**: Verify implementation is a contract
- **Compatibility**: Ensure new implementation is compatible

#### 3. Upgrade Safety
- **Testing**: Thoroughly test upgrades on testnet
- **Rollback Plan**: Have rollback mechanism ready
- **Monitoring**: Monitor system after upgrades

### Benefits

#### 1. Unified Upgrades
- **Single Point**: All proxies upgrade from single beacon
- **Consistency**: All proxies use same implementation
- **Simplicity**: No need to upgrade individual proxies

#### 2. Gas Efficiency
- **Shared Storage**: Implementation address stored once
- **Reduced Overhead**: Minimal gas cost for upgrades
- **Optimized Calls**: Efficient delegatecall mechanism

#### 3. User Experience
- **Seamless**: Users don't notice upgrades
- **No Migration**: No user action required
- **Address Stability**: Proxy addresses remain constant

### Limitations

#### 1. Complexity
- **Learning Curve**: More complex than simple proxies
- **Debugging**: Harder to debug delegatecall issues
- **Testing**: More complex testing requirements

#### 2. Dependencies
- **Beacon Dependency**: Proxies depend on beacon contract
- **Single Point**: Beacon becomes single point of failure
- **Coordination**: Requires coordination for upgrades

#### 3. Gas Costs
- **Initial Deployment**: Higher initial deployment cost
- **Beacon Calls**: Additional gas for beacon lookups
- **Upgrade Costs**: Gas costs for beacon upgrades

---

## Gnosis Safe Integration

### Overview

The CTF Exchange integrates with Gnosis Safe for secure multi-signature wallet functionality. This provides enhanced security for admin operations and fee collection.

### Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Gnosis    │    │   Beacon    │    │  Exchange   │
│    Safe     │    │   Proxy     │    │  Contract   │
│             │    │             │    │             │
│ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │
│ │ Multi-  │ │    │ │ Beacon  │ │    │ │ Trading │ │
│ │ Signature│ │    │ │ Address │ │    │ │ Logic   │ │
│ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌─────────────┐
                    │   Factory   │
                    │             │
                    │ ┌─────────┐ │
                    │ │ Safe    │ │
                    │ │ Creation│ │
                    │ └─────────┘ │
                    └─────────────┘
```

### Key Components

#### 1. Gnosis Safe Factory
- **Purpose**: Creates new Gnosis Safe instances
- **Configuration**: Configurable threshold and signers
- **Integration**: Integrated with beacon proxy system

#### 2. Beacon Proxy
- **Purpose**: Delegates calls to implementation
- **Safe Integration**: Supports safe-based operations
- **Upgradeable**: Can be upgraded via beacon

#### 3. Exchange Contract
- **Purpose**: Core trading functionality
- **Safe Support**: Compatible with safe operations
- **Fee Collection**: Integrated fee collection system

### Implementation Details

#### Safe Factory Integration
```solidity
// From PolymarketCompatibleProxyFactory.sol
contract PolymarketCompatibleProxyFactory {
    address public beacon;
    address public safeFactory;
    
    constructor(address _beacon, address _safeFactory) {
        beacon = _beacon;
        safeFactory = _safeFactory;
    }
    
    function createProxy(
        address[] memory owners,
        uint256 threshold,
        bytes memory data
    ) external returns (address proxy, address safe) {
        // Create safe
        safe = GnosisSafeFactory(safeFactory).createSafe(
            owners,
            threshold,
            data
        );
        
        // Create proxy
        proxy = new BeaconProxy(beacon);
        
        // Initialize proxy with safe
        BeaconProxy(proxy).initialize(safe);
        
        return (proxy, safe);
    }
}
```

#### Safe-Compatible Proxy
```solidity
// From BeaconProxy.sol
contract BeaconProxy {
    address public beacon;
    address public safe;
    
    constructor(address _beacon) {
        beacon = _beacon;
    }
    
    function initialize(address _safe) external {
        require(safe == address(0), "Already initialized");
        safe = _safe;
    }
    
    modifier onlySafe() {
        require(msg.sender == safe, "Only safe can call");
        _;
    }
    
    function _implementation() internal view returns (address) {
        return ExchangeBeacon(beacon).implementation();
    }
    
    function _delegate(address implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    fallback() external payable onlySafe {
        _delegate(_implementation());
    }
    
    receive() external payable onlySafe {
        _delegate(_implementation());
    }
}
```

### Security Features

#### 1. Multi-Signature Requirements
- **Threshold**: Configurable signature threshold
- **Owners**: Multiple safe owners
- **Validation**: Signature validation before execution

#### 2. Access Control
- **Safe-Only**: Only safe can call proxy functions
- **Owner Validation**: Validate safe ownership
- **Permission Checks**: Check permissions before operations

#### 3. Upgrade Safety
- **Beacon Control**: Safe controls beacon upgrades
- **Implementation Validation**: Validate new implementations
- **Rollback Capability**: Ability to rollback upgrades

### Integration Benefits

#### 1. Enhanced Security
- **Multi-Sig**: Multiple signatures required for operations
- **Access Control**: Granular access control
- **Audit Trail**: Complete operation audit trail

#### 2. User Experience
- **Familiar Interface**: Users familiar with Gnosis Safe
- **Easy Management**: Easy safe management
- **Integration**: Seamless integration with existing tools

#### 3. Operational Efficiency
- **Automated**: Automated safe creation
- **Scalable**: Scalable safe management
- **Maintainable**: Easy to maintain and upgrade

---

## Signature Types

### Overview

The CTF Exchange supports multiple signature types for secure transaction execution and user authentication.

### Signature Types

#### 1. EIP-712 Signatures
- **Purpose**: Structured data signing
- **Format**: Type-safe signature format
- **Security**: Enhanced security over raw signatures

#### 2. Personal Signatures
- **Purpose**: Simple message signing
- **Format**: Standard Ethereum signature format
- **Compatibility**: Compatible with most wallets

#### 3. Multi-Signature Signatures
- **Purpose**: Multi-party transaction approval
- **Format**: Gnosis Safe signature format
- **Security**: Enhanced security for critical operations

### Implementation Details

#### EIP-712 Signatures
```solidity
// From SignatureVerifier.sol
contract SignatureVerifier {
    bytes32 public constant DOMAIN_SEPARATOR = keccak256(
        abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("CTF Exchange")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        )
    );
    
    function verifySignature(
        bytes32 hash,
        bytes memory signature,
        address signer
    ) internal pure returns (bool) {
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hash)
        );
        
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        address recoveredSigner = ecrecover(ethSignedHash, v, r, s);
        
        return recoveredSigner == signer;
    }
    
    function splitSignature(bytes memory signature) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(signature.length == 65, "Invalid signature length");
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
    }
}
```

#### Personal Signatures
```solidity
// From PersonalSignatureVerifier.sol
contract PersonalSignatureVerifier {
    function verifyPersonalSignature(
        bytes32 hash,
        bytes memory signature,
        address signer
    ) internal pure returns (bool) {
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        address recoveredSigner = ecrecover(ethSignedHash, v, r, s);
        
        return recoveredSigner == signer;
    }
}
```

#### Multi-Signature Signatures
```solidity
// From MultiSignatureVerifier.sol
contract MultiSignatureVerifier {
    function verifyMultiSignature(
        bytes32 hash,
        bytes memory signatures,
        address[] memory signers,
        uint256 threshold
    ) internal pure returns (bool) {
        require(signatures.length >= threshold * 65, "Insufficient signatures");
        require(signers.length >= threshold, "Insufficient signers");
        
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        
        address[] memory recoveredSigners = new address[](threshold);
        uint256 recoveredCount = 0;
        
        for (uint256 i = 0; i < threshold; i++) {
            bytes memory signature = new bytes(65);
            for (uint256 j = 0; j < 65; j++) {
                signature[j] = signatures[i * 65 + j];
            }
            
            (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
            address recoveredSigner = ecrecover(ethSignedHash, v, r, s);
            
            // Check if signer is authorized
            bool isAuthorized = false;
            for (uint256 k = 0; k < signers.length; k++) {
                if (recoveredSigner == signers[k]) {
                    isAuthorized = true;
                    break;
                }
            }
            
            if (isAuthorized) {
                recoveredSigners[recoveredCount] = recoveredSigner;
                recoveredCount++;
            }
        }
        
        return recoveredCount >= threshold;
    }
}
```

### Security Considerations

#### 1. Signature Validation
- **Format Validation**: Validate signature format
- **Length Checks**: Check signature length
- **Recovery Validation**: Validate recovered address

#### 2. Replay Protection
- **Nonce Usage**: Use nonces for replay protection
- **Timestamp Validation**: Validate timestamps
- **Unique Messages**: Ensure message uniqueness

#### 3. Signer Authorization
- **Authorized Signers**: Validate signer authorization
- **Threshold Checks**: Check signature thresholds
- **Permission Validation**: Validate signer permissions

### Use Cases

#### 1. Order Signing
- **Purpose**: Sign trading orders
- **Type**: EIP-712 signatures
- **Security**: Enhanced security for orders

#### 2. Admin Operations
- **Purpose**: Admin operation approval
- **Type**: Multi-signature signatures
- **Security**: Enhanced security for admin operations

#### 3. User Authentication
- **Purpose**: User authentication
- **Type**: Personal signatures
- **Security**: Simple user authentication

---

## Upgrade Mechanisms

### Overview

The CTF Exchange implements multiple upgrade mechanisms to ensure system flexibility and maintainability.

### Upgrade Types

#### 1. Beacon Upgrades
- **Purpose**: Upgrade all proxies simultaneously
- **Mechanism**: Update beacon implementation
- **Scope**: System-wide upgrades

#### 2. Implementation Upgrades
- **Purpose**: Upgrade individual implementations
- **Mechanism**: Deploy new implementation
- **Scope**: Feature-specific upgrades

#### 3. Factory Upgrades
- **Purpose**: Upgrade proxy factories
- **Mechanism**: Deploy new factory
- **Scope**: Factory-specific upgrades

### Implementation Details

#### Beacon Upgrade Process
```solidity
// From ExchangeBeacon.sol
contract ExchangeBeacon {
    address public implementation;
    address public admin;
    
    event Upgraded(address indexed implementation);
    
    function upgradeTo(address newImplementation) external onlyAdmin {
        require(newImplementation != address(0), "Beacon: invalid implementation");
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }
}
```

#### Implementation Upgrade Process
```solidity
// From UpgradeableImplementation.sol
contract UpgradeableImplementation {
    address public beacon;
    
    constructor(address _beacon) {
        beacon = _beacon;
    }
    
    modifier onlyBeacon() {
        require(msg.sender == beacon, "Only beacon can call");
        _;
    }
    
    function upgrade() external onlyBeacon {
        // Upgrade logic here
    }
}
```

#### Factory Upgrade Process
```solidity
// From PolymarketCompatibleProxyFactory.sol
contract PolymarketCompatibleProxyFactory {
    address public beacon;
    address public safeFactory;
    
    function upgradeBeacon(address newBeacon) external onlyAdmin {
        beacon = newBeacon;
        emit BeaconUpgraded(newBeacon);
    }
    
    function upgradeSafeFactory(address newSafeFactory) external onlyAdmin {
        safeFactory = newSafeFactory;
        emit SafeFactoryUpgraded(newSafeFactory);
    }
}
```

### Security Considerations

#### 1. Access Control
- **Admin Controls**: Restrict upgrade permissions
- **Multi-Sig**: Use multi-signature for upgrades
- **Timelock**: Implement timelock for upgrades

#### 2. Validation
- **Implementation Validation**: Validate new implementations
- **Compatibility Checks**: Check upgrade compatibility
- **Testing**: Thorough testing before upgrades

#### 3. Rollback
- **Rollback Plan**: Have rollback mechanism ready
- **Backup**: Maintain backup implementations
- **Monitoring**: Monitor system after upgrades

### Upgrade Process

#### 1. Pre-Upgrade
- **Testing**: Test upgrades on testnet
- **Validation**: Validate upgrade compatibility
- **Backup**: Create backup implementations

#### 2. Upgrade Execution
- **Deployment**: Deploy new implementation
- **Beacon Update**: Update beacon implementation
- **Verification**: Verify upgrade success

#### 3. Post-Upgrade
- **Monitoring**: Monitor system performance
- **Validation**: Validate system functionality
- **Rollback**: Rollback if issues arise

---

## Security Considerations

### Overview

The CTF Exchange implements comprehensive security measures to protect user funds and system integrity.

### Security Measures

#### 1. Access Control
- **Admin Controls**: Restricted admin access
- **Multi-Sig**: Multi-signature for critical operations
- **Permission System**: Granular permission system

#### 2. Upgrade Security
- **Beacon Pattern**: Secure upgrade mechanism
- **Implementation Validation**: Validate implementations
- **Rollback Capability**: Ability to rollback upgrades

#### 3. Transaction Security
- **Signature Validation**: Validate all signatures
- **Replay Protection**: Protect against replay attacks
- **Input Validation**: Validate all inputs

### Implementation Details

#### Access Control
```solidity
// From AccessControl.sol
contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;
    mapping(bytes32 => address) private _roleAdmin;
    
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    
    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: sender does not have role");
        _;
    }
    
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }
    
    function grantRole(bytes32 role, address account) external onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }
    
    function revokeRole(bytes32 role, address account) external onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }
    
    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }
    
    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }
}
```

#### Upgrade Security
```solidity
// From UpgradeableContract.sol
contract UpgradeableContract {
    address public implementation;
    address public admin;
    
    event Upgraded(address indexed implementation);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call");
        _;
    }
    
    function upgradeTo(address newImplementation) external onlyAdmin {
        require(newImplementation != address(0), "Invalid implementation");
        require(isContract(newImplementation), "Implementation is not a contract");
        
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }
    
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
```

#### Transaction Security
```solidity
// From TransactionSecurity.sol
contract TransactionSecurity {
    mapping(bytes32 => bool) private _executed;
    
    event TransactionExecuted(bytes32 indexed txHash, address indexed executor);
    
    modifier onlyOnce(bytes32 txHash) {
        require(!_executed[txHash], "Transaction already executed");
        _;
        _executed[txHash] = true;
    }
    
    function executeTransaction(
        bytes32 txHash,
        bytes memory data,
        bytes memory signature
    ) external onlyOnce(txHash) {
        require(verifySignature(txHash, signature, msg.sender), "Invalid signature");
        
        // Execute transaction
        (bool success, ) = address(this).call(data);
        require(success, "Transaction execution failed");
        
        emit TransactionExecuted(txHash, msg.sender);
    }
    
    function verifySignature(
        bytes32 hash,
        bytes memory signature,
        address signer
    ) internal pure returns (bool) {
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        address recoveredSigner = ecrecover(ethSignedHash, v, r, s);
        
        return recoveredSigner == signer;
    }
}
```

### Security Best Practices

#### 1. Code Review
- **Thorough Review**: Comprehensive code review
- **Security Audit**: Professional security audit
- **Testing**: Extensive testing

#### 2. Access Management
- **Least Privilege**: Principle of least privilege
- **Multi-Sig**: Multi-signature for critical operations
- **Regular Review**: Regular access review

#### 3. Monitoring
- **Event Monitoring**: Monitor all events
- **Anomaly Detection**: Detect anomalies
- **Alert System**: Alert system for issues

---

## Fee Collection System

### Overview

The CTF Exchange implements a comprehensive fee collection system that charges fees on both BUY and SELL transactions to generate revenue for the exchange operator.

### Fee Structure

#### 1. Fee Types
- **Trading Fees**: Fees on trading transactions
- **Operator Fees**: Fees collected by operator
- **Platform Fees**: Platform-specific fees

#### 2. Fee Calculation
- **Percentage-Based**: Fees calculated as percentage of transaction value
- **Asset-Specific**: Fees collected in the most liquid asset
- **Symmetric Design**: Fair pricing for both BUY and SELL sides

#### 3. Fee Collection
- **Automatic Collection**: Fees collected automatically
- **Operator Receipt**: Fees sent to operator address
- **Event Logging**: Comprehensive fee event logging

### Implementation Details

#### Fee Rate Management
```solidity
// From Fees.sol
contract Fees {
    uint256 internal constant MAX_FEE_RATE_BIPS = 1000; // 10%
    uint256 internal feeRateBips = 200; // 2% default
    
    function getFeeRate() public view returns (uint256) {
        return feeRateBips;
    }
    
    function setFeeRate(uint256 newFeeRate) external onlyAdmin {
        require(newFeeRate <= MAX_FEE_RATE_BIPS, "Fee rate too high");
        feeRateBips = newFeeRate;
        emit FeeRateUpdated(newFeeRate);
    }
    
    function calculateFee(uint256 amount) public view returns (uint256) {
        return (amount * feeRateBips) / 10000;
    }
}
```

#### Fee Charging
```solidity
// From Trading.sol
contract Trading {
    function _chargeFee(address payer, address receiver, uint256 tokenId, uint256 fee) internal {
        if (fee > 0) {
            _transfer(payer, receiver, tokenId, fee);
            emit FeeCharged(receiver, tokenId, fee);
        }
    }
    
    function buyTokens(uint256 tokenId, uint256 amount) external {
        uint256 fee = calculateFee(amount);
        uint256 netAmount = amount - fee;
        
        // Transfer tokens to buyer
        _transfer(address(this), msg.sender, tokenId, netAmount);
        
        // Charge fee
        _chargeFee(msg.sender, operator, tokenId, fee);
        
        emit TokensBought(msg.sender, tokenId, amount, fee);
    }
    
    function sellTokens(uint256 tokenId, uint256 amount) external {
        uint256 fee = calculateFee(amount);
        uint256 netAmount = amount - fee;
        
        // Transfer tokens from seller
        _transfer(msg.sender, address(this), tokenId, amount);
        
        // Charge fee
        _chargeFee(msg.sender, operator, tokenId, fee);
        
        emit TokensSold(msg.sender, tokenId, amount, fee);
    }
}
```

### Fee Examples

#### Example 1: BUY 100 tokens @ $0.50 (2% fee)
- **Receive**: 100 outcome tokens
- **Fee**: 2% × 100 = 2 outcome tokens
- **Net**: 98 outcome tokens
- **Operator Receives**: 2 outcome tokens

#### Example 2: SELL 100 tokens @ $0.50 (2% fee)
- **Receive**: 50 USDC (100 × $0.50)
- **Fee**: 2% × 50 = 1 USDC
- **Net**: 49 USDC
- **Operator Receives**: 1 USDC

#### Example 3: BUY 100 tokens @ $0.10 (2% fee)
- **Receive**: 100 outcome tokens
- **Fee**: 2% × 100 = 2 outcome tokens
- **Net**: 98 outcome tokens
- **Operator Receives**: 2 outcome tokens

#### Example 4: SELL 100 tokens @ $0.90 (2% fee)
- **Receive**: 90 USDC (100 × $0.90)
- **Fee**: 2% × 90 = 1.8 USDC
- **Net**: 88.2 USDC
- **Operator Receives**: 1.8 USDC

### Security Considerations

#### 1. Fee Rate Limits
- **Maximum Rate**: Hard-coded maximum of 10%
- **Admin Controls**: Only admins can modify fee structures
- **Audit Trail**: Log all fee rate changes

#### 2. Fee Collection Security
- **Operator Validation**: Verify operator addresses
- **Asset Validation**: Ensure correct asset transfers
- **Event Logging**: Comprehensive fee event logging

#### 3. Market Integrity
- **Symmetric Design**: Maintain fee symmetry for complementary positions
- **Arbitrage Prevention**: Prevent fee-based arbitrage opportunities
- **Price Impact**: Minimize fee impact on market prices

---

## Bytecode Deployment Address Discrepancies

### Overview

When deploying contracts using hardcoded bytecode (as opposed to Foundry's standard compilation process), there can be discrepancies between the expected address shown in Foundry's broadcast logs and the actual deployed address on the blockchain.

### Problem Statement

**Issue**: Foundry's broadcast log shows one address, but the contract is actually deployed at a different address on the blockchain (e.g., Ganache).

**Example**:
- **Broadcast Log**: `0x5b73c5498c1e3b4dba84de0f1833c4a029d90519`
- **Actual Deployment**: `0x1B218bDC9D1621101039AC8aC8B0b66BBe2f8a7f` (from Ganache log)

### Root Cause Analysis

#### 1. **Bytecode Deployment vs Normal Contract Deployment**

**Normal Contract Deployment** (e.g., `01_deploy_local.s.sol`):
- Uses Foundry's standard contract compilation and deployment
- Foundry can accurately predict the contract address because it knows the exact bytecode and deployment parameters
- Broadcast logs show the correct address

**Bytecode Deployment** (e.g., `10_simple_ctf_deployment.s.sol`):
- Uses hardcoded bytecode with `CREATE` opcode
- Foundry's broadcast log shows the **expected** address based on its calculation
- But **Ganache** uses its own address calculation logic, which may differ

#### 2. **Address Calculation Differences**

**Foundry's Address Calculation**:
```
expected_address = keccak256(rlp.encode([sender, nonce]))
```

**Ganache's Address Calculation**:
- May use different nonce values
- May use different sender addresses
- May have different address calculation logic

#### 3. **Evidence from Deployment Logs**

**Script 10** (bytecode deployment):
- Broadcast log shows: `0x5b73c5498c1e3b4dba84de0f1833c4a029d90519`
- Actual deployment: `0x1B218bDC9D1621101039AC8aC8B0b66BBe2f8a7f` (from Ganache log)

**Script 01** (normal deployment):
- All addresses match between broadcast log and actual deployment

### Impact and Scope

#### 1. **This is NOT a Problem for Other Contracts**

Other contracts in the project (like `CTFExchange`, `USDC`, `PolymarketCompatibleProxyFactory`) are deployed using Foundry's standard compilation process, so their broadcast logs show the correct addresses.

#### 2. **Specific to Bytecode Deployment**

This issue only affects:
- Contracts deployed using hardcoded bytecode
- Contracts using `CREATE` opcode directly
- Contracts bypassing Foundry's normal compilation pipeline

### Solutions and Best Practices

#### 1. **Always Check Actual Deployment Address**

When using bytecode deployment:
```bash
# Check actual deployment address from Ganache log
# or use cast to verify deployment
cast code 0x1B218bDC9D1621101039AC8aC8B0b66BBe2f8a7f --rpc-url http://localhost:7545
```

#### 2. **Update Scripts with Correct Addresses**

After deployment, update test scripts with the actual deployed address:
```solidity
// Update with actual deployed address from Ganache log
address public constant CTF_ADDRESS = address(0x1B218bDC9D1621101039AC8aC8B0b66BBe2f8a7f);
```

#### 3. **Use Foundry's Standard Deployment When Possible**

Prefer standard contract deployment over bytecode deployment:
```solidity
// Standard deployment (recommended)
CTFExchange exchange = new CTFExchange(...);

// Bytecode deployment (use only when necessary)
bytes memory bytecode = hex"...";
address deployedAddress;
assembly {
    deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
}
```

#### 4. **Document Deployment Addresses**

Always document the actual deployed addresses:
```markdown
## Deployment Addresses

### Local Development (Ganache)
- CTF Contract: `0x1B218bDC9D1621101039AC8aC8B0b66BBe2f8a7f`
- Exchange Contract: `0xd3d9c2977bf11e1a0bb836128074110daca5267b`
- USDC Contract: `0xfb468291bc2959a9a360d3868ecb02e9eeb72c15`

### Testnet
- CTF Contract: `0x...`
- Exchange Contract: `0x...`
- USDC Contract: `0x...`
```

### Technical Details

#### 1. **CREATE Opcode Behavior**

The `CREATE` opcode calculates addresses using:
```solidity
address = keccak256(rlp.encode([sender, nonce]))
```

However, different environments may:
- Use different nonce values
- Use different sender addresses
- Have different RLP encoding implementations

#### 2. **Foundry's Broadcast Log**

Foundry's broadcast log shows the **expected** address based on:
- The sender address it uses
- The nonce it expects
- Its own address calculation logic

#### 3. **Ganache's Address Calculation**

Ganache may use:
- Different nonce tracking
- Different sender address handling
- Different address calculation logic

### Prevention Strategies

#### 1. **Use Standard Deployment**

Whenever possible, use Foundry's standard deployment:
```solidity
// ✅ Recommended
MyContract contract = new MyContract(...);

// ❌ Avoid when possible
bytes memory bytecode = hex"...";
address contract = deployBytecode(bytecode);
```

#### 2. **Verify Deployments**

Always verify deployments after bytecode deployment:
```solidity
// Verify deployment
require(contract.code.length > 0, "Contract not deployed");
```

#### 3. **Test Addresses**

Test with actual deployed addresses:
```solidity
// Use actual deployed address in tests
address deployedAddress = 0x1B218bDC9D1621101039AC8aC8B0b66BBe2f8a7f;
MyContract contract = MyContract(deployedAddress);
```

### Conclusion

**This is specifically a bytecode deployment issue**, not a broader problem. The discrepancy occurs because:

1. **Bytecode deployment** bypasses Foundry's normal compilation pipeline
2. **Foundry's broadcast log** shows the expected address based on its calculation
3. **Ganache** uses its own address calculation, resulting in a different actual address

**Solution**: Always check the actual deployment address from the blockchain (Ganache log) when using bytecode deployment, rather than relying on Foundry's broadcast log.

---

## Conclusion

The CTF Exchange implements a comprehensive system with:

- ✅ **Secure Architecture**: Beacon proxy pattern for seamless upgrades
- ✅ **Multi-Signature Support**: Gnosis Safe integration for enhanced security
- ✅ **Flexible Fee System**: Balanced fee collection for sustainable revenue
- ✅ **Robust Security**: Comprehensive security measures and access controls
- ✅ **Upgrade Mechanisms**: Multiple upgrade paths for system flexibility
- ✅ **Address Management**: Proper handling of bytecode deployment addresses

This system ensures **sustainable operation** while maintaining **security, flexibility, and user experience**. 