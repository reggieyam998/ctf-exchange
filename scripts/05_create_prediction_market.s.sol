// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IConditionalTokens } from "src/exchange/interfaces/IConditionalTokens.sol";
import { CTFExchange } from "src/exchange/CTFExchange.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @title Prediction Market Creation Script
/// @notice Creates prediction markets with real-world examples
contract CreatePredictionMarket is Script {
    IConditionalTokens public ctf;
    CTFExchange public exchange;
    IERC20 public usdc;

    function run() public {
        console.log("=== Prediction Market Creation Script ===");
        
        _loadEnvironment();
        _createBitcoinMarket();
        _createUSElectionMarket();
        
        console.log("\n=== Market Creation Complete ===");
    }

    function _loadEnvironment() internal {
        console.log("\n--- Loading Environment ---");
        
        address ctfAddress = vm.envAddress("CTF_ADDRESS");
        address exchangeAddress = vm.envAddress("EXCHANGE_ADDRESS");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        
        ctf = IConditionalTokens(ctfAddress);
        exchange = CTFExchange(exchangeAddress);
        usdc = IERC20(usdcAddress);
        
        console.log("Environment loaded successfully");
    }

    function _createBitcoinMarket() internal {
        console.log("\n--- Creating Bitcoin Prediction Market ---");
        
        string memory question = "Will Bitcoin reach $100,000 by December 31, 2024?";
        bytes32 questionId = keccak256(abi.encodePacked(question));
        address oracle = vm.envAddress("BITCOIN_ORACLE_ADDRESS");
        uint256 outcomeSlotCount = 2;
        
        console.log("Question:", question);
        console.log("Oracle:", oracle);
        
        // Prepare condition
        ctf.prepareCondition(oracle, questionId, outcomeSlotCount);
        bytes32 conditionId = ctf.getConditionId(oracle, questionId, outcomeSlotCount);
        console.log("Condition ID:", vm.toString(conditionId));
        
        // Generate position IDs
        bytes32 yesCollectionId = ctf.getCollectionId(bytes32(0), conditionId, 2);
        bytes32 noCollectionId = ctf.getCollectionId(bytes32(0), conditionId, 1);
        
        uint256 yesPositionId = ctf.getPositionId(usdc, yesCollectionId);
        uint256 noPositionId = ctf.getPositionId(usdc, noCollectionId);
        
        console.log("YES Position ID:", yesPositionId);
        console.log("NO Position ID:", noPositionId);
        
        // Register tokens
        exchange.registerToken(yesPositionId, noPositionId, conditionId);
        console.log("Bitcoin market created successfully!");
    }

    function _createUSElectionMarket() internal {
        console.log("\n--- Creating US Election Prediction Market ---");
        
        string memory question = "Who will win the 2024 US Presidential Election?";
        bytes32 questionId = keccak256(abi.encodePacked(question));
        address oracle = vm.envAddress("ELECTION_ORACLE_ADDRESS");
        uint256 outcomeSlotCount = 3;
        
        console.log("Question:", question);
        console.log("Oracle:", oracle);
        
        // Prepare condition
        ctf.prepareCondition(oracle, questionId, outcomeSlotCount);
        bytes32 conditionId = ctf.getConditionId(oracle, questionId, outcomeSlotCount);
        console.log("Condition ID:", vm.toString(conditionId));
        
        // Generate position IDs for multi-outcome
        for (uint256 i = 1; i <= outcomeSlotCount; i++) {
            bytes32 collectionId = ctf.getCollectionId(bytes32(0), conditionId, i);
            uint256 positionId = ctf.getPositionId(usdc, collectionId);
            console.log("Outcome", i, "Position ID:", positionId);
        }
        
        console.log("US Election market created successfully!");
    }
} 