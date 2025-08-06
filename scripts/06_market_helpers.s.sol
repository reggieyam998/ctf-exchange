// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IConditionalTokens } from "src/exchange/interfaces/IConditionalTokens.sol";
import { CTFExchange } from "src/exchange/CTFExchange.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @title Market Helper Script
/// @notice Helper functions for market creation and management
contract MarketHelpers is Script {
    IConditionalTokens public ctf;
    CTFExchange public exchange;
    IERC20 public usdc;

    function run() public {
        console.log("=== Market Helper Script ===");
        _loadEnvironment();
    }

    function _loadEnvironment() internal {
        address ctfAddress = vm.envAddress("CTF_ADDRESS");
        address exchangeAddress = vm.envAddress("EXCHANGE_ADDRESS");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        
        ctf = IConditionalTokens(ctfAddress);
        exchange = CTFExchange(exchangeAddress);
        usdc = IERC20(usdcAddress);
        
        console.log("Environment loaded successfully");
    }

    // Create a custom binary market
    function createBinaryMarket(
        string memory question,
        address oracle
    ) external returns (bytes32 conditionId, uint256 yesPositionId, uint256 noPositionId) {
        console.log("\n--- Creating Binary Market ---");
        console.log("Question:", question);
        console.log("Oracle:", oracle);
        
        bytes32 questionId = keccak256(abi.encodePacked(question));
        uint256 outcomeSlotCount = 2;
        
        // Prepare condition
        ctf.prepareCondition(oracle, questionId, outcomeSlotCount);
        conditionId = ctf.getConditionId(oracle, questionId, outcomeSlotCount);
        
        // Generate position IDs
        bytes32 yesCollectionId = ctf.getCollectionId(bytes32(0), conditionId, 2);
        bytes32 noCollectionId = ctf.getCollectionId(bytes32(0), conditionId, 1);
        
        yesPositionId = ctf.getPositionId(usdc, yesCollectionId);
        noPositionId = ctf.getPositionId(usdc, noCollectionId);
        
        // Register tokens
        exchange.registerToken(yesPositionId, noPositionId, conditionId);
        
        console.log("Condition ID:", vm.toString(conditionId));
        console.log("YES Position ID:", yesPositionId);
        console.log("NO Position ID:", noPositionId);
        console.log("Market created successfully!");
        
        return (conditionId, yesPositionId, noPositionId);
    }

    // Create a multi-outcome market
    function createMultiOutcomeMarket(
        string memory question,
        address oracle,
        uint256 outcomeSlotCount
    ) external returns (bytes32 conditionId, uint256[] memory positionIds) {
        console.log("\n--- Creating Multi-Outcome Market ---");
        console.log("Question:", question);
        console.log("Oracle:", oracle);
        console.log("Outcome slots:", outcomeSlotCount);
        
        bytes32 questionId = keccak256(abi.encodePacked(question));
        
        // Prepare condition
        ctf.prepareCondition(oracle, questionId, outcomeSlotCount);
        conditionId = ctf.getConditionId(oracle, questionId, outcomeSlotCount);
        
        // Generate position IDs
        positionIds = new uint256[](outcomeSlotCount);
        for (uint256 i = 1; i <= outcomeSlotCount; i++) {
            bytes32 collectionId = ctf.getCollectionId(bytes32(0), conditionId, i);
            positionIds[i-1] = ctf.getPositionId(usdc, collectionId);
            console.log("Outcome", i, "Position ID:", positionIds[i-1]);
        }
        
        console.log("Condition ID:", vm.toString(conditionId));
        console.log("Market created successfully!");
        
        return (conditionId, positionIds);
    }

    // Get market information
    function getMarketInfo(bytes32 conditionId) external {
        console.log("\n--- Market Information ---");
        console.log("Condition ID:", vm.toString(conditionId));
        
        uint256 outcomeSlotCount = ctf.getOutcomeSlotCount(conditionId);
        console.log("Outcome slot count:", outcomeSlotCount);
        
        uint256 payoutDenominator = ctf.payoutDenominator(conditionId);
        
        if (payoutDenominator > 0) {
            console.log("Market is RESOLVED");
            for (uint256 i = 0; i < outcomeSlotCount; i++) {
                uint256 payoutNumerator = ctf.payoutNumerators(conditionId, i);
                uint256 payoutPercentage = (payoutNumerator * 100) / payoutDenominator;
                console.log("Outcome", i, "payout:", payoutPercentage);
            }
        } else {
            console.log("Market is UNRESOLVED");
            console.log("Waiting for oracle resolution...");
        }
    }

    // Simulate oracle resolution (for testing)
    function simulateOracleResolution(
        bytes32 questionId,
        uint256[] memory payouts
    ) external {
        console.log("\n--- Simulating Oracle Resolution ---");
        console.log("Question ID:", vm.toString(questionId));
        console.log("Payouts:");
        
        for (uint256 i = 0; i < payouts.length; i++) {
            console.log("Outcome", i, ":", payouts[i]);
        }
        
        console.log("Note: In production, only the designated oracle can call reportPayouts");
    }

    // Create sports betting market
    function createSportsMarket() external {
        console.log("\n--- Creating Sports Betting Market ---");
        
        string memory question = "Will the Lakers win the NBA Championship 2024?";
        address oracle = vm.envAddress("SPORTS_ORACLE_ADDRESS");
        
        (bytes32 conditionId, uint256 yesPositionId, uint256 noPositionId) = 
            this.createBinaryMarket(question, oracle);
        
        console.log("Sports market created!");
        console.log("Lakers YES Position ID:", yesPositionId);
        console.log("Lakers NO Position ID:", noPositionId);
    }

    // Create weather market
    function createWeatherMarket() external {
        console.log("\n--- Creating Weather Market ---");
        
        string memory question = "Will it rain in San Francisco on March 15, 2024?";
        address oracle = vm.envAddress("WEATHER_ORACLE_ADDRESS");
        
        (bytes32 conditionId, uint256 yesPositionId, uint256 noPositionId) = 
            this.createBinaryMarket(question, oracle);
        
        console.log("Weather market created!");
        console.log("Rain YES Position ID:", yesPositionId);
        console.log("Rain NO Position ID:", noPositionId);
    }

    // Create political market
    function createPoliticalMarket() external {
        console.log("\n--- Creating Political Market ---");
        
        string memory question = "Who will win the 2024 US Presidential Election?";
        address oracle = vm.envAddress("POLITICAL_ORACLE_ADDRESS");
        uint256 outcomeSlotCount = 4; // Multiple candidates
        
        (bytes32 conditionId, uint256[] memory positionIds) = 
            this.createMultiOutcomeMarket(question, oracle, outcomeSlotCount);
        
        console.log("Political market created!");
        console.log("Candidate 1 Position ID:", positionIds[0]);
        console.log("Candidate 2 Position ID:", positionIds[1]);
        console.log("Candidate 3 Position ID:", positionIds[2]);
        console.log("Candidate 4 Position ID:", positionIds[3]);
    }

    // Create crypto market
    function createCryptoMarket() external {
        console.log("\n--- Creating Crypto Market ---");
        
        string memory question = "Will Ethereum reach $5,000 by June 30, 2024?";
        address oracle = vm.envAddress("CRYPTO_ORACLE_ADDRESS");
        
        (bytes32 conditionId, uint256 yesPositionId, uint256 noPositionId) = 
            this.createBinaryMarket(question, oracle);
        
        console.log("Crypto market created!");
        console.log("ETH $5K YES Position ID:", yesPositionId);
        console.log("ETH $5K NO Position ID:", noPositionId);
    }

    // Create entertainment market
    function createEntertainmentMarket() external {
        console.log("\n--- Creating Entertainment Market ---");
        
        string memory question = "Will Avatar 3 win Best Picture at the 2025 Oscars?";
        address oracle = vm.envAddress("ENTERTAINMENT_ORACLE_ADDRESS");
        
        (bytes32 conditionId, uint256 yesPositionId, uint256 noPositionId) = 
            this.createBinaryMarket(question, oracle);
        
        console.log("Entertainment market created!");
        console.log("Avatar 3 YES Position ID:", yesPositionId);
        console.log("Avatar 3 NO Position ID:", noPositionId);
    }
} 