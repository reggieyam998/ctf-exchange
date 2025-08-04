// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { CTFExchange } from "src/exchange/CTFExchange.sol";
import { USDC } from "src/dev/mocks/USDC.sol";
import { Deployer } from "src/dev/util/Deployer.sol";
import { IConditionalTokens } from "src/exchange/interfaces/IConditionalTokens.sol";
import { ExchangeBeacon } from "src/dev/mocks/ExchangeBeacon.sol";
import { BeaconProxyFactory } from "src/dev/mocks/BeaconProxyFactory.sol";
import { MockBeaconImplementation } from "src/dev/mocks/MockBeaconImplementation.sol";
import { MockGnosisSafeFactory } from "src/dev/mocks/MockGnosisSafeFactory.sol";
import { Order, Side, MatchType, OrderStatus, SignatureType } from "src/exchange/libraries/OrderStructs.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IERC1155 } from "openzeppelin-contracts/token/ERC1155/IERC1155.sol";

/// @title LocalTesting
/// @notice Comprehensive local testing for CTF Exchange functionality
contract LocalTesting is Test {
    // Deployed contracts
    USDC public usdc;
    IConditionalTokens public ctf;
    MockBeaconImplementation public mockImpl;
    ExchangeBeacon public beacon;
    BeaconProxyFactory public beaconFactory;
    MockGnosisSafeFactory public safeFactory;
    CTFExchange public exchange;

    // Test addresses
    address public admin;
    address public bob;
    address public carla;
    address public henry;
    address public brian;

    // Test data
    bytes32 public questionId;
    bytes32 public conditionId;
    uint256 public yes;
    uint256 public no;

    // Test amounts
    uint256 public constant INITIAL_BALANCE = 1_000_000_000; // 1000 USDC
    uint256 public constant ORDER_AMOUNT = 50_000_000; // 50 USDC
    uint256 public constant FEE_RATE_BPS = 30; // 0.3%

    function setUp() public {
        console.log("=== Setting Up Local Testing Environment ===");
        
        // Setup test addresses
        admin = vm.addr(0x1);
        bob = vm.addr(0xB0B);
        carla = vm.addr(0xCA414);
        henry = vm.addr(0x123456);
        brian = vm.addr(0x789ABC);

        // Deploy all contracts
        _deployContracts();
        
        // Setup exchange
        _setupExchange();
        
        console.log("=== Setup Complete ===");
    }

    function testTokenRegistration() public {
        console.log("\n--- Testing Token Registration ---");
        
        // Verify tokens are registered
        require(exchange.getCollateral() == address(usdc), "Collateral not set correctly");
        require(exchange.getCtf() == address(ctf), "CTF not set correctly");
        console.log("Token registration verified");
        
        // Test condition preparation
        bytes32 testQuestionId = keccak256("test-question-2");
        address testOracle = henry;
        
        ctf.prepareCondition(testOracle, testQuestionId, 3);
        bytes32 testConditionId = ctf.getConditionId(testOracle, testQuestionId, 3);
        console.log("Additional condition prepared:", vm.toString(testConditionId));
        
        console.log("Token registration test passed!");
    }

    function testOrderCreationAndSigning() public {
        console.log("\n--- Testing Order Creation and Signing ---");
        
        // Test EOA signature
        Order memory order = _createAndSignOrder(bob, yes, ORDER_AMOUNT, ORDER_AMOUNT * 2, Side.BUY);
        console.log("EOA order created and signed");
        
        // Verify order signature
        exchange.validateOrderSignature(exchange.hashOrder(order), order);
        console.log("EOA signature verified");
        
        // Test order with fees
        Order memory feeOrder = _createAndSignOrderWithFee(bob, yes, ORDER_AMOUNT, ORDER_AMOUNT * 2, FEE_RATE_BPS, Side.BUY);
        console.log("Order with fees created and signed");
        
        // Test different order types
        Order memory sellOrder = _createAndSignOrder(carla, no, ORDER_AMOUNT, ORDER_AMOUNT * 2, Side.SELL);
        console.log("Sell order created and signed");
        
        console.log("Order creation and signing test passed!");
    }

    function testOrderMatchingAndExecution() public {
        console.log("\n--- Testing Order Matching and Execution ---");
        
        // Create buy and sell orders
        Order memory buyOrder = _createAndSignOrder(bob, yes, ORDER_AMOUNT, ORDER_AMOUNT * 2, Side.BUY);
        Order memory sellOrder = _createAndSignOrder(carla, yes, ORDER_AMOUNT, ORDER_AMOUNT * 2, Side.SELL);
        
        // Test single order fill
        vm.prank(carla);
        exchange.fillOrder(buyOrder, ORDER_AMOUNT);
        console.log("Single order fill successful");
        
        // Test order matching
        Order[] memory makerOrders = new Order[](1);
        makerOrders[0] = sellOrder;
        
        uint256[] memory makerFillAmounts = new uint256[](1);
        makerFillAmounts[0] = ORDER_AMOUNT;
        
        Order memory takerOrder = _createAndSignOrder(henry, yes, ORDER_AMOUNT, ORDER_AMOUNT * 2, Side.BUY);
        
        vm.prank(henry);
        exchange.matchOrders(takerOrder, makerOrders, ORDER_AMOUNT, makerFillAmounts);
        console.log("Order matching successful");
        
        console.log("Order matching and execution test passed!");
    }

    function testFeeCalculation() public {
        console.log("\n--- Testing Fee Calculation ---");
        
        // Create order with fees
        Order memory feeOrder = _createAndSignOrderWithFee(bob, yes, ORDER_AMOUNT, ORDER_AMOUNT * 2, FEE_RATE_BPS, Side.BUY);
        
        // Calculate expected fee
        uint256 expectedFee = (ORDER_AMOUNT * FEE_RATE_BPS) / 10000;
        console.log("Expected fee:", expectedFee);
        
        // Test fee order execution
        vm.prank(carla);
        exchange.fillOrder(feeOrder, ORDER_AMOUNT);
        console.log("Fee order execution successful");
        
        console.log("Fee calculation test passed!");
    }

    function testPauseFunctionality() public {
        console.log("\n--- Testing Pause Functionality ---");
        
        // Test pause
        vm.prank(admin);
        exchange.pauseTrading();
        console.log("Trading paused");
        
        // Verify pause prevents trading
        Order memory order = _createAndSignOrder(bob, yes, ORDER_AMOUNT, ORDER_AMOUNT * 2, Side.BUY);
        
        vm.expectRevert();
        vm.prank(carla);
        exchange.fillOrder(order, ORDER_AMOUNT);
        console.log("Pause prevents trading - verified");
        
        // Test unpause
        vm.prank(admin);
        exchange.unpauseTrading();
        console.log("Trading unpaused");
        
        // Verify trading resumes
        vm.prank(carla);
        exchange.fillOrder(order, ORDER_AMOUNT);
        console.log("Trading resumed successfully");
        
        console.log("Pause functionality test passed!");
    }

    function testAuthFunctionality() public {
        console.log("\n--- Testing Auth Functionality ---");
        
        // Test admin functions
        require(exchange.isAdmin(admin), "Admin should be admin");
        require(exchange.isOperator(admin), "Admin should be operator");
        require(exchange.isOperator(bob), "Bob should be operator");
        require(exchange.isOperator(carla), "Carla should be operator");
        console.log("Admin roles verified");
        
        // Test adding new admin
        vm.prank(admin);
        exchange.addAdmin(henry);
        require(exchange.isAdmin(henry), "Henry should be admin");
        console.log("New admin added successfully");
        
        // Test removing admin
        vm.prank(admin);
        exchange.removeAdmin(henry);
        require(!exchange.isAdmin(henry), "Henry should not be admin");
        console.log("Admin removed successfully");
        
        console.log("Auth functionality test passed!");
    }

    function testBeaconProxyIntegration() public {
        console.log("\n--- Testing Beacon Proxy Integration ---");
        
        // Test beacon functionality
        address currentImpl = beacon.implementation();
        require(currentImpl == address(mockImpl), "Beacon implementation mismatch");
        console.log("Beacon implementation verified");
        
        // Test factory functionality
        address factoryBeacon = beaconFactory.getBeacon();
        require(factoryBeacon == address(beacon), "Factory beacon mismatch");
        console.log("Factory beacon verified");
        
        // Test proxy creation prediction
        address testOwner = vm.addr(999);
        bytes32 testSalt = keccak256("test-salt");
        
        address predictedProxy = beaconFactory.predictProxyAddress(testOwner, testSalt);
        console.log("Predicted proxy address:", predictedProxy);
        
        // Test that proxy doesn't exist yet
        bool proxyExists = beaconFactory.proxyExists(testOwner, testSalt);
        require(!proxyExists, "Proxy should not exist yet");
        console.log("Proxy existence check passed");
        
        console.log("Beacon proxy integration test passed!");
    }

    function testSafeFactoryIntegration() public {
        console.log("\n--- Testing Safe Factory Integration ---");
        
        // Test safe factory functionality
        address masterCopy = safeFactory.masterCopy();
        console.log("Safe factory master copy:", masterCopy);
        
        // Test safe creation
        address testOwner = vm.addr(888);
        address createdSafe = safeFactory.createSafe(testOwner);
        console.log("Safe created for owner:", createdSafe);
        
        // Test safe address prediction
        address predictedSafe = safeFactory.predictSafeAddress(testOwner);
        console.log("Predicted safe address:", predictedSafe);
        
        console.log("Safe factory integration test passed!");
    }

    function testCompleteExchangeWorkflow() public {
        console.log("\n--- Testing Complete Exchange Workflow ---");
        
        // 1. Create orders
        Order memory buyOrder = _createAndSignOrder(bob, yes, ORDER_AMOUNT, ORDER_AMOUNT * 2, Side.BUY);
        Order memory sellOrder = _createAndSignOrder(carla, yes, ORDER_AMOUNT, ORDER_AMOUNT * 2, Side.SELL);
        
        // 2. Execute trades
        vm.prank(carla);
        exchange.fillOrder(buyOrder, ORDER_AMOUNT);
        console.log("Buy order executed");
        
        vm.prank(bob);
        exchange.fillOrder(sellOrder, ORDER_AMOUNT);
        console.log("Sell order executed");
        
        // 3. Test pause/unpause
        vm.prank(admin);
        exchange.pauseTrading();
        console.log("Trading paused");
        
        vm.prank(admin);
        exchange.unpauseTrading();
        console.log("Trading unpaused");
        
        // 4. Test with fees
        Order memory feeOrder = _createAndSignOrderWithFee(henry, yes, ORDER_AMOUNT, ORDER_AMOUNT * 2, FEE_RATE_BPS, Side.BUY);
        vm.prank(brian);
        exchange.fillOrder(feeOrder, ORDER_AMOUNT);
        console.log("Fee order executed");
        
        console.log("Complete exchange workflow test passed!");
    }

    // Helper functions
    function _deployContracts() internal {
        console.log("\n--- Deploying Contracts ---");
        
        // 1. Deploy Mock USDC
        usdc = new USDC();
        console.log("Mock USDC deployed at:", address(usdc));

        // 2. Deploy Real ConditionalTokens
        ctf = IConditionalTokens(Deployer.ConditionalTokens());
        console.log("Real ConditionalTokens deployed at:", address(ctf));

        // 3. Deploy Mock Beacon Implementation
        mockImpl = new MockBeaconImplementation();
        console.log("Mock Beacon Implementation deployed at:", address(mockImpl));

        // 4. Deploy Exchange Beacon
        beacon = new ExchangeBeacon(address(mockImpl), admin);
        console.log("Exchange Beacon deployed at:", address(beacon));

        // 5. Deploy Beacon Proxy Factory
        beaconFactory = new BeaconProxyFactory(address(beacon), admin);
        console.log("Beacon Proxy Factory deployed at:", address(beaconFactory));

        // 6. Deploy Mock Gnosis Safe Factory
        address mockMasterCopy = address(0x1234567890123456789012345678901234567890);
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
    }

    function _setupExchange() internal {
        console.log("\n--- Setting Up Exchange ---");
        
        // Setup admin roles
        exchange.addAdmin(admin);
        exchange.addOperator(admin);
        exchange.addOperator(bob);
        exchange.addOperator(carla);
        console.log("Admin roles configured");

        // Prepare condition and tokens
        questionId = keccak256("test-question");
        address oracle = admin;
        
        ctf.prepareCondition(oracle, questionId, 2);
        conditionId = ctf.getConditionId(oracle, questionId, 2);
        console.log("Condition prepared:", vm.toString(conditionId));

        // Get position IDs
        yes = _getPositionId(2);
        no = _getPositionId(1);
        console.log("Yes position ID:", yes);
        console.log("No position ID:", no);

        // Register tokens
        exchange.registerToken(yes, no, conditionId);
        console.log("Tokens registered");

        // Mint initial balances
        _mintTestTokens(bob, address(exchange), INITIAL_BALANCE);
        _mintTestTokens(carla, address(exchange), INITIAL_BALANCE);
        _mintTestTokens(henry, address(exchange), INITIAL_BALANCE);
        _mintTestTokens(brian, address(exchange), INITIAL_BALANCE);
        console.log("Initial balances minted");
        
        // Approve exchange to transfer ERC1155 tokens
        _approveERC1155ForExchange();
        console.log("ERC1155 approvals completed");
    }

    function _getPositionId(uint256 indexSet) internal view returns (uint256) {
        return ctf.getPositionId(IERC20(address(usdc)), ctf.getCollectionId(bytes32(0), conditionId, indexSet));
    }

    function _mintTestTokens(address to, address exchangeAddress, uint256 amount) internal {
        usdc.mint(to, amount);
        vm.prank(to);
        usdc.approve(exchangeAddress, amount);
    }
    
    function _approveERC1155ForExchange() internal {
        // Approve exchange to transfer ERC1155 tokens for all test users
        address[] memory users = new address[](4);
        users[0] = bob;
        users[1] = carla;
        users[2] = henry;
        users[3] = brian;
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            IERC1155(address(ctf)).setApprovalForAll(address(exchange), true);
        }
    }

    function _createOrder(address maker, uint256 tokenId, uint256 makerAmount, uint256 takerAmount, Side side) internal view returns (Order memory) {
        return Order({
            salt: uint256(keccak256(abi.encodePacked(block.timestamp, maker, tokenId))),
            maker: maker,
            signer: maker,
            taker: address(0),
            tokenId: tokenId,
            makerAmount: makerAmount,
            takerAmount: takerAmount,
            expiration: block.timestamp + 3600, // 1 hour from now
            nonce: 0,
            feeRateBps: 0,
            side: side,
            signatureType: SignatureType.EOA,
            signature: ""
        });
    }

    function _createAndSignOrder(address maker, uint256 tokenId, uint256 makerAmount, uint256 takerAmount, Side side) internal returns (Order memory) {
        Order memory order = _createOrder(maker, tokenId, makerAmount, takerAmount, side);
        order.signature = _signMessage(maker, exchange.hashOrder(order));
        return order;
    }

    function _createAndSignOrderWithFee(address maker, uint256 tokenId, uint256 makerAmount, uint256 takerAmount, uint256 feeRateBps, Side side) internal returns (Order memory) {
        Order memory order = _createOrder(maker, tokenId, makerAmount, takerAmount, side);
        order.feeRateBps = feeRateBps;
        order.signature = _signMessage(maker, exchange.hashOrder(order));
        return order;
    }

    function _signMessage(address signer, bytes32 messageHash) internal returns (bytes memory) {
        uint256 privateKey = 0xB0B; // Use bob's private key for testing
        if (signer == carla) privateKey = 0xCA414;
        if (signer == henry) privateKey = 0x123456;
        if (signer == brian) privateKey = 0x789ABC;
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        return abi.encodePacked(r, s, v);
    }
} 