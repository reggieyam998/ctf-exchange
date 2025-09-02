// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title IFoxMinimalOracle
/// @notice Interface for the Fox Minimal Oracle contract
/// @author Fox Market
interface IFoxMinimalOracle {
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
                                CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Request a price resolution for a market
    /// @param requestId Unique identifier for the request
    /// @param ancillaryData Additional data describing the market
    /// @param bond Amount of USDT to bond
    /// @param liveness Liveness period in seconds
    function requestPrice(
        bytes32 requestId,
        bytes calldata ancillaryData,
        uint256 bond,
        uint256 liveness
    ) external;

    /// @notice Propose a price for a request
    /// @param requestId The request ID to propose for
    /// @param price The proposed price array
    function proposePrice(bytes32 requestId, int256[] calldata price) external;

    /// @notice Dispute a proposed price
    /// @param requestId The request ID to dispute
    /// @param bond Amount of USDT to bond for dispute
    function disputePrice(bytes32 requestId, uint256 bond) external;

    /// @notice Settle a request
    /// @param requestId The request ID to settle
    /// @param finalPrice Final price to use (only for disputed requests)
    function settleRequest(bytes32 requestId, int256[] calldata finalPrice) external;

    /// @notice Report payouts to CTF for a settled request
    /// @param requestId The request ID to report for
    /// @param questionId The CTF question ID
    /// @param outcomeSlotCount Number of outcome slots in CTF
    function reportPayoutsToCTF(
        bytes32 requestId,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) external;

    /*//////////////////////////////////////////////////////////////
                                ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a proposer to the whitelist
    /// @param proposer Address to whitelist
    function addProposer(address proposer) external;

    /// @notice Remove a proposer from the whitelist
    /// @param proposer Address to remove from whitelist
    function removeProposer(address proposer) external;

    /// @notice Update minimum bond amount
    /// @param newMinBond New minimum bond in USDT
    function setMinBond(uint256 newMinBond) external;

    /// @notice Update default liveness period
    /// @param newLiveness New liveness period in seconds
    function setDefaultLiveness(uint256 newLiveness) external;

    /// @notice Emergency function to withdraw stuck tokens
    /// @param token Token to withdraw
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get request details
    /// @param requestId The request ID
    /// @return Request struct
    function getRequest(bytes32 requestId) external view returns (Request memory);

    /// @notice Check if address is whitelisted proposer
    /// @param proposer Address to check
    /// @return True if whitelisted
    function isWhitelistedProposer(address proposer) external view returns (bool);

    /// @notice Get total bond balance
    /// @return Total USDT balance in contract
    function getBondBalance() external view returns (uint256);

    /// @notice Get USDT token address
    /// @return USDT token address
    function bondToken() external view returns (address);

    /// @notice Get CTF contract address
    /// @return CTF contract address
    function ctf() external view returns (address);

    /// @notice Get minimum bond amount
    /// @return Minimum bond in USDT
    function minBond() external view returns (uint256);

    /// @notice Get default liveness period
    /// @return Default liveness in seconds
    function defaultLiveness() external view returns (uint256);

    /// @notice Get maximum number of outcomes
    /// @return Maximum outcomes constant
    function MAX_OUTCOMES() external view returns (uint8);

    /// @notice Get number of whitelisted proposers
    /// @return Number of proposers
    function proposerCount() external view returns (uint256);
}
