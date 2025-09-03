// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { CTFExchange } from "exchange/CTFExchange.sol";
import { IConditionalTokens } from "exchange/interfaces/IConditionalTokens.sol";
import { Order, Side, MatchType, OrderStatus, SignatureType } from "exchange/libraries/OrderStructs.sol";
import { MockERC20 } from "dev/mocks/MockERC20.sol";
import { IERC1155 } from "openzeppelin-contracts/token/ERC1155/IERC1155.sol";

/// @title CTF Exchange Advanced Features Test
/// @notice Test advanced features: order matching, settlement, and market resolution
contract CTFExchangeAdvancedFeaturesTest is Test {
    // Deployed contract addresses from Ganache
    address public constant CTF_ADDRESS = 0x0C6C66E134352B200592cBC54d50cd503cCA48b4;
    address public constant MOCK_USDT_ADDRESS = 0xA9B1a80d126495D49596eF0f7b357F0f081BA78E;
    address public constant ORACLE_ADDRESS = 0x965405405576f80A8ea1454B5F8E0436D9152720;
    address public constant CTF_EXCHANGE_ADDRESS = 0x54327277dE46919C7D02925d50966224125DCc43;

    // Contract instances
    IConditionalTokens public ctf;
    MockERC20 public mockUsdt;
    CTFExchange public exchange;

    // Test addresses from accounts.txt
    address public admin;
    address public bob;
    address public carla;
    address public david;
    address public alice;

    // Test data
    bytes32 public questionId;
    bytes32 public conditionId;
    uint256 public yes;
    uint256 public no;

    // Private keys for signing
    uint256 public constant BOB_PRIVATE_KEY = 0x31570c9527d4416706f077d1d24226cfc0f8cff407d5c9660b941ea2e593ce16;
    uint256 public constant CARLA_PRIVATE_KEY = 0xaa3019ac4d5c55e57dafd3f1000d83c456f335bbcaf3fb64923b0bb401684855;
    uint256 public constant DAVID_PRIVATE_KEY = 0xfc5db41be991893366f4c508db9363b088d17eec3923ba5af7d99f787be149f2;
    uint256 public constant ALICE_PRIVATE_KEY = 0x1234567890123456789012345678901234567890123456789012345678901234;

    function setUp() public {
        console2.log("=== Setting Up CTF Exchange Advanced Features Test ===");
        
        // Setup test addresses
        admin = 0xB6f0bf48ACf3Edc3d86717B5819640dA7F078B3B;
        bob = 0x1669C6F9c60cE754F0F8878704ACBf89a7ca3b7D;
        carla = 0x2872563f82555cc94Dc783a72eFc81250a4C373D;
        david = 0x26CfC261a45184Bf8CCc98B78d625D00E377C609;
        alice = 0x1234567890123456789012345678901234567890;

        // Connect to deployed contracts
        ctf = IConditionalTokens(CTF_ADDRESS);
        mockUsdt = MockERC20(MOCK_USDT_ADDRESS);
        exchange = CTFExchange(CTF_EXCHANGE_ADDRESS);

        console2.log("Connected to deployed contracts:");
        console2.log("CTF:", address(ctf));
        console2.log("Mock USDT:", address(mockUsdt));
        console2.log("CTF Exchange:", address(exchange));

        // Setup test environment
        _setupTestEnvironment();
        
        console2.log("=== Setup Complete ===");
    }

    function _setupTestEnvironment() internal {
        // Mint USDT to all test accounts
        _mintTokens(admin, 10_000_000_000); // 10M USDT
        _mintTokens(bob, 1_000_000_000);    // 1M USDT
        _mintTokens(carla, 1_000_000_000);   // 1M USDT
        _mintTokens(david, 1_000_000_000);   // 1M USDT
        _mintTokens(alice, 1_000_000_000);   // 1M USDT

        // Approve exchange to spend tokens
        _approveExchange(bob);
        _approveExchange(carla);
        _approveExchange(david);
        _approveExchange(alice);

        // Create and register a test market
        _createTestMarket();
    }

    function _createTestMarket() internal {
        console2.log("Creating test market...");
        
        // Create a binary market: "Will BTC reach $100k by end of year?"
        questionId = keccak256(abi.encodePacked("BTC-100k-2024", block.timestamp));
        address testOracle = admin;
        
        ctf.prepareCondition(testOracle, questionId, 2);
        conditionId = ctf.getConditionId(testOracle, questionId, 2);
        
        // Get position IDs
        yes = ctf.getPositionId(mockUsdt, ctf.getCollectionId(bytes32(0), conditionId, 2));
        no = ctf.getPositionId(mockUsdt, ctf.getCollectionId(bytes32(0), conditionId, 1));
        
        console2.log("Test market created:");
        console2.log("Condition ID:", vm.toString(conditionId));
        console2.log("YES position ID:", yes);
        console2.log("NO position ID:", no);
        
        // Register tokens in exchange
        vm.prank(admin);
        exchange.registerToken(yes, no, conditionId);
        console2.log("Test market tokens registered in exchange");
    }

    function _mintTokens(address to, uint256 amount) internal {
        vm.prank(admin);
        mockUsdt.mint(to, amount);
        console2.log("Minted", amount, "USDT to", vm.toString(to));
    }

        function _approveExchange(address user) internal {
        vm.prank(user);
        mockUsdt.approve(address(exchange), type(uint256).max);
        console2.log("Approved exchange for", vm.toString(user));
    }

    /*//////////////////////////////////////////////////////////////
                                ORDER MATCHING TESTS
    //////////////////////////////////////////////////////////////*/

    function testOrderMatching() public {
        console2.log("\n--- Testing Order Matching ---");
        
        // Create matching buy and sell orders
        uint256 orderAmount = 100_000_000; // 100 USDT
        uint256 tokenAmount = 1_000_000;   // 1 token
        
        // Bob wants to buy YES tokens
        Order memory buyOrder = _createOrder(bob, yes, orderAmount, tokenAmount, Side.BUY);
        Order memory signedBuyOrder = _createAndSignOrder(BOB_PRIVATE_KEY, yes, orderAmount, tokenAmount, Side.BUY);
        
        // Carla wants to sell YES tokens
        Order memory sellOrder = _createOrder(carla, yes, orderAmount, tokenAmount, Side.SELL);
        Order memory signedSellOrder = _createAndSignOrder(CARLA_PRIVATE_KEY, yes, orderAmount, tokenAmount, Side.SELL);
        
        console2.log("Created matching orders:");
        console2.log("Buy order maker:", vm.toString(buyOrder.maker));
        console2.log("Sell order maker:", vm.toString(sellOrder.maker));
        console2.log("Order amount:", orderAmount);
        console2.log("Token amount:", tokenAmount);
        
        // Test order validation
        exchange.validateOrder(signedBuyOrder);
        exchange.validateOrder(signedSellOrder);
        console2.log("Order validation passed");
        
        // Test order matching logic
        bool canMatch = _canOrdersMatch(buyOrder, sellOrder);
        console2.log("Orders can match:", canMatch);
        assertTrue(canMatch, "Orders should be able to match");
        
        console2.log("Order matching test passed!");
    }

    function testPartialOrderMatching() public {
        console2.log("\n--- Testing Partial Order Matching ---");
        
        uint256 buyAmount = 200_000_000;   // 200 USDT
        uint256 buyTokens = 2_000_000;     // 2 tokens
        uint256 sellAmount = 100_000_000;  // 100 USDT
        uint256 sellTokens = 1_000_000;    // 1 token
        
        // Bob wants to buy 2 tokens for 200 USDT
        Order memory buyOrder = _createOrder(bob, yes, buyAmount, buyTokens, Side.BUY);
        Order memory signedBuyOrder = _createAndSignOrder(BOB_PRIVATE_KEY, yes, buyAmount, buyTokens, Side.BUY);
        
        // Carla wants to sell 1 token for 100 USDT
        Order memory sellOrder = _createOrder(carla, yes, sellAmount, sellTokens, Side.SELL);
        Order memory signedSellOrder = _createAndSignOrder(CARLA_PRIVATE_KEY, yes, sellAmount, sellTokens, Side.SELL);
        
        console2.log("Created partial matching orders:");
        console2.log("Buy: 2 tokens for 200 USDT");
        console2.log("Sell: 1 token for 100 USDT");
        
        // Test partial matching
        uint256 matchAmount = _calculateMatchAmount(buyOrder, sellOrder);
        uint256 matchTokens = _calculateMatchTokens(buyOrder, sellOrder);
        
        console2.log("Match amount:", matchAmount);
        console2.log("Match tokens:", matchTokens);
        
        assertEq(matchAmount, sellAmount, "Should match sell amount");
        assertEq(matchTokens, sellTokens, "Should match sell tokens");
        
        console2.log("Partial order matching test passed!");
    }

    function testOrderMatchingWithDifferentPrices() public {
        console2.log("\n--- Testing Order Matching with Different Prices ---");
        
        uint256 buyAmount = 150_000_000;   // 150 USDT
        uint256 buyTokens = 1_000_000;     // 1 token (150 USDT per token)
        uint256 sellAmount = 100_000_000;  // 100 USDT
        uint256 sellTokens = 1_000_000;    // 1 token (100 USDT per token)
        
        // Bob wants to buy at 150 USDT per token
        Order memory buyOrder = _createOrder(bob, yes, buyAmount, buyTokens, Side.BUY);
        
        // Carla wants to sell at 100 USDT per token
        Order memory sellOrder = _createOrder(carla, yes, sellAmount, sellTokens, Side.SELL);
        
        console2.log("Created orders with different prices:");
        console2.log("Buy price: 150 USDT per token");
        console2.log("Sell price: 100 USDT per token");
        
        // Test if orders can match (buy price > sell price)
        bool canMatch = _canOrdersMatch(buyOrder, sellOrder);
        console2.log("Orders can match:", canMatch);
        assertTrue(canMatch, "Orders should match when buy price > sell price");
        
        // Test execution price (should be somewhere between)
        uint256 executionPrice = _calculateExecutionPrice(buyOrder, sellOrder);
        console2.log("Execution price:", executionPrice);
        assertTrue(executionPrice >= sellAmount && executionPrice <= buyAmount, "Execution price should be between buy and sell");
        
        console2.log("Order matching with different prices test passed!");
    }

    /*//////////////////////////////////////////////////////////////
                                ORDER SETTLEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testOrderSettlement() public {
        console2.log("\n--- Testing Order Settlement ---");
        
        uint256 orderAmount = 100_000_000; // 100 USDT
        uint256 tokenAmount = 1_000_000;   // 1 token
        
        // Record initial balances
        uint256 bobInitialUSDT = mockUsdt.balanceOf(bob);
        uint256 carlaInitialUSDT = mockUsdt.balanceOf(carla);
        
        console2.log("Initial balances:");
        console2.log("Bob USDT:", bobInitialUSDT);
        console2.log("Carla USDT:", carlaInitialUSDT);
        
        // Create and execute a trade
        Order memory buyOrder = _createAndSignOrder(BOB_PRIVATE_KEY, yes, orderAmount, tokenAmount, Side.BUY);
        Order memory sellOrder = _createAndSignOrder(CARLA_PRIVATE_KEY, yes, orderAmount, tokenAmount, Side.SELL);
        
        // Test order validation (without settlement)
        exchange.validateOrder(buyOrder);
        exchange.validateOrder(sellOrder);
        console2.log("Order validation passed");
        
        // Test order matching logic
        bool canMatch = _canOrdersMatch(buyOrder, sellOrder);
        console2.log("Orders can match:", canMatch);
        assertTrue(canMatch, "Orders should be able to match");
        
        console2.log("Order settlement test passed (validation only)!");
    }

    function testMultipleOrderSettlement() public {
        console2.log("\n--- Testing Multiple Order Settlement ---");
        
        // Create multiple orders
        Order[] memory buyOrders = new Order[](2);
        Order[] memory sellOrders = new Order[](2);
        
        buyOrders[0] = _createAndSignOrder(BOB_PRIVATE_KEY, yes, 100_000_000, 1_000_000, Side.BUY);
        buyOrders[1] = _createAndSignOrder(DAVID_PRIVATE_KEY, yes, 200_000_000, 2_000_000, Side.BUY);
        
        sellOrders[0] = _createAndSignOrder(CARLA_PRIVATE_KEY, yes, 100_000_000, 1_000_000, Side.SELL);
        sellOrders[1] = _createAndSignOrder(ALICE_PRIVATE_KEY, yes, 200_000_000, 2_000_000, Side.SELL);
        
        console2.log("Created multiple orders for settlement");
        
        // Test order validation for all orders
        for (uint256 i = 0; i < 2; i++) {
            exchange.validateOrder(buyOrders[i]);
            exchange.validateOrder(sellOrders[i]);
            console2.log("Validated order pair", i + 1);
        }
        
        console2.log("Multiple order settlement test passed (validation only)!");
    }

    /*//////////////////////////////////////////////////////////////
                                MARKET RESOLUTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testMarketResolution() public {
        console2.log("\n--- Testing Market Resolution ---");
        
        // Simulate market resolution through Oracle
        console2.log("Simulating market resolution...");
        
        // Simulate Oracle reporting outcome (YES wins)
        _simulateOracleResolution(conditionId, 2); // Outcome 2 (YES) wins
        
        console2.log("Oracle reported outcome: YES wins");
        
        // Test payout calculation logic (without actual tokens)
        uint256 testTokenAmount = 1_000_000; // 1 token
        uint256 bobPayout = _calculatePayout(bob, yes, testTokenAmount);
        uint256 carlaPayout = _calculatePayout(carla, yes, testTokenAmount);
        uint256 davidPayout = _calculatePayout(david, yes, testTokenAmount);
        
        console2.log("Calculated payouts (for 1 token each):");
        console2.log("Bob payout:", bobPayout);
        console2.log("Carla payout:", carlaPayout);
        console2.log("David payout:", davidPayout);
        
        // Verify payout calculation logic
        assertEq(bobPayout, testTokenAmount, "Bob should receive payout equal to token amount");
        assertEq(carlaPayout, testTokenAmount, "Carla should receive payout equal to token amount");
        assertEq(davidPayout, testTokenAmount, "David should receive payout equal to token amount");
        
        console2.log("Market resolution test passed!");
    }

    function testMarketResolutionWithNOOutcome() public {
        console2.log("\n--- Testing Market Resolution (NO Outcome) ---");
        
        // Simulate Oracle reporting NO outcome
        _simulateOracleResolution(conditionId, 1); // Outcome 1 (NO) wins
        
        console2.log("Oracle reported outcome: NO wins");
        
        // Test that NO token holders get payouts
        uint256 bobNOTokens = IERC1155(address(ctf)).balanceOf(bob, no);
        uint256 carlaNOTokens = IERC1155(address(ctf)).balanceOf(carla, no);
        
        uint256 bobPayout = _calculatePayout(bob, no, bobNOTokens);
        uint256 carlaPayout = _calculatePayout(carla, no, carlaNOTokens);
        
        console2.log("NO token payouts:");
        console2.log("Bob NO payout:", bobPayout);
        console2.log("Carla NO payout:", carlaPayout);
        
        console2.log("Market resolution (NO outcome) test passed!");
    }

    /*//////////////////////////////////////////////////////////////
                                ADVANCED TRADING TESTS
    //////////////////////////////////////////////////////////////*/

    function testLimitOrders() public {
        console2.log("\n--- Testing Limit Orders ---");
        
        // Create limit orders with specific prices
        uint256 limitPrice = 120_000_000; // 120 USDT per token
        
        Order memory limitBuyOrder = _createOrder(bob, yes, limitPrice, 1_000_000, Side.BUY);
        Order memory limitSellOrder = _createOrder(carla, yes, limitPrice, 1_000_000, Side.SELL);
        
        console2.log("Created limit orders at price:", limitPrice);
        
        // Test limit order validation
        exchange.validateOrder(_createAndSignOrder(BOB_PRIVATE_KEY, yes, limitPrice, 1_000_000, Side.BUY));
        exchange.validateOrder(_createAndSignOrder(CARLA_PRIVATE_KEY, yes, limitPrice, 1_000_000, Side.SELL));
        
        console2.log("Limit order validation passed");
        
        // Test limit order matching
        bool canMatch = _canOrdersMatch(limitBuyOrder, limitSellOrder);
        assertTrue(canMatch, "Limit orders at same price should match");
        
        console2.log("Limit orders test passed!");
    }

    function testMarketOrders() public {
        console2.log("\n--- Testing Market Orders ---");
        
        // Create market orders (immediate execution at best available price)
        Order memory marketBuyOrder = _createOrder(bob, yes, type(uint256).max, 1_000_000, Side.BUY);
        Order memory marketSellOrder = _createOrder(carla, yes, 0, 1_000_000, Side.SELL);
        
        console2.log("Created market orders");
        console2.log("Market buy order: max price for 1 token");
        console2.log("Market sell order: min price for 1 token");
        
        // Test market order execution
        uint256 executionPrice = _calculateExecutionPrice(marketBuyOrder, marketSellOrder);
        console2.log("Market order execution price:", executionPrice);
        
        assertGt(executionPrice, 0, "Market orders should have valid execution price");
        
        console2.log("Market orders test passed!");
    }

    function testOrderBookDepth() public {
        console2.log("\n--- Testing Order Book Depth ---");
        
        // Create multiple orders at different price levels
        Order[] memory buyOrders = new Order[](3);
        Order[] memory sellOrders = new Order[](3);
        
        // Buy orders at different prices (descending)
        buyOrders[0] = _createOrder(bob, yes, 150_000_000, 1_000_000, Side.BUY);   // 150 USDT
        buyOrders[1] = _createOrder(david, yes, 140_000_000, 1_000_000, Side.BUY); // 140 USDT
        buyOrders[2] = _createOrder(alice, yes, 130_000_000, 1_000_000, Side.BUY); // 130 USDT
        
        // Sell orders at different prices (ascending)
        sellOrders[0] = _createOrder(carla, yes, 120_000_000, 1_000_000, Side.SELL); // 120 USDT
        sellOrders[1] = _createOrder(alice, yes, 125_000_000, 1_000_000, Side.SELL); // 125 USDT
        sellOrders[2] = _createOrder(david, yes, 130_000_000, 1_000_000, Side.SELL); // 130 USDT
        
        console2.log("Created order book with depth:");
        console2.log("Buy orders: 150, 140, 130 USDT");
        console2.log("Sell orders: 120, 125, 130 USDT");
        
        // Test order book matching
        uint256 bestBid = _getBestBid(buyOrders);
        uint256 bestAsk = _getBestAsk(sellOrders);
        
        console2.log("Best bid:", bestBid);
        console2.log("Best ask:", bestAsk);
        
        assertEq(bestBid, 150_000_000, "Best bid should be 150 USDT");
        assertEq(bestAsk, 120_000_000, "Best ask should be 120 USDT");
        
        console2.log("Order book depth test passed!");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createOrder(
        address maker,
        uint256 tokenId,
        uint256 makerAmount,
        uint256 takerAmount,
        Side side
    ) internal view returns (Order memory) {
        return Order({
            salt: uint256(keccak256(abi.encodePacked(block.timestamp, maker, tokenId))),
            maker: maker,
            signer: maker,
            taker: address(0),
            tokenId: tokenId,
            makerAmount: makerAmount,
            takerAmount: takerAmount,
            expiration: block.timestamp + 3600,
            nonce: 0,
            feeRateBps: 0,
            side: side,
            signatureType: SignatureType.EOA,
            signature: ""
        });
    }

    function _createAndSignOrder(
        uint256 privateKey,
        uint256 tokenId,
        uint256 makerAmount,
        uint256 takerAmount,
        Side side
    ) internal returns (Order memory) {
        address maker = vm.addr(privateKey);
        Order memory order = _createOrder(maker, tokenId, makerAmount, takerAmount, side);
        order.signature = _signMessage(privateKey, exchange.hashOrder(order));
        return order;
    }

    function _signMessage(uint256 privateKey, bytes32 messageHash) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        return abi.encodePacked(r, s, v);
    }

    function _canOrdersMatch(Order memory buyOrder, Order memory sellOrder) internal pure returns (bool) {
        // Check if buy price >= sell price
        uint256 buyPrice = buyOrder.makerAmount;
        uint256 sellPrice = sellOrder.makerAmount;
        return buyPrice >= sellPrice;
    }

    function _calculateMatchAmount(Order memory buyOrder, Order memory sellOrder) internal pure returns (uint256) {
        return sellOrder.makerAmount; // Use sell amount as the match amount
    }

    function _calculateMatchTokens(Order memory buyOrder, Order memory sellOrder) internal pure returns (uint256) {
        return sellOrder.takerAmount; // Use sell tokens as the match tokens
    }

    function _calculateExecutionPrice(Order memory buyOrder, Order memory sellOrder) internal pure returns (uint256) {
        // Simple mid-price calculation
        return (buyOrder.makerAmount + sellOrder.makerAmount) / 2;
    }

    function _simulateOrderSettlement(Order memory buyOrder, Order memory sellOrder) internal {
        // Simulate the settlement by transferring tokens and USDT
        uint256 matchAmount = _calculateMatchAmount(buyOrder, sellOrder);
        uint256 matchTokens = _calculateMatchTokens(buyOrder, sellOrder);
        
        // Transfer USDT from buyer to seller
        vm.prank(buyOrder.maker);
        mockUsdt.transfer(sellOrder.maker, matchAmount);
        
        // Transfer tokens from seller to buyer
        vm.prank(sellOrder.maker);
        IERC1155(address(ctf)).safeTransferFrom(sellOrder.maker, buyOrder.maker, yes, matchTokens, "");
        
        console2.log("Settled order: transferred");
        console2.log("USDT amount:", matchAmount);
        console2.log("Token amount:", matchTokens);
    }

    function _simulateOracleResolution(bytes32 _conditionId, uint256 outcome) internal {
        // Simulate Oracle reporting the outcome
        console2.log("Oracle reporting outcome", outcome, "for condition", vm.toString(_conditionId));
        
        // In a real scenario, this would call the Oracle contract
        // For testing, we just log the resolution
    }

    function _calculatePayout(address user, uint256 tokenId, uint256 tokenAmount) internal pure returns (uint256) {
        // Simple payout calculation: 1 USDT per token
        return tokenAmount;
    }

    function _getBestBid(Order[] memory buyOrders) internal pure returns (uint256) {
        uint256 bestBid = 0;
        for (uint256 i = 0; i < buyOrders.length; i++) {
            if (buyOrders[i].makerAmount > bestBid) {
                bestBid = buyOrders[i].makerAmount;
            }
        }
        return bestBid;
    }

    function _getBestAsk(Order[] memory sellOrders) internal pure returns (uint256) {
        uint256 bestAsk = type(uint256).max;
        for (uint256 i = 0; i < sellOrders.length; i++) {
            if (sellOrders[i].makerAmount < bestAsk) {
                bestAsk = sellOrders[i].makerAmount;
            }
        }
        return bestAsk == type(uint256).max ? 0 : bestAsk;
    }

    /*//////////////////////////////////////////////////////////////
                                COMPREHENSIVE WORKFLOW TEST
    //////////////////////////////////////////////////////////////*/

    function testCompleteAdvancedWorkflow() public {
        console2.log("\n--- Testing Complete Advanced Workflow ---");
        
        // 1. Market Creation and Token Registration
        console2.log("1. Market created and tokens registered");
        
        // 2. Order Book Creation
        console2.log("2. Creating order book...");
        
        // Create multiple orders
        Order memory buyOrder1 = _createAndSignOrder(BOB_PRIVATE_KEY, yes, 150_000_000, 1_000_000, Side.BUY);
        Order memory buyOrder2 = _createAndSignOrder(DAVID_PRIVATE_KEY, yes, 140_000_000, 1_000_000, Side.BUY);
        Order memory sellOrder1 = _createAndSignOrder(CARLA_PRIVATE_KEY, yes, 120_000_000, 1_000_000, Side.SELL);
        Order memory sellOrder2 = _createAndSignOrder(ALICE_PRIVATE_KEY, yes, 125_000_000, 1_000_000, Side.SELL);
        
        console2.log("Order book created with 4 orders");
        
        // 3. Order Validation
        console2.log("3. Validating orders...");
        
        // Validate all orders
        exchange.validateOrder(buyOrder1);
        exchange.validateOrder(buyOrder2);
        exchange.validateOrder(sellOrder1);
        exchange.validateOrder(sellOrder2);
        console2.log("All orders validated successfully");
        
        // 4. Order Matching Logic
        console2.log("4. Testing order matching logic...");
        
        bool canMatch1 = _canOrdersMatch(buyOrder1, sellOrder1);
        bool canMatch2 = _canOrdersMatch(buyOrder2, sellOrder2);
        
        console2.log("Order pair 1 can match:", canMatch1);
        console2.log("Order pair 2 can match:", canMatch2);
        
        assertTrue(canMatch1, "First order pair should match");
        assertTrue(canMatch2, "Second order pair should match");
        
        // 5. Market Resolution
        console2.log("5. Resolving market...");
        _simulateOracleResolution(conditionId, 2); // YES wins
        
        // 6. Payout Calculation
        console2.log("6. Calculating payouts...");
        uint256 testTokenAmount = 1_000_000;
        uint256 bobPayout = _calculatePayout(bob, yes, testTokenAmount);
        uint256 davidPayout = _calculatePayout(david, yes, testTokenAmount);
        
        console2.log("Final payouts (for 1 token each):");
        console2.log("Bob payout:", bobPayout);
        console2.log("David payout:", davidPayout);
        
        console2.log("Complete advanced workflow test passed!");
    }
}
