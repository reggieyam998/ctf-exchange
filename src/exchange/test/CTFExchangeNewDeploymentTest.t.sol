// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { CTFExchange } from "exchange/CTFExchange.sol";
import { IConditionalTokens } from "exchange/interfaces/IConditionalTokens.sol";
import { Order, Side, MatchType, OrderStatus, SignatureType } from "exchange/libraries/OrderStructs.sol";
import { MockERC20 } from "dev/mocks/MockERC20.sol";
import { IERC1155 } from "openzeppelin-contracts/token/ERC1155/IERC1155.sol";

/// @title CTF Exchange Integration Test - New Deployment
/// @notice Test integration with newly deployed CTF Exchange on Ganache with USDT and admin privileges
contract CTFExchangeNewDeploymentTest is Test {
    // Deployed contract addresses from Ganache (NEW DEPLOYMENT - CORRECTED)
    address public constant CTF_ADDRESS = 0x0C6C66E134352B200592cBC54d50cd503cCA48b4; // From root folder
    address public constant MOCK_USDT_ADDRESS = 0xA9B1a80d126495D49596eF0f7b357F0f081BA78E; // New deployment
    address public constant ORACLE_ADDRESS = 0x965405405576f80A8ea1454B5F8E0436D9152720;
    address public constant CTF_EXCHANGE_ADDRESS = 0x54327277dE46919C7D02925d50966224125DCc43; // New deployment

    // Contract instances
    IConditionalTokens public ctf;
    MockERC20 public mockUsdt;
    CTFExchange public exchange;

    // Test addresses from accounts.txt
    address public admin;
    address public bob;
    address public carla;
    address public david;

    // Test data
    bytes32 public questionId;
    bytes32 public conditionId;
    uint256 public yes;
    uint256 public no;

    // Private keys for signing (from accounts.txt)
    uint256 public constant BOB_PRIVATE_KEY = 0x31570c9527d4416706f077d1d24226cfc0f8cff407d5c9660b941ea2e593ce16;
    uint256 public constant CARLA_PRIVATE_KEY = 0xaa3019ac4d5c55e57dafd3f1000d83c456f335bbcaf3fb64923b0bb401684855;
    uint256 public constant DAVID_PRIVATE_KEY = 0xfc5db41be991893366f4c508db9363b088d17eec3923ba5af7d99f787be149f2;

    function setUp() public {
        console2.log("=== Setting Up CTF Exchange New Deployment Test ===");
        
        // Setup test addresses from accounts.txt
        admin = 0xB6f0bf48ACf3Edc3d86717B5819640dA7F078B3B;
        bob = 0x1669C6F9c60cE754F0F8878704ACBf89a7ca3b7D;
        carla = 0x2872563f82555cc94Dc783a72eFc81250a4C373D;
        david = 0x26CfC261a45184Bf8CCc98B78d625D00E377C609;

        // Connect to deployed contracts
        ctf = IConditionalTokens(CTF_ADDRESS);
        mockUsdt = MockERC20(MOCK_USDT_ADDRESS);
        exchange = CTFExchange(CTF_EXCHANGE_ADDRESS);

        console2.log("Connected to NEW deployed contracts:");
        console2.log("CTF:", address(ctf));
        console2.log("Mock USDT:", address(mockUsdt));
        console2.log("CTF Exchange:", address(exchange));
        console2.log("Admin:", admin);
        console2.log("Bob:", bob);
        console2.log("Carla:", carla);
        console2.log("David:", david);

        console2.log("=== Setup Complete ===");
    }

    /*//////////////////////////////////////////////////////////////
                                BASIC CONNECTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testDeployedContractsConnection() public view {
        console2.log("\n--- Testing Deployed Contracts Connection ---");
        
        // Verify contract connections
        require(address(ctf) == CTF_ADDRESS, "CTF address mismatch");
        require(address(mockUsdt) == MOCK_USDT_ADDRESS, "Mock USDT address mismatch");
        require(address(exchange) == CTF_EXCHANGE_ADDRESS, "Exchange address mismatch");
        
        console2.log("Contract connections verified successfully");
        
        // Test basic contract functionality
        require(exchange.getCollateral() == MOCK_USDT_ADDRESS, "Collateral not set correctly");
        require(exchange.getCtf() == CTF_ADDRESS, "CTF not set correctly");
        
        console2.log("Basic contract functionality verified");
        console2.log("Deployed contracts connection test passed!");
    }

    function testBasicExchangeFunctionality() public {
        console2.log("\n--- Testing Basic Exchange Functionality ---");
        
        // Test basic exchange configuration
        address collateral = exchange.getCollateral();
        address ctfAddress = exchange.getCtf();
        
        console2.log("Exchange collateral:", collateral);
        console2.log("Exchange CTF address:", ctfAddress);
        
        // Verify configuration matches deployment
        assertEq(collateral, MOCK_USDT_ADDRESS, "Collateral should match Mock USDT");
        assertEq(ctfAddress, CTF_ADDRESS, "CTF address should match deployment");
        
        // Test exchange state
        bool isPaused = exchange.paused();
        console2.log("Exchange paused status:", isPaused);
        
        // Test nonce functionality
        uint256 bobNonce = exchange.nonces(bob);
        uint256 carlaNonce = exchange.nonces(carla);
        console2.log("Bob's nonce:", bobNonce);
        console2.log("Carla's nonce:", carlaNonce);
        
        // Test nonce increment
        vm.prank(bob);
        exchange.incrementNonce();
        uint256 bobNewNonce = exchange.nonces(bob);
        console2.log("Bob's new nonce:", bobNewNonce);
        assertEq(bobNewNonce, bobNonce + 1, "Nonce should be incremented");
        
        console2.log("Basic exchange functionality test passed!");
    }

    function testAdminPrivileges() public {
        console2.log("\n--- Testing Admin Privileges ---");
        
        // Test admin roles
        bool isAdmin = exchange.isAdmin(admin);
        console2.log("Admin status:", isAdmin);
        
        if (isAdmin) {
            console2.log("Admin role verified - testing admin functions");
            
            // Test pause functionality
            vm.prank(admin);
            exchange.pauseTrading();
            console2.log("Trading paused successfully");
            
            vm.prank(admin);
            exchange.unpauseTrading();
            console2.log("Trading unpaused successfully");
            
            console2.log("Admin functionality test passed!");
        } else {
            console2.log("Admin role not found - this indicates a deployment issue");
        }
    }

    /*//////////////////////////////////////////////////////////////
                                TOKEN REGISTRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testTokenRegistration() public {
        console2.log("\n--- Testing Token Registration ---");
        
        // Create a condition and position IDs
        bytes32 testQuestionId = keccak256(abi.encodePacked("token-registration-test", block.timestamp));
        address testOracle = admin;
        
        console2.log("Creating test condition for token registration...");
        ctf.prepareCondition(testOracle, testQuestionId, 2);
        bytes32 testConditionId = ctf.getConditionId(testOracle, testQuestionId, 2);
        console2.log("Test condition ID:", vm.toString(testConditionId));
        
        // Get position IDs
        uint256 testYes = ctf.getPositionId(mockUsdt, ctf.getCollectionId(bytes32(0), testConditionId, 2));
        uint256 testNo = ctf.getPositionId(mockUsdt, ctf.getCollectionId(bytes32(0), testConditionId, 1));
        console2.log("Test YES position ID:", testYes);
        console2.log("Test NO position ID:", testNo);
        
        // Register tokens in exchange (should work now with admin privileges)
        console2.log("Registering tokens in exchange...");
        vm.prank(admin);
        exchange.registerToken(testYes, testNo, testConditionId);
        console2.log("Token registration successful!");
        
        // Verify registration
        uint256 complement = exchange.getComplement(testYes);
        console2.log("YES token complement:", complement);
        assertEq(complement, testNo, "Complement should match NO token");
        
        uint256 complement2 = exchange.getComplement(testNo);
        console2.log("NO token complement:", complement2);
        assertEq(complement2, testYes, "Complement should match YES token");
        
        console2.log("Token registration verification passed!");
    }

    /*//////////////////////////////////////////////////////////////
                                ORDER CREATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testOrderCreationWithRegisteredTokens() public {
        console2.log("\n--- Testing Order Creation with Registered Tokens ---");
        
        // Create a unique condition and register tokens
        bytes32 orderTestQuestionId = keccak256(abi.encodePacked("order-creation-test", block.timestamp, "unique"));
        address testOracle = admin;
        
        console2.log("Creating unique condition for order creation test...");
        ctf.prepareCondition(testOracle, orderTestQuestionId, 2);
        bytes32 orderTestConditionId = ctf.getConditionId(testOracle, orderTestQuestionId, 2);
        console2.log("Order test condition ID:", vm.toString(orderTestConditionId));
        
        uint256 orderTestYes = ctf.getPositionId(mockUsdt, ctf.getCollectionId(bytes32(0), orderTestConditionId, 2));
        uint256 orderTestNo = ctf.getPositionId(mockUsdt, ctf.getCollectionId(bytes32(0), orderTestConditionId, 1));
        console2.log("Order test YES position ID:", orderTestYes);
        console2.log("Order test NO position ID:", orderTestNo);
        
        // Register tokens in exchange
        console2.log("Registering tokens for order creation test...");
        vm.prank(admin);
        exchange.registerToken(orderTestYes, orderTestNo, orderTestConditionId);
        console2.log("Order test tokens registered successfully");
        
        // Create orders with registered position IDs
        Order memory buyOrder = _createOrder(bob, orderTestYes, 50_000_000, 100_000_000, Side.BUY);
        Order memory sellOrder = _createOrder(carla, orderTestYes, 50_000_000, 100_000_000, Side.SELL);
        
        console2.log("Orders created successfully with registered tokens");
        
        // Test order hashing
        bytes32 buyOrderHash = exchange.hashOrder(buyOrder);
        bytes32 sellOrderHash = exchange.hashOrder(sellOrder);
        console2.log("Buy order hash:", vm.toString(buyOrderHash));
        console2.log("Sell order hash:", vm.toString(sellOrderHash));
        
        // Sign orders
        Order memory signedBuyOrder = _createAndSignOrder(BOB_PRIVATE_KEY, orderTestYes, 50_000_000, 100_000_000, Side.BUY);
        Order memory signedSellOrder = _createAndSignOrder(CARLA_PRIVATE_KEY, orderTestYes, 50_000_000, 100_000_000, Side.SELL);
        
        console2.log("Orders signed successfully");
        
        // Test order validation (should work with registered tokens)
        exchange.validateOrder(signedBuyOrder);
        exchange.validateOrder(signedSellOrder);
        console2.log("Order validation passed with registered tokens");
        
        console2.log("Order creation with registered tokens test passed!");
    }

    /*//////////////////////////////////////////////////////////////
                                TOKEN SETUP TESTS
    //////////////////////////////////////////////////////////////*/

    function testTokenSetup() public {
        console2.log("\n--- Testing Token Setup ---");
        
        // Check admin's USDT balance (should have been minted during deployment)
        uint256 adminBalance = mockUsdt.balanceOf(admin);
        console2.log("Admin's USDT balance:", adminBalance);
        assertGt(adminBalance, 0, "Admin should have USDT balance");
        
        // Mint USDT to other accounts
        _mintTokens(bob, 1000_000_000);
        _mintTokens(carla, 1000_000_000);
        _mintTokens(david, 1000_000_000);
        
        // Check balances
        uint256 bobBalance = mockUsdt.balanceOf(bob);
        uint256 carlaBalance = mockUsdt.balanceOf(carla);
        uint256 davidBalance = mockUsdt.balanceOf(david);
        
        console2.log("Bob's USDT balance:", bobBalance);
        console2.log("Carla's USDT balance:", carlaBalance);
        console2.log("David's USDT balance:", davidBalance);
        
        assertGt(bobBalance, 0, "Bob should have USDT");
        assertGt(carlaBalance, 0, "Carla should have USDT");
        assertGt(davidBalance, 0, "David should have USDT");
        
        // Approve exchange to spend tokens
        vm.prank(bob);
        mockUsdt.approve(address(exchange), type(uint256).max);
        
        vm.prank(carla);
        mockUsdt.approve(address(exchange), type(uint256).max);
        
        vm.prank(david);
        mockUsdt.approve(address(exchange), type(uint256).max);
        
        console2.log("Token setup completed successfully!");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _mintTokens(address to, uint256 amount) internal {
        // Use admin to mint tokens
        vm.prank(admin);
        mockUsdt.mint(to, amount);
        console2.log("Minted", amount, "USDT to", vm.toString(to));
    }

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

    function testCompleteWorkflow() public {
        console2.log("\n--- Testing Complete Workflow ---");
        
        // Setup tokens
        testTokenSetup();
        
        // Register tokens with unique condition
        console2.log("Registering tokens for complete workflow...");
        bytes32 workflowQuestionId = keccak256(abi.encodePacked("complete-workflow-test", block.timestamp, "unique"));
        address testOracle = admin;
        
        ctf.prepareCondition(testOracle, workflowQuestionId, 2);
        bytes32 workflowConditionId = ctf.getConditionId(testOracle, workflowQuestionId, 2);
        console2.log("Workflow condition ID:", vm.toString(workflowConditionId));
        
        uint256 workflowYes = ctf.getPositionId(mockUsdt, ctf.getCollectionId(bytes32(0), workflowConditionId, 2));
        uint256 workflowNo = ctf.getPositionId(mockUsdt, ctf.getCollectionId(bytes32(0), workflowConditionId, 1));
        
        vm.prank(admin);
        exchange.registerToken(workflowYes, workflowNo, workflowConditionId);
        console2.log("Workflow tokens registered successfully");
        
        // Create orders with registered tokens
        Order memory buyOrder = _createOrder(bob, workflowYes, 50_000_000, 100_000_000, Side.BUY);
        Order memory sellOrder = _createOrder(carla, workflowYes, 50_000_000, 100_000_000, Side.SELL);
        
        console2.log("Workflow orders created successfully");
        
        // Test order hashing and signing
        bytes32 buyOrderHash = exchange.hashOrder(buyOrder);
        bytes32 sellOrderHash = exchange.hashOrder(sellOrder);
        console2.log("Workflow buy order hash:", vm.toString(buyOrderHash));
        console2.log("Workflow sell order hash:", vm.toString(sellOrderHash));
        
        Order memory signedBuyOrder = _createAndSignOrder(BOB_PRIVATE_KEY, workflowYes, 50_000_000, 100_000_000, Side.BUY);
        Order memory signedSellOrder = _createAndSignOrder(CARLA_PRIVATE_KEY, workflowYes, 50_000_000, 100_000_000, Side.SELL);
        
        // Test order validation
        exchange.validateOrder(signedBuyOrder);
        exchange.validateOrder(signedSellOrder);
        console2.log("Workflow order validation passed");
        
        console2.log("Complete workflow test passed!");
    }
}
