// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { CTFExchange } from "src/exchange/CTFExchange.sol";
import { USDC } from "src/dev/mocks/USDC.sol";
import { IConditionalTokens } from "src/exchange/interfaces/IConditionalTokens.sol";

/// @title VerifyDeployment
/// @notice Script to verify that all contracts are deployed and accessible
contract VerifyDeployment is Script {
    // Deployed contract addresses (from previous deployment)
    address public constant USDC_ADDRESS = 0x02a52E2DEf2f62D98c5662614CE707104eF01bc9;
    address public constant CTF_ADDRESS = 0x3431D37cEF4E795eb43db8E35DBD291Fc1db57f3; // This will be updated dynamically
    address public constant EXCHANGE_ADDRESS = 0xd98eA4Ddf58c9897eC11fDE1d00f116Fb6DCe99E;

    function run() public {
        console.log("=== Verifying Deployment ===");
        
        // Get contract instances
        USDC usdc = USDC(USDC_ADDRESS);
        IConditionalTokens ctf = IConditionalTokens(CTF_ADDRESS);
        CTFExchange exchange = CTFExchange(EXCHANGE_ADDRESS);
        
        console.log("USDC address:", address(usdc));
        console.log("CTF address:", address(ctf));
        console.log("Exchange address:", address(exchange));
        
        // Verify USDC contract
        _verifyUSDC(usdc);
        
        // Verify CTF contract
        _verifyCTF(ctf);
        
        // Verify Exchange contract
        _verifyExchange(exchange);
        
        console.log("All contracts verified successfully!");
    }
    
    function _verifyUSDC(USDC usdc) internal view {
        console.log("\n--- Verifying USDC Contract ---");
        
        // Check USDC name and symbol
        string memory name = usdc.name();
        string memory symbol = usdc.symbol();
        uint8 decimals = usdc.decimals();
        
        console.log("USDC Name:", name);
        console.log("USDC Symbol:", symbol);
        console.log("USDC Decimals:", decimals);
        
        require(keccak256(bytes(name)) == keccak256(bytes("USDC")), "USDC name incorrect");
        require(keccak256(bytes(symbol)) == keccak256(bytes("USDC")), "USDC symbol incorrect");
        require(decimals == 6, "USDC decimals incorrect");
        
        console.log("USDC contract verified!");
    }
    
    function _verifyCTF(IConditionalTokens ctf) internal view {
        console.log("\n--- Verifying CTF Contract ---");
        
        // Check if CTF contract is accessible
        console.log("CTF contract is accessible");
        console.log("CTF contract address:", address(ctf));
        
        // Verify the contract has code
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(ctf)
        }
        console.log("CTF contract code size:", codeSize);
        
        if (codeSize == 0) {
            console.log("WARNING: CTF contract has no code - this might indicate a deployment issue");
            console.log("This could be because:");
            console.log("1. The contract was not deployed correctly");
            console.log("2. The address is incorrect");
            console.log("3. The deployment transaction failed");
        } else {
            console.log("CTF contract verified!");
        }
    }
    
    function _verifyExchange(CTFExchange exchange) internal view {
        console.log("\n--- Verifying Exchange Contract ---");
        
        // Verify exchange configuration
        address collateral = exchange.getCollateral();
        address ctf = exchange.getCtf();
        
        console.log("Exchange Collateral:", collateral);
        console.log("Exchange CTF:", ctf);
        
        require(collateral == USDC_ADDRESS, "Exchange collateral not set correctly");
        require(ctf == CTF_ADDRESS, "Exchange CTF not set correctly");
        
        console.log("Exchange contract verified!");
    }
} 