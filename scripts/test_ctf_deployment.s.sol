// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Deployer } from "src/dev/util/Deployer.sol";
import { IConditionalTokens } from "src/exchange/interfaces/IConditionalTokens.sol";

/// @title TestCTFDeployment
/// @notice Script to test CTF deployment
contract TestCTFDeployment is Script {
    function run() public {
        console.log("=== Testing CTF Deployment ===");
        
        // Test CTF deployment
        address ctfAddress = Deployer.ConditionalTokens();
        console.log("CTF deployed at:", ctfAddress);
        
        // Check if contract has code
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(ctfAddress)
        }
        console.log("CTF contract code size:", codeSize);
        
        if (codeSize > 0) {
            console.log("CTF deployment successful!");
            
            // Try to create an instance
            IConditionalTokens ctf = IConditionalTokens(ctfAddress);
            console.log("CTF instance created successfully");
            
            // Test basic functionality
            _testCTFBasic(ctf);
        } else {
            console.log("CTF deployment failed - no code at address");
        }
    }
    
    function _testCTFBasic(IConditionalTokens ctf) internal {
        console.log("\n--- Testing Basic CTF Functions ---");
        
        // Test condition preparation
        bytes32 questionId = keccak256("test-question");
        address oracle = vm.addr(1);
        
        try ctf.prepareCondition(oracle, questionId, 2) {
            console.log("Condition prepared successfully");
            
            // Get condition ID
            bytes32 conditionId = ctf.getConditionId(oracle, questionId, 2);
            console.log("Condition ID:", vm.toString(conditionId));
            
            // Get outcome slot count
            uint256 outcomeSlotCount = ctf.getOutcomeSlotCount(conditionId);
            console.log("Outcome slot count:", outcomeSlotCount);
            
            console.log("CTF basic functionality test passed!");
        } catch Error(string memory reason) {
            console.log("CTF prepareCondition failed:", reason);
        } catch {
            console.log("CTF prepareCondition failed with unknown error");
        }
    }
} 