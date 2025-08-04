// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { CTFExchange } from "src/exchange/CTFExchange.sol";
import { USDC } from "src/dev/mocks/USDC.sol";
import { IConditionalTokens } from "src/exchange/interfaces/IConditionalTokens.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @title LocalTest
/// @notice Script to test CTF functionality with deployed contracts
contract LocalTest is Script {
    // Deployed contract addresses (from previous deployment)
    address public constant USDC_ADDRESS = 0x02a52E2DEf2f62D98c5662614CE707104eF01bc9;
    address public constant CTF_ADDRESS = 0x3431D37cEF4E795eb43db8E35DBD291Fc1db57f3;
    address public constant EXCHANGE_ADDRESS = 0xd98eA4Ddf58c9897eC11fDE1d00f116Fb6DCe99E;

    function run() public {
        console.log("=== Testing CTF Functionality with Deployed Contracts ===");
        
        // Get contract instances
        USDC usdc = USDC(USDC_ADDRESS);
        IConditionalTokens ctf = IConditionalTokens(CTF_ADDRESS);
        CTFExchange exchange = CTFExchange(EXCHANGE_ADDRESS);
        
        console.log("USDC address:", address(usdc));
        console.log("CTF address:", address(ctf));
        console.log("Exchange address:", address(exchange));
        
        // Test basic CTF functions
        _testCTFFunctionality(ctf);
        
        // Test exchange integration
        _testExchangeIntegration(exchange, usdc, ctf);
        
        console.log("All tests passed!");
    }
    
    function _testCTFFunctionality(IConditionalTokens ctf) internal {
        console.log("\n--- Testing CTF Functionality ---");
        
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
        console.log("Outcome slot count verified:", outcomeSlotCount);
        
        // Test position ID computation
        uint256 positionId = ctf.getPositionId(
            IERC20(USDC_ADDRESS), 
            ctf.getCollectionId(bytes32(0), conditionId, 1)
        );
        console.log("Position ID computed:", positionId);
        
        console.log("CTF functionality test passed!");
    }
    
    function _testExchangeIntegration(CTFExchange exchange, USDC usdc, IConditionalTokens ctf) internal {
        console.log("\n--- Testing Exchange Integration ---");
        
        // Verify exchange configuration
        require(exchange.getCollateral() == address(usdc), "Collateral not set correctly");
        require(exchange.getCtf() == address(ctf), "CTF not set correctly");
        console.log("Exchange configuration verified");
        
        // Test USDC functionality
        uint256 initialBalance = usdc.balanceOf(address(this));
        console.log("Initial USDC balance:", initialBalance);
        
        // Test USDC minting (if available)
        if (initialBalance == 0) {
            usdc.mint(address(this), 1000 * 10**6); // 1000 USDC
            console.log("USDC minted successfully");
        }
        
        console.log("Exchange integration test passed!");
    }
} 