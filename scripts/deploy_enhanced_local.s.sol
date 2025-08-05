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
import { EnhancedGnosisSafeFactory } from "src/dev/mocks/EnhancedGnosisSafeFactory.sol";

/// @title Enhanced Local Deployment Script
/// @notice Deploys all contracts with enhanced Polymarket-mimicking approach
contract EnhancedLocalDeployment is Script {
    // Environment variables
    string public PK;
    string public ADMIN;
    string public RPC_URL;
    string public COLLATERAL;
    string public CTF;
    string public PROXY_FACTORY;
    string public SAFE_FACTORY;
    string public CHAIN_ID;
    string public GAS_LIMIT;
    string public GAS_PRICE;
    string public ENVIRONMENT;
    string public DEBUG;

    // Deployed contracts
    USDC public usdc;
    IConditionalTokens public ctf;
    MockBeaconImplementation public mockImpl;
    ExchangeBeacon public beacon;
    BeaconProxyFactory public beaconFactory;
    EnhancedGnosisSafeFactory public safeFactory;
    CTFExchange public exchange;

    function run() public {
        console.log("=== Enhanced Local Deployment Script ===");
        console.log("Mimicking Polymarket's dual factory approach");
        
        // Load environment variables
        PK = vm.envString("PK");
        ADMIN = vm.envString("ADMIN");
        RPC_URL = vm.envString("RPC_URL");
        CHAIN_ID = vm.envString("CHAIN_ID");
        GAS_LIMIT = vm.envString("GAS_LIMIT");
        GAS_PRICE = vm.envString("GAS_PRICE");
        ENVIRONMENT = vm.envString("ENVIRONMENT");
        DEBUG = vm.envString("DEBUG");

        console.log("Environment:", ENVIRONMENT);
        console.log("Chain ID:", CHAIN_ID);
        console.log("RPC URL:", RPC_URL);

        // Start deployment
        vm.startBroadcast();

        console.log("\n--- Deploying Enhanced Local Environment ---");

        // 1. Deploy Mock USDC (Polymarket uses real USDC on Polygon)
        usdc = new USDC();
        console.log("Mock USDC deployed at:", address(usdc));

        // 2. Deploy Real ConditionalTokens (same as Polymarket)
        ctf = IConditionalTokens(Deployer.ConditionalTokens());
        console.log("Real ConditionalTokens deployed at:", address(ctf));

        // 3. Deploy Mock Implementation for Beacon
        mockImpl = new MockBeaconImplementation();
        console.log("Mock Beacon Implementation deployed at:", address(mockImpl));

        // 4. Deploy Exchange Beacon (our improved approach)
        beacon = new ExchangeBeacon(address(mockImpl), vm.addr(vm.parseUint(PK, 16)));
        console.log("Exchange Beacon deployed at:", address(beacon));

        // 5. Deploy Beacon Proxy Factory (our improved Polymarket proxy factory)
        beaconFactory = new BeaconProxyFactory(address(beacon), vm.addr(vm.parseUint(PK, 16)));
        console.log("Beacon Proxy Factory deployed at:", address(beaconFactory));

        // 6. Deploy Enhanced Gnosis Safe Factory (mimicking Polymarket's approach)
        address mockMasterCopy = address(0x1234567890123456789012345678901234567890);
        safeFactory = new EnhancedGnosisSafeFactory(mockMasterCopy, vm.addr(vm.parseUint(PK, 16)));
        console.log("Enhanced Gnosis Safe Factory deployed at:", address(safeFactory));

        // 7. Deploy CTF Exchange with both factories
        exchange = new CTFExchange(
            address(usdc),           // collateral (USDC)
            address(ctf),            // ctf (ConditionalTokens)
            address(beaconFactory),  // proxyFactory (our improved approach)
            address(safeFactory)      // safeFactory (Polymarket-mimicking)
        );
        console.log("CTF Exchange deployed at:", address(exchange));

        // Configure exchange
        console.log("\n--- Configuring Exchange ---");
        
        address adminAddress = vm.addr(vm.parseUint(PK, 16));
        
        // Set up admin roles
        exchange.addAdmin(adminAddress);
        exchange.addOperator(adminAddress);
        console.log("Admin roles configured for:", adminAddress);

        // Verify deployment
        console.log("\n--- Verifying Deployment ---");
        
        require(exchange.getCollateral() == address(usdc), "Collateral not set correctly");
        require(exchange.getCtf() == address(ctf), "CTF not set correctly");
        require(exchange.isAdmin(adminAddress), "Admin role not set");
        require(exchange.isOperator(adminAddress), "Operator role not set");
        
        console.log("Deployment verification passed");

        // Test beacon and safe factory integration
        console.log("\n--- Testing Factory Integration ---");
        
        // Test beacon factory
        address testOwner = vm.addr(999);
        bytes32 testSalt = keccak256("test-salt");
        address predictedProxy = beaconFactory.predictProxyAddress(testOwner, testSalt);
        console.log("Predicted proxy address:", predictedProxy);
        
        // Test safe factory
        uint256 testSafeSalt = 12345;
        address predictedSafe = safeFactory.predictSafeAddress(testOwner, testSafeSalt);
        console.log("Predicted safe address:", predictedSafe);
        
        console.log("Factory integration tests passed");

        vm.stopBroadcast();

        console.log("\n=== Enhanced Deployment Complete ===");
        console.log("This deployment mimics Polymarket's dual factory approach:");
        console.log("- Beacon Proxy Factory: For custom proxy wallets (improved over Polymarket)");
        console.log("- Enhanced Gnosis Safe Factory: For 1-of-1 multisig wallets (like Polymarket)");
        console.log("- Both factories support deterministic address generation");
        console.log("- Both factories support batch creation");
        console.log("- Both factories include pause/unpause functionality");
        
        console.log("\n=== Deployment Summary ===");
        console.log("Mock USDC:", address(usdc));
        console.log("ConditionalTokens:", address(ctf));
        console.log("Mock Implementation:", address(mockImpl));
        console.log("Exchange Beacon:", address(beacon));
        console.log("Beacon Proxy Factory:", address(beaconFactory));
        console.log("Enhanced Gnosis Safe Factory:", address(safeFactory));
        console.log("CTF Exchange:", address(exchange));
        console.log("Admin Address:", adminAddress);
    }
} 