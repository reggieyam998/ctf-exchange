// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { CTFExchange } from "src/exchange/CTFExchange.sol";
import { USDC } from "src/dev/mocks/USDC.sol";
import { Deployer } from "src/dev/util/Deployer.sol";
import { IConditionalTokens } from "src/exchange/interfaces/IConditionalTokens.sol";
import { ExchangeBeacon } from "src/dev/mocks/ExchangeBeacon.sol";
import { BeaconProxyFactory } from "src/dev/mocks/BeaconProxyFactory.sol";
import { MockBeaconImplementation } from "src/dev/mocks/MockBeaconImplementation.sol";
import { MockGnosisSafeFactory } from "src/dev/mocks/MockGnosisSafeFactory.sol";

/// @title LocalDeployment
/// @notice Script to deploy CTF Exchange for local development
/// @dev Uses real ConditionalTokens contract via Deployer.ConditionalTokens()
contract LocalDeployment is Script {
    // Environment variables
    string public PK;
    string public ADMIN;
    string public RPC_URL;

    // Deployed contracts
    USDC public usdc;
    IConditionalTokens public ctf;
    MockBeaconImplementation public mockImpl;
    ExchangeBeacon public beacon;
    BeaconProxyFactory public beaconFactory;
    MockGnosisSafeFactory public safeFactory;
    CTFExchange public exchange;

    function run() public {
        // Load environment variables
        PK = vm.envString("PK");
        ADMIN = vm.envString("ADMIN");
        RPC_URL = vm.envString("RPC_URL");
        
        uint256 deployerPrivateKey = vm.parseUint(PK);
        address adminAddress = vm.parseAddress(ADMIN);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Mock USDC
        usdc = new USDC();
        console.log("Mock USDC deployed at:", address(usdc));

        // 2. Deploy Real ConditionalTokens (using Deployer.ConditionalTokens())
        ctf = IConditionalTokens(Deployer.ConditionalTokens());
        console.log("Real ConditionalTokens deployed at:", address(ctf));

        // 3. Deploy Mock Implementation for Beacon
        mockImpl = new MockBeaconImplementation();
        console.log("Mock Beacon Implementation deployed at:", address(mockImpl));

        // 4. Deploy Exchange Beacon (for proxy wallet upgrades)
        beacon = new ExchangeBeacon(address(mockImpl), adminAddress);
        console.log("Exchange Beacon deployed at:", address(beacon));

        // 5. Deploy Beacon Proxy Factory
        beaconFactory = new BeaconProxyFactory(address(beacon), adminAddress);
        console.log("Beacon Proxy Factory deployed at:", address(beaconFactory));

        // 6. Deploy Mock Gnosis Safe Factory
        address mockMasterCopy = address(0x1234567890123456789012345678901234567890); // Placeholder
        safeFactory = new MockGnosisSafeFactory(mockMasterCopy);
        console.log("Mock Gnosis Safe Factory deployed at:", address(safeFactory));

        // 7. Deploy CTF Exchange (with beacon proxy factory and safe factory)
        exchange = new CTFExchange(
            address(usdc),           // collateral
            address(ctf),            // ctf
            address(beaconFactory),  // proxyFactory (beacon-based)
            address(safeFactory)      // safeFactory (mock for local development)
        );
        console.log("CTF Exchange deployed at:", address(exchange));

        // 6. Configure exchange with admin roles
        exchange.addAdmin(adminAddress);
        exchange.addOperator(adminAddress);

        // 7. Verify admin roles are set correctly
        require(exchange.isAdmin(adminAddress), "Admin role not set");
        require(exchange.isOperator(adminAddress), "Operator role not set");

        // 8. Revoke deployer's authorization
        exchange.renounceAdminRole();
        exchange.renounceOperatorRole();

        vm.stopBroadcast();

        // 9. Verify deployment
        _verifyDeployment(adminAddress);
    }

    function _verifyDeployment(address adminAddress) internal view {
        console.log("\n=== Deployment Verification ===");
        console.log("Admin address:", adminAddress);
        console.log("USDC address:", address(usdc));
        console.log("CTF address:", address(ctf));
        console.log("Mock Beacon Implementation address:", address(mockImpl));
        console.log("Exchange Beacon address:", address(beacon));
        console.log("Beacon Proxy Factory address:", address(beaconFactory));
        console.log("Mock Gnosis Safe Factory address:", address(safeFactory));
        console.log("Exchange address:", address(exchange));
        
        // Verify exchange configuration
        require(exchange.getCollateral() == address(usdc), "Collateral not set correctly");
        require(exchange.getCtf() == address(ctf), "CTF not set correctly");
        
        // Verify beacon proxy system
        require(beacon.implementation() == address(mockImpl), "Beacon implementation not set correctly");
        require(beaconFactory.getBeacon() == address(beacon), "Factory beacon not set correctly");
        
        console.log("All verifications passed!");
    }

    /// @notice Test function to verify CTF functionality
    function testCTFFunctionality() public {
        console.log("\n=== Testing CTF Functionality ===");
        
        // Test basic CTF functions
        bytes32 questionId = keccak256("test-question");
        address oracle = vm.addr(1);
        
        // Prepare condition
        ctf.prepareCondition(oracle, questionId, 2);
        console.log("Condition prepared successfully");
        
        // Get condition ID
        bytes32 conditionId = ctf.getConditionId(oracle, questionId, 2);
        console.log("Condition ID:", vm.toString(conditionId));
        
        // Get outcome slot count
        uint256 outcomeSlotCount = ctf.getOutcomeSlotCount(conditionId);
        require(outcomeSlotCount == 2, "Outcome slot count should be 2");
        console.log("Outcome slot count verified");
        
        console.log("CTF functionality test passed!");
    }

    /// @notice Test function to verify beacon proxy system integration
    function testBeaconProxySystem() public {
        console.log("\n=== Testing Beacon Proxy System Integration ===");
        
        // Test beacon functionality
        address currentImpl = beacon.implementation();
        console.log("Current beacon implementation:", currentImpl);
        require(currentImpl == address(mockImpl), "Beacon implementation mismatch");
        
        // Test factory functionality
        address factoryBeacon = beaconFactory.getBeacon();
        console.log("Factory beacon address:", factoryBeacon);
        require(factoryBeacon == address(beacon), "Factory beacon mismatch");
        
        // Test proxy creation (basic test)
        address testOwner = vm.addr(999);
        bytes32 testSalt = keccak256("test-salt");
        
        address predictedProxy = beaconFactory.predictProxyAddress(testOwner, testSalt);
        console.log("Predicted proxy address:", predictedProxy);
        
        // Test that proxy doesn't exist yet
        bool proxyExists = beaconFactory.proxyExists(testOwner, testSalt);
        require(!proxyExists, "Proxy should not exist yet");
        console.log("Proxy existence check passed");
        
        console.log("Beacon proxy system integration test passed!");
    }
} 