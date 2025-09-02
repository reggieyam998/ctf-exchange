// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";
import { FoxMinimalOracle } from "../FoxMinimalOracle.sol";
import { IFoxMinimalOracle } from "../interfaces/IFoxMinimalOracle.sol";
import { MockERC20 } from "../../dev/mocks/MockERC20.sol";
import { MockConditionalTokens } from "../../dev/mocks/MockConditionalTokens.sol";
import { PayoutDecoderLib } from "../libraries/PayoutDecoderLib.sol";

/// @title Fox Minimal Oracle Tests
/// @notice Comprehensive tests for the Fox Minimal Oracle
/// @author Fox Market
contract FoxMinimalOracleTest is Test {
    FoxMinimalOracle public oracle;
    MockERC20 public bondToken;
    MockConditionalTokens public ctf;

    address public owner = address(0x1);
    address public proposer = address(0x2);
    address public user = address(0x3);
    address public disputer = address(0x4);

    bytes32 public constant REQUEST_ID = keccak256("test-request");
    bytes32 public constant QUESTION_ID = keccak256("test-question");

    function setUp() public {
        // Deploy mock contracts
        bondToken = new MockERC20("USDT", "USDT", 6);
        ctf = new MockConditionalTokens();

        // Deploy oracle
        vm.prank(owner);
        oracle = new FoxMinimalOracle(address(bondToken), address(ctf));

        // Setup initial state
        bondToken.mint(owner, 1000 * 10**6);
        bondToken.mint(proposer, 1000 * 10**6);
        bondToken.mint(user, 1000 * 10**6);
        bondToken.mint(disputer, 1000 * 10**6);

        // Add proposer to whitelist
        vm.prank(owner);
        oracle.addProposer(proposer);
    }

    /*//////////////////////////////////////////////////////////////
                                BASIC TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public {
        assertEq(oracle.owner(), owner);
        assertEq(address(oracle.bondToken()), address(bondToken));
        assertEq(address(oracle.ctf()), address(ctf));
        assertEq(oracle.minBond(), 10 * 10**6);
        assertEq(oracle.defaultLiveness(), 300);
        assertEq(oracle.MAX_OUTCOMES(), 7);
        assertEq(oracle.proposerCount(), 2); // owner + proposer
        assertTrue(oracle.isWhitelistedProposer(owner));
        assertTrue(oracle.isWhitelistedProposer(proposer));
    }

    function test_RequestPrice() public {
        bytes memory ancillaryData = "NBA Game ID:123, Market Type:Winner";
        uint256 bond = 20 * 10**6;
        uint256 liveness = 300;

        vm.startPrank(user);
        bondToken.approve(address(oracle), bond);
        
        oracle.requestPrice(REQUEST_ID, ancillaryData, bond, liveness);
        vm.stopPrank();

        FoxMinimalOracle.Request memory request = oracle.getRequest(REQUEST_ID);
        assertEq(request.timestamp, block.timestamp);
        assertEq(request.ancillaryData, ancillaryData);
        assertEq(request.bond, bond);
        assertEq(request.proposer, address(0));
        assertFalse(request.disputed);
        assertEq(request.disputeDeadline, block.timestamp + liveness);
        assertFalse(request.settled);
    }

    function test_RequestPrice_RevertIfAlreadyExists() public {
        bytes memory ancillaryData = "test";
        uint256 bond = 20 * 10**6;

        vm.startPrank(user);
        bondToken.approve(address(oracle), bond * 2);
        
        oracle.requestPrice(REQUEST_ID, ancillaryData, bond, 300);
        
        vm.expectRevert("Request already exists");
        oracle.requestPrice(REQUEST_ID, ancillaryData, bond, 300);
        vm.stopPrank();
    }

    function test_RequestPrice_RevertIfBondTooLow() public {
        bytes memory ancillaryData = "test";
        uint256 bond = 5 * 10**6; // Below min bond

        vm.startPrank(user);
        bondToken.approve(address(oracle), bond);
        
        vm.expectRevert("Bond too low");
        oracle.requestPrice(REQUEST_ID, ancillaryData, bond, 300);
        vm.stopPrank();
    }

    function test_RequestPrice_RevertIfInvalidLiveness() public {
        bytes memory ancillaryData = "test";
        uint256 bond = 20 * 10**6;

        vm.startPrank(user);
        bondToken.approve(address(oracle), bond);
        
        vm.expectRevert("Invalid liveness period");
        oracle.requestPrice(REQUEST_ID, ancillaryData, bond, 200); // Too short
        
        vm.expectRevert("Invalid liveness period");
        oracle.requestPrice(REQUEST_ID, ancillaryData, bond, 700); // Too long
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                PROPOSAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ProposePrice_Binary() public {
        _createRequest();
        
        int256[] memory price = new int256[](1);
        price[0] = 1e18; // Yes outcome

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);

        FoxMinimalOracle.Request memory request = oracle.getRequest(REQUEST_ID);
        assertEq(request.proposedPrice.length, 1);
        assertEq(request.proposedPrice[0], 1e18);
        assertEq(request.proposer, proposer);
    }

    function test_ProposePrice_Sports() public {
        _createRequest();
        
        int256[] memory price = new int256[](2);
        price[0] = 105; // Home score
        price[1] = 98;  // Away score

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);

        FoxMinimalOracle.Request memory request = oracle.getRequest(REQUEST_ID);
        assertEq(request.proposedPrice.length, 2);
        assertEq(request.proposedPrice[0], 105);
        assertEq(request.proposedPrice[1], 98);
        assertEq(request.proposer, proposer);
    }

    function test_ProposePrice_RevertIfNotWhitelisted() public {
        _createRequest();
        
        int256[] memory price = new int256[](1);
        price[0] = 1e18;

        vm.prank(user);
        vm.expectRevert("Not whitelisted proposer");
        oracle.proposePrice(REQUEST_ID, price);
    }

    function test_ProposePrice_RevertIfAlreadyProposed() public {
        _createRequest();
        
        int256[] memory price = new int256[](1);
        price[0] = 1e18;

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);
        
        vm.prank(proposer);
        vm.expectRevert("Price already proposed");
        oracle.proposePrice(REQUEST_ID, price);
    }

    function test_ProposePrice_RevertIfInvalidBinaryPrice() public {
        _createRequest();
        
        int256[] memory price = new int256[](1);
        price[0] = 2e18; // Invalid binary price

        vm.prank(proposer);
        vm.expectRevert("Invalid binary price");
        oracle.proposePrice(REQUEST_ID, price);
    }

    function test_ProposePrice_RevertIfTooManyOutcomes() public {
        _createRequest();
        
        int256[] memory price = new int256[](8); // More than MAX_OUTCOMES

        vm.prank(proposer);
        vm.expectRevert("Invalid price array length");
        oracle.proposePrice(REQUEST_ID, price);
    }

    /*//////////////////////////////////////////////////////////////
                                DISPUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DisputePrice() public {
        _createRequest();
        _proposePrice();
        
        uint256 disputeBond = 15 * 10**6;

        vm.startPrank(disputer);
        bondToken.approve(address(oracle), disputeBond);
        
        oracle.disputePrice(REQUEST_ID, disputeBond);
        vm.stopPrank();

        FoxMinimalOracle.Request memory request = oracle.getRequest(REQUEST_ID);
        assertTrue(request.disputed);
    }

    function test_DisputePrice_RevertIfNoProposal() public {
        _createRequest();
        
        uint256 disputeBond = 15 * 10**6;

        vm.startPrank(disputer);
        bondToken.approve(address(oracle), disputeBond);
        
        vm.expectRevert("No price proposed");
        oracle.disputePrice(REQUEST_ID, disputeBond);
        vm.stopPrank();
    }

    function test_DisputePrice_RevertIfAlreadyDisputed() public {
        _createRequest();
        _proposePrice();
        _disputePrice();
        
        uint256 disputeBond = 15 * 10**6;

        vm.startPrank(user);
        bondToken.approve(address(oracle), disputeBond);
        
        vm.expectRevert("Already disputed");
        oracle.disputePrice(REQUEST_ID, disputeBond);
        vm.stopPrank();
    }

    function test_DisputePrice_RevertIfBondTooLow() public {
        _createRequest();
        _proposePrice();
        
        uint256 disputeBond = 5 * 10**6; // Below min bond

        vm.startPrank(disputer);
        bondToken.approve(address(oracle), disputeBond);
        
        vm.expectRevert("Dispute bond too low");
        oracle.disputePrice(REQUEST_ID, disputeBond);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                SETTLEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SettleRequest_Undisputed() public {
        _createRequest();
        _proposePrice();
        
        // Fast forward past liveness period
        vm.warp(block.timestamp + 301);
        
        oracle.settleRequest(REQUEST_ID, new int256[](0));

        FoxMinimalOracle.Request memory request = oracle.getRequest(REQUEST_ID);
        assertTrue(request.settled);
    }

    function test_SettleRequest_Disputed() public {
        _createRequest();
        _proposePrice();
        _disputePrice();
        
        // Fast forward past liveness period
        vm.warp(block.timestamp + 301);

        int256[] memory finalPrice = new int256[](1);
        finalPrice[0] = 0; // No outcome

        vm.prank(owner);
        oracle.settleRequest(REQUEST_ID, finalPrice);

        FoxMinimalOracle.Request memory request = oracle.getRequest(REQUEST_ID);
        assertTrue(request.settled);
    }

    function test_SettleRequest_RevertIfLivenessNotExpired() public {
        _createRequest();
        _proposePrice();
        
        vm.expectRevert("Liveness period not expired");
        oracle.settleRequest(REQUEST_ID, new int256[](0));
    }

    function test_SettleRequest_RevertIfDisputedNotOwner() public {
        _createRequest();
        _proposePrice();
        _disputePrice();
        
        // Fast forward past liveness period
        vm.warp(block.timestamp + 301);

        int256[] memory finalPrice = new int256[](1);
        finalPrice[0] = 0;

        vm.prank(user);
        vm.expectRevert("Only owner can settle disputed requests");
        oracle.settleRequest(REQUEST_ID, finalPrice);
    }

    /*//////////////////////////////////////////////////////////////
                                CTF INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ReportPayoutsToCTF_Binary() public {
        _createRequest();
        _proposePrice();
        _settleRequest();
        
        vm.expectCall(
            address(ctf),
            abi.encodeWithSelector(ctf.reportPayouts.selector, QUESTION_ID, _getBinaryPayouts())
        );
        
        oracle.reportPayoutsToCTF(REQUEST_ID, QUESTION_ID, 2);
    }

    function test_ReportPayoutsToCTF_Sports() public {
        _createRequest();
        _proposeSportsPrice();
        _settleRequest();
        
        uint256[] memory expectedPayouts = new uint256[](3);
        expectedPayouts[0] = 1; // Home Win
        expectedPayouts[1] = 0; // Away Win
        expectedPayouts[2] = 0; // Tie

        vm.expectCall(
            address(ctf),
            abi.encodeWithSelector(ctf.reportPayouts.selector, QUESTION_ID, expectedPayouts)
        );
        
        oracle.reportPayoutsToCTF(REQUEST_ID, QUESTION_ID, 3);
    }

    function test_ReportPayoutsToCTF_RevertIfNotSettled() public {
        _createRequest();
        _proposePrice();
        
        vm.expectRevert("Request not settled");
        oracle.reportPayoutsToCTF(REQUEST_ID, QUESTION_ID, 2);
    }

    /*//////////////////////////////////////////////////////////////
                                MULTI-OUTCOME SPORTS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ProposePrice_Spread() public {
        _createRequest();
        
        int256[] memory price = new int256[](3);
        price[0] = 105; // Home score
        price[1] = 98;  // Away score
        price[2] = 5;   // Spread line (+5.5)

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);

        FoxMinimalOracle.Request memory request = oracle.getRequest(REQUEST_ID);
        assertEq(request.proposedPrice.length, 3);
        assertEq(request.proposedPrice[0], 105);
        assertEq(request.proposedPrice[1], 98);
        assertEq(request.proposedPrice[2], 5);
    }

    function test_ProposePrice_Total() public {
        _createRequest();
        
        int256[] memory price = new int256[](4);
        price[0] = 105; // Home score
        price[1] = 98;  // Away score
        price[2] = 0;   // No spread
        price[3] = 200; // Total line (over/under 200)

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);

        FoxMinimalOracle.Request memory request = oracle.getRequest(REQUEST_ID);
        assertEq(request.proposedPrice.length, 4);
        assertEq(request.proposedPrice[3], 200);
    }

    function test_SportsMarket_AwayWin() public {
        _createRequest();
        
        int256[] memory price = new int256[](2);
        price[0] = 98;  // Home score
        price[1] = 105; // Away score (away wins)

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);
        _settleRequest();
        
        uint256[] memory expectedPayouts = new uint256[](3);
        expectedPayouts[0] = 0; // Home Win
        expectedPayouts[1] = 1; // Away Win
        expectedPayouts[2] = 0; // Tie

        vm.expectCall(
            address(ctf),
            abi.encodeWithSelector(ctf.reportPayouts.selector, QUESTION_ID, expectedPayouts)
        );
        
        oracle.reportPayoutsToCTF(REQUEST_ID, QUESTION_ID, 3);
    }

    function test_SportsMarket_Tie() public {
        _createRequest();
        
        int256[] memory price = new int256[](2);
        price[0] = 100; // Home score
        price[1] = 100; // Away score (tie)

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);
        _settleRequest();
        
        uint256[] memory expectedPayouts = new uint256[](3);
        expectedPayouts[0] = 0; // Home Win
        expectedPayouts[1] = 0; // Away Win
        expectedPayouts[2] = 1; // Tie

        vm.expectCall(
            address(ctf),
            abi.encodeWithSelector(ctf.reportPayouts.selector, QUESTION_ID, expectedPayouts)
        );
        
        oracle.reportPayoutsToCTF(REQUEST_ID, QUESTION_ID, 3);
    }

    function test_SportsMarket_Canceled() public {
        _createRequest();
        
        int256[] memory price = new int256[](5);
        price[0] = 0;   // Home score
        price[1] = 0;   // Away score
        price[2] = 0;   // Spread
        price[3] = 0;   // Total
        price[4] = 1;   // Canceled flag

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);
        _settleRequest();
        
        // Canceled markets should split payouts equally
        uint256[] memory expectedPayouts = new uint256[](3);
        expectedPayouts[0] = 1; // All outcomes get 1 (split)
        expectedPayouts[1] = 1;
        expectedPayouts[2] = 1;

        vm.expectCall(
            address(ctf),
            abi.encodeWithSelector(ctf.reportPayouts.selector, QUESTION_ID, expectedPayouts)
        );
        
        oracle.reportPayoutsToCTF(REQUEST_ID, QUESTION_ID, 3);
    }

    function test_SpreadMarket_HomeCovers() public {
        _createRequest();
        
        int256[] memory price = new int256[](3);
        price[0] = 110; // Home score
        price[1] = 100; // Away score
        price[2] = 5;   // Spread line (+5.5) - Home covers

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);
        _settleRequest();
        
        uint256[] memory expectedPayouts = new uint256[](3);
        expectedPayouts[0] = 1; // Home covers
        expectedPayouts[1] = 0; // Away covers
        expectedPayouts[2] = 0; // Push

        vm.expectCall(
            address(ctf),
            abi.encodeWithSelector(ctf.reportPayouts.selector, QUESTION_ID, expectedPayouts)
        );
        
        oracle.reportPayoutsToCTF(REQUEST_ID, QUESTION_ID, 3);
    }

    function test_SpreadMarket_Push() public {
        _createRequest();
        
        int256[] memory price = new int256[](3);
        price[0] = 105; // Home score
        price[1] = 100; // Away score
        price[2] = 5;   // Spread line (exact push)

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);
        _settleRequest();
        
        uint256[] memory expectedPayouts = new uint256[](3);
        expectedPayouts[0] = 0; // Home covers
        expectedPayouts[1] = 0; // Away covers
        expectedPayouts[2] = 1; // Push

        vm.expectCall(
            address(ctf),
            abi.encodeWithSelector(ctf.reportPayouts.selector, QUESTION_ID, expectedPayouts)
        );
        
        oracle.reportPayoutsToCTF(REQUEST_ID, QUESTION_ID, 3);
    }

    function test_TotalMarket_Over() public {
        _createRequest();
        
        int256[] memory price = new int256[](4);
        price[0] = 110; // Home score
        price[1] = 95;  // Away score
        price[2] = 0;   // No spread
        price[3] = 200; // Total line (over/under 200) - Total = 205 (over)

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);
        _settleRequest();
        
        uint256[] memory expectedPayouts = new uint256[](3);
        expectedPayouts[0] = 1; // Over
        expectedPayouts[1] = 0; // Under
        expectedPayouts[2] = 0; // Push

        vm.expectCall(
            address(ctf),
            abi.encodeWithSelector(ctf.reportPayouts.selector, QUESTION_ID, expectedPayouts)
        );
        
        oracle.reportPayoutsToCTF(REQUEST_ID, QUESTION_ID, 3);
    }

    function test_TotalMarket_Push() public {
        _createRequest();
        
        int256[] memory price = new int256[](4);
        price[0] = 100; // Home score
        price[1] = 100; // Away score
        price[2] = 0;   // No spread
        price[3] = 200; // Total line (exact push)

        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);
        _settleRequest();
        
        uint256[] memory expectedPayouts = new uint256[](3);
        expectedPayouts[0] = 0; // Over
        expectedPayouts[1] = 0; // Under
        expectedPayouts[2] = 1; // Push

        vm.expectCall(
            address(ctf),
            abi.encodeWithSelector(ctf.reportPayouts.selector, QUESTION_ID, expectedPayouts)
        );
        
        oracle.reportPayoutsToCTF(REQUEST_ID, QUESTION_ID, 3);
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AddProposer() public {
        address newProposer = address(0x5);

        vm.prank(owner);
        oracle.addProposer(newProposer);

        assertTrue(oracle.isWhitelistedProposer(newProposer));
        assertEq(oracle.proposerCount(), 3);
    }

    function test_RemoveProposer() public {
        vm.prank(owner);
        oracle.removeProposer(proposer);

        assertFalse(oracle.isWhitelistedProposer(proposer));
        assertEq(oracle.proposerCount(), 1);
    }

    function test_RemoveProposer_RevertIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        oracle.removeProposer(proposer);
    }

    function test_SetMinBond() public {
        uint256 newMinBond = 25 * 10**6;

        vm.prank(owner);
        oracle.setMinBond(newMinBond);

        assertEq(oracle.minBond(), newMinBond);
    }

    function test_SetDefaultLiveness() public {
        uint256 newLiveness = 450;

        vm.prank(owner);
        oracle.setDefaultLiveness(newLiveness);

        assertEq(oracle.defaultLiveness(), newLiveness);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createRequest() internal {
        bytes memory ancillaryData = "test";
        uint256 bond = 20 * 10**6;

        vm.startPrank(user);
        bondToken.approve(address(oracle), bond);
        oracle.requestPrice(REQUEST_ID, ancillaryData, bond, 300);
        vm.stopPrank();
    }

    function _proposePrice() internal {
        int256[] memory price = _getBinaryPrice();
        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);
    }

    function _proposeSportsPrice() internal {
        int256[] memory price = new int256[](2);
        price[0] = 105; // Home score
        price[1] = 98;  // Away score
        vm.prank(proposer);
        oracle.proposePrice(REQUEST_ID, price);
    }

    function _disputePrice() internal {
        uint256 disputeBond = 15 * 10**6;
        vm.startPrank(disputer);
        bondToken.approve(address(oracle), disputeBond);
        oracle.disputePrice(REQUEST_ID, disputeBond);
        vm.stopPrank();
    }

    function _settleRequest() internal {
        vm.warp(block.timestamp + 301);
        oracle.settleRequest(REQUEST_ID, new int256[](0));
    }

    function _getBinaryPrice() internal pure returns (int256[] memory) {
        int256[] memory price = new int256[](1);
        price[0] = 1e18; // Yes outcome
        return price;
    }

    function _getBinaryPayouts() internal pure returns (uint256[] memory) {
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1; // Yes outcome wins
        payouts[1] = 0; // No outcome loses
        return payouts;
    }
}
