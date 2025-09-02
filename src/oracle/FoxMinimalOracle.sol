// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "../common/ReentrancyGuard.sol";
import { IConditionalTokens } from "../exchange/interfaces/IConditionalTokens.sol";
import { PayoutDecoderLib } from "./libraries/PayoutDecoderLib.sol";
import { IFoxMinimalOracle } from "./interfaces/IFoxMinimalOracle.sol";

/// @title Fox Minimal Oracle
/// @notice Lightweight oracle for fast resolutions of prediction markets
/// @dev Supports binary (general markets) and multi-outcome (sports markets) resolutions
/// @author Fox Market
contract FoxMinimalOracle is Ownable, ReentrancyGuard {
    using PayoutDecoderLib for int256[];

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PriceRequested(
        bytes32 indexed requestId,
        bytes ancillaryData,
        uint256 bond,
        uint256 liveness,
        uint256 timestamp
    );

    event PriceProposed(
        bytes32 indexed requestId,
        address indexed proposer,
        int256[] price,
        uint256 timestamp
    );

    event PriceDisputed(
        bytes32 indexed requestId,
        address indexed disputer,
        uint256 bond,
        uint256 timestamp
    );

    event PriceSettled(
        bytes32 indexed requestId,
        int256[] finalPrice,
        bool disputed,
        uint256 timestamp
    );

    event ProposerWhitelisted(address indexed proposer, bool whitelisted);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Request {
        uint256 timestamp;
        bytes ancillaryData;
        int256[] proposedPrice;
        uint256 bond;
        address proposer;
        bool disputed;
        uint256 disputeDeadline;
        bool settled;
    }

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice USDT token for bonds and rewards
    IERC20 public immutable bondToken;

    /// @notice CTF contract for reporting payouts
    IConditionalTokens public immutable ctf;

    /// @notice Mapping of requestId to Request struct
    mapping(bytes32 => Request) public requests;

    /// @notice Mapping of whitelisted proposers
    mapping(address => bool) public whitelistedProposers;

    /// @notice Minimum bond amount in USDT (6 decimals)
    uint256 public minBond = 10 * 10**6; // $10 USDT

    /// @notice Default liveness period in seconds
    uint256 public defaultLiveness = 300; // 5 minutes

    /// @notice Maximum number of outcomes for multi-outcome markets
    uint8 public constant MAX_OUTCOMES = 7;

    /// @notice Number of whitelisted proposers
    uint256 public proposerCount;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _bondToken, address _ctf) {
        bondToken = IERC20(_bondToken);
        ctf = IConditionalTokens(_ctf);
        
        // Add owner as initial proposer
        whitelistedProposers[msg.sender] = true;
        proposerCount = 1;
        
        emit ProposerWhitelisted(msg.sender, true);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyWhitelistedProposer() {
        require(whitelistedProposers[msg.sender], "Not whitelisted proposer");
        _;
    }

    modifier requestExists(bytes32 requestId) {
        require(requests[requestId].timestamp != 0, "Request does not exist");
        _;
    }

    modifier requestNotSettled(bytes32 requestId) {
        require(!requests[requestId].settled, "Request already settled");
        _;
    }

    modifier withinLivenessPeriod(bytes32 requestId) {
        require(
            block.timestamp <= requests[requestId].disputeDeadline,
            "Liveness period expired"
        );
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Request a price resolution for a market
    /// @param requestId Unique identifier for the request
    /// @param ancillaryData Additional data describing the market (e.g., "NBA Game ID:123, Market Type:Winner")
    /// @param bond Amount of USDT to bond (must be >= minBond)
    /// @param liveness Liveness period in seconds (300-600 seconds)
    function requestPrice(
        bytes32 requestId,
        bytes calldata ancillaryData,
        uint256 bond,
        uint256 liveness
    ) external nonReentrant {
        require(requests[requestId].timestamp == 0, "Request already exists");
        require(bond >= minBond, "Bond too low");
        require(liveness >= 300 && liveness <= 600, "Invalid liveness period");

        // Transfer bond from caller
        require(
            bondToken.transferFrom(msg.sender, address(this), bond),
            "Bond transfer failed"
        );

        // Create request
        requests[requestId] = Request({
            timestamp: block.timestamp,
            ancillaryData: ancillaryData,
            proposedPrice: new int256[](0),
            bond: bond,
            proposer: address(0),
            disputed: false,
            disputeDeadline: block.timestamp + liveness,
            settled: false
        });

        emit PriceRequested(requestId, ancillaryData, bond, liveness, block.timestamp);
    }

    /// @notice Propose a price for a request
    /// @param requestId The request ID to propose for
    /// @param price The proposed price (binary: [0,1] or multi-outcome: [homeScore, awayScore, ...])
    function proposePrice(bytes32 requestId, int256[] calldata price)
        external
        nonReentrant
        onlyWhitelistedProposer
        requestExists(requestId)
        requestNotSettled(requestId)
        withinLivenessPeriod(requestId)
    {
        Request storage request = requests[requestId];
        
        require(request.proposer == address(0), "Price already proposed");
        require(price.length > 0 && price.length <= MAX_OUTCOMES, "Invalid price array length");

        // Validate binary market prices (0, 1, or 0.5 for invalid)
        if (price.length == 1) {
            require(
                price[0] == 0 || price[0] == 1e18 || price[0] == 0.5e18,
                "Invalid binary price"
            );
        }

        request.proposedPrice = price;
        request.proposer = msg.sender;

        emit PriceProposed(requestId, msg.sender, price, block.timestamp);
    }

    /// @notice Dispute a proposed price
    /// @param requestId The request ID to dispute
    /// @param bond Amount of USDT to bond for dispute
    function disputePrice(bytes32 requestId, uint256 bond)
        external
        nonReentrant
        requestExists(requestId)
        requestNotSettled(requestId)
        withinLivenessPeriod(requestId)
    {
        Request storage request = requests[requestId];
        
        require(request.proposer != address(0), "No price proposed");
        require(!request.disputed, "Already disputed");
        require(bond >= minBond, "Dispute bond too low");

        // Transfer dispute bond
        require(
            bondToken.transferFrom(msg.sender, address(this), bond),
            "Dispute bond transfer failed"
        );

        request.disputed = true;

        emit PriceDisputed(requestId, msg.sender, bond, block.timestamp);
    }

    /// @notice Settle a request (auto if undisputed, manual if disputed)
    /// @param requestId The request ID to settle
    /// @param finalPrice Final price to use (only for disputed requests)
    function settleRequest(bytes32 requestId, int256[] calldata finalPrice)
        external
        nonReentrant
        requestExists(requestId)
        requestNotSettled(requestId)
    {
        Request storage request = requests[requestId];
        
        require(request.proposer != address(0), "No price proposed");
        require(
            block.timestamp > request.disputeDeadline,
            "Liveness period not expired"
        );

        int256[] memory priceToUse;
        bool wasDisputed = request.disputed;

        if (request.disputed) {
            // Admin must provide final price for disputed requests
            require(msg.sender == owner(), "Only owner can settle disputed requests");
            require(finalPrice.length > 0 && finalPrice.length <= MAX_OUTCOMES, "Invalid final price");
            priceToUse = finalPrice;
        } else {
            // Use proposed price for undisputed requests
            priceToUse = request.proposedPrice;
        }

        request.settled = true;

        // Handle bond distribution
        _distributeBonds(requestId, request, wasDisputed);

        emit PriceSettled(requestId, priceToUse, wasDisputed, block.timestamp);
    }

    /// @notice Report payouts to CTF for a settled request
    /// @param requestId The request ID to report for
    /// @param questionId The CTF question ID
    /// @param outcomeSlotCount Number of outcome slots in CTF
    function reportPayoutsToCTF(
        bytes32 requestId,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) external nonReentrant requestExists(requestId) {
        Request storage request = requests[requestId];
        
        require(request.settled, "Request not settled");
        require(request.proposedPrice.length > 0, "No price available");

        // Decode payouts based on market type
        uint256[] memory payouts = _decodePayouts(request.proposedPrice, outcomeSlotCount);

        // Report to CTF
        ctf.reportPayouts(questionId, payouts);
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a proposer to the whitelist
    /// @param proposer Address to whitelist
    function addProposer(address proposer) external onlyOwner {
        require(proposer != address(0), "Invalid proposer address");
        require(!whitelistedProposers[proposer], "Already whitelisted");

        whitelistedProposers[proposer] = true;
        proposerCount++;

        emit ProposerWhitelisted(proposer, true);
    }

    /// @notice Remove a proposer from the whitelist
    /// @param proposer Address to remove from whitelist
    function removeProposer(address proposer) external onlyOwner {
        require(whitelistedProposers[proposer], "Not whitelisted");
        require(proposer != owner(), "Cannot remove owner");

        whitelistedProposers[proposer] = false;
        proposerCount--;

        emit ProposerWhitelisted(proposer, false);
    }

    /// @notice Update minimum bond amount
    /// @param newMinBond New minimum bond in USDT (6 decimals)
    function setMinBond(uint256 newMinBond) external onlyOwner {
        require(newMinBond > 0, "Invalid bond amount");
        minBond = newMinBond;
    }

    /// @notice Update default liveness period
    /// @param newLiveness New liveness period in seconds
    function setDefaultLiveness(uint256 newLiveness) external onlyOwner {
        require(newLiveness >= 300 && newLiveness <= 600, "Invalid liveness period");
        defaultLiveness = newLiveness;
    }

    /// @notice Emergency function to withdraw stuck tokens
    /// @param token Token to withdraw
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        IERC20(token).transfer(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Distribute bonds after settlement
    /// @param requestId The request ID
    /// @param request The request struct
    /// @param wasDisputed Whether the request was disputed
    function _distributeBonds(bytes32 requestId, Request storage request, bool wasDisputed) internal {
        if (wasDisputed) {
            // For disputed requests, bonds go to admin (owner)
            bondToken.transfer(owner(), bondToken.balanceOf(address(this)));
        } else {
            // For undisputed requests, bond goes to proposer
            bondToken.transfer(request.proposer, request.bond);
        }
    }

    /// @notice Decode price array into CTF payouts
    /// @param price The price array from the oracle
    /// @param outcomeSlotCount Number of outcome slots in CTF
    /// @return payouts Array of payout numerators
    function _decodePayouts(int256[] memory price, uint256 outcomeSlotCount)
        internal
        pure
        returns (uint256[] memory payouts)
    {
        payouts = new uint256[](outcomeSlotCount);

        if (price.length == 1) {
            // Binary market
            require(outcomeSlotCount == 2, "Binary market requires 2 outcomes");
            
            if (price[0] == 1e18) {
                // Yes outcome wins
                payouts[0] = 1;
                payouts[1] = 0;
            } else if (price[0] == 0) {
                // No outcome wins
                payouts[0] = 0;
                payouts[1] = 1;
            } else if (price[0] == 0.5e18) {
                // Invalid market (split)
                payouts[0] = 1;
                payouts[1] = 1;
            }
        } else {
            // Multi-outcome market (sports)
            payouts = price.decodeMultiOutcomePayouts(outcomeSlotCount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get request details
    /// @param requestId The request ID
    /// @return Request struct
    function getRequest(bytes32 requestId) external view returns (Request memory) {
        return requests[requestId];
    }

    /// @notice Check if address is whitelisted proposer
    /// @param proposer Address to check
    /// @return True if whitelisted
    function isWhitelistedProposer(address proposer) external view returns (bool) {
        return whitelistedProposers[proposer];
    }

    /// @notice Get total bond balance
    /// @return Total USDT balance in contract
    function getBondBalance() external view returns (uint256) {
        return bondToken.balanceOf(address(this));
    }
}
