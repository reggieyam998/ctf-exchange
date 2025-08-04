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

/// @title TestLocalDeployment
/// @notice Comprehensive test script for local deployment with beacon proxy system
contract TestLocalDeployment is Script {
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
        console.log("=== Testing Local Deployment with Beacon Proxy System ===");
        
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

        // 2. Deploy Real ConditionalTokens
        ctf = IConditionalTokens(Deployer.ConditionalTokens());
        console.log("Real ConditionalTokens deployed at:", address(ctf));

        // 3. Deploy Mock Implementation for Beacon
        mockImpl = new MockBeaconImplementation();
        console.log("Mock Beacon Implementation deployed at:", address(mockImpl));

        // 4. Deploy Exchange Beacon
        beacon = new ExchangeBeacon(address(mockImpl), adminAddress);
        console.log("Exchange Beacon deployed at:", address(beacon));

        // 5. Deploy Beacon Proxy Factory
        beaconFactory = new BeaconProxyFactory(address(beacon), adminAddress);
        console.log("Beacon Proxy Factory deployed at:", address(beaconFactory));

        // 6. Deploy Mock Gnosis Safe Factory
        address mockMasterCopy = address(0x1234567890123456789012345678901234567890); // Placeholder
        safeFactory = new MockGnosisSafeFactory(mockMasterCopy);
        console.log("Mock Gnosis Safe Factory deployed at:", address(safeFactory));

        // 7. Deploy CTF Exchange
        exchange = new CTFExchange(
            address(usdc),           // collateral
            address(ctf),            // ctf
            address(beaconFactory),  // proxyFactory (beacon-based)
            address(safeFactory)      // safeFactory (mock for local development)
        );
        console.log("CTF Exchange deployed at:", address(exchange));

        // 8. Configure exchange with admin roles
        exchange.addAdmin(adminAddress);
        exchange.addOperator(adminAddress);

        vm.stopBroadcast();

        // 9. Run comprehensive tests
        _testDeploymentVerification(adminAddress);
        _testCTFFunctionality();
        _testBeaconProxySystem();
        _testExchangeIntegration();
        
        console.log("\n=== All Tests Passed! ===");
    }

    function _testDeploymentVerification(address adminAddress) internal view {
        console.log("\n--- Testing Deployment Verification ---");
        
        // Verify exchange configuration
        require(exchange.getCollateral() == address(usdc), "Collateral not set correctly");
        require(exchange.getCtf() == address(ctf), "CTF not set correctly");
        console.log("Exchange configuration verified");
        
        // Verify admin roles
        require(exchange.isAdmin(adminAddress), "Admin role not set");
        require(exchange.isOperator(adminAddress), "Operator role not set");
        console.log("Admin roles verified");
        
        // Verify beacon proxy system
        require(beacon.implementation() == address(mockImpl), "Beacon implementation not set correctly");
        require(beaconFactory.getBeacon() == address(beacon), "Factory beacon not set correctly");
        console.log("Beacon proxy system verified");
        
        console.log("Deployment verification passed!");
    }

    function _testCTFFunctionality() internal {
        console.log("\n--- Testing CTF Functionality ---");
        
        // Test basic CTF functions
        bytes32 questionId = keccak256("test-question");
        address oracle = vm.addr(1);
        
        // Prepare condition
        ctf.prepareCondition(oracle, questionId, 2);
        console.log("Condition prepared successfully");
        
        // Get condition ID
        bytes32 conditionId = ctf.getConditionId(oracle, questionId, 2);
        console.log("Condition ID generated:", vm.toString(conditionId));
        
        // Get outcome slot count
        uint256 outcomeSlotCount = ctf.getOutcomeSlotCount(conditionId);
        require(outcomeSlotCount == 2, "Outcome slot count should be 2");
        console.log("Outcome slot count verified:", outcomeSlotCount);
        
        console.log("CTF functionality test passed!");
    }

    function _testBeaconProxySystem() internal {
        console.log("\n--- Testing Beacon Proxy System ---");
        
        // Test beacon functionality
        address currentImpl = beacon.implementation();
        console.log("Current beacon implementation:", currentImpl);
        require(currentImpl == address(mockImpl), "Beacon implementation mismatch");
        
        // Test factory functionality
        address factoryBeacon = beaconFactory.getBeacon();
        console.log("Factory beacon address:", factoryBeacon);
        require(factoryBeacon == address(beacon), "Factory beacon mismatch");
        
        // Test proxy creation prediction
        address testOwner = vm.addr(999);
        bytes32 testSalt = keccak256("test-salt");
        
        address predictedProxy = beaconFactory.predictProxyAddress(testOwner, testSalt);
        console.log("Predicted proxy address:", predictedProxy);
        
        // Test that proxy doesn't exist yet
        bool proxyExists = beaconFactory.proxyExists(testOwner, testSalt);
        require(!proxyExists, "Proxy should not exist yet");
        console.log("Proxy existence check passed");
        
        // Test mock implementation functionality
        mockImpl.setValue(42);
        require(mockImpl.getValue() == 42, "Mock implementation value not set");
        console.log("Mock implementation functionality verified");
        
        console.log("Beacon proxy system test passed!");
    }

    function _testExchangeIntegration() internal {
        console.log("\n--- Testing Exchange Integration ---");
        
        // Test exchange configuration
        address exchangeCollateral = exchange.getCollateral();
        address exchangeCTF = exchange.getCtf();
        
        require(exchangeCollateral == address(usdc), "Exchange collateral mismatch");
        require(exchangeCTF == address(ctf), "Exchange CTF mismatch");
        console.log("Exchange configuration verified");
        
        // Test exchange factory configuration
        // Note: We can't directly access the factory addresses from CTFExchange
        // but we can verify the exchange was deployed successfully
        console.log("Exchange deployment verified");
        
        console.log("Exchange integration test passed!");
    }
} 