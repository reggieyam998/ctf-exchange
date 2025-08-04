// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { CTFExchange } from "src/exchange/CTFExchange.sol";
import { USDC } from "src/dev/mocks/USDC.sol";
import { Deployer } from "src/dev/util/Deployer.sol";
import { IConditionalTokens } from "src/exchange/interfaces/IConditionalTokens.sol";

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

        // 3. Deploy CTF Exchange (with placeholder factories for now)
        // Note: We'll deploy the actual factories in Task 2.2 and 2.3
        exchange = new CTFExchange(
            address(usdc),    // collateral
            address(ctf),     // ctf
            address(0),       // proxyFactory (placeholder)
            address(0)        // safeFactory (placeholder)
        );
        console.log("CTF Exchange deployed at:", address(exchange));

        // 4. Configure exchange with admin roles
        exchange.addAdmin(adminAddress);
        exchange.addOperator(adminAddress);

        // 5. Verify admin roles are set correctly
        require(exchange.isAdmin(adminAddress), "Admin role not set");
        require(exchange.isOperator(adminAddress), "Operator role not set");

        // 6. Revoke deployer's authorization
        exchange.renounceAdminRole();
        exchange.renounceOperatorRole();

        vm.stopBroadcast();

        // 7. Verify deployment
        _verifyDeployment(adminAddress);
    }

    function _verifyDeployment(address adminAddress) internal view {
        console.log("\n=== Deployment Verification ===");
        console.log("Admin address:", adminAddress);
        console.log("USDC address:", address(usdc));
        console.log("CTF address:", address(ctf));
        console.log("Exchange address:", address(exchange));
        
        // Verify exchange configuration
        require(exchange.getCollateral() == address(usdc), "Collateral not set correctly");
        require(exchange.getCtf() == address(ctf), "CTF not set correctly");
        
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
} 