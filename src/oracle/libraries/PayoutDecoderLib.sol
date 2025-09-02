// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title Payout Decoder Library
/// @notice Library for decoding multi-outcome sports market data into CTF payouts
/// @dev Handles winner, spread, and total markets for sports betting
/// @author Fox Market
library PayoutDecoderLib {
    // Precision for decimal calculations (18 decimals)
    uint256 private constant PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct SportsMarketData {
        int256 homeScore;
        int256 awayScore;
        int256 spreadLine;      // Spread line (e.g., +5.5 points)
        int256 totalLine;       // Total over/under line
        bool isCanceled;
        MarketType marketType;
    }

    enum MarketType {
        WINNER,     // 0: Home Win, 1: Away Win, 2: Tie
        SPREAD,     // 0: Home covers, 1: Away covers, 2: Push
        TOTAL       // 0: Over, 1: Under, 2: Push
    }

    /*//////////////////////////////////////////////////////////////
                                MAIN FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Decode multi-outcome price array into CTF payouts
    /// @param price The price array from oracle [homeScore, awayScore, spreadLine?, totalLine?, canceledFlag]
    /// @param outcomeSlotCount Number of outcome slots in CTF
    /// @return payouts Array of payout numerators
    function decodeMultiOutcomePayouts(int256[] memory price, uint256 outcomeSlotCount)
        internal
        pure
        returns (uint256[] memory payouts)
    {
        require(price.length >= 2, "Invalid price array length");
        require(outcomeSlotCount >= 2 && outcomeSlotCount <= 7, "Invalid outcome count");

        payouts = new uint256[](outcomeSlotCount);

        // Parse sports market data from price array
        SportsMarketData memory data = _parseSportsData(price);

        if (data.isCanceled) {
            // Canceled market - split payouts equally
            for (uint256 i = 0; i < outcomeSlotCount; i++) {
                payouts[i] = 1;
            }
            return payouts;
        }

        // Determine market type based on outcome count and available data
        MarketType marketType = _determineMarketType(outcomeSlotCount, price.length);

        if (marketType == MarketType.WINNER) {
            payouts = _decodeWinnerMarket(data, outcomeSlotCount);
        } else if (marketType == MarketType.SPREAD) {
            payouts = _decodeSpreadMarket(data, outcomeSlotCount);
        } else if (marketType == MarketType.TOTAL) {
            payouts = _decodeTotalMarket(data, outcomeSlotCount);
        } else {
            // Fallback: use first two outcomes as binary
            payouts[0] = data.homeScore > data.awayScore ? 1 : 0;
            payouts[1] = data.homeScore < data.awayScore ? 1 : 0;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                DECODING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decode winner market (Home Win, Away Win, Tie)
    /// @param data Sports market data
    /// @param outcomeSlotCount Number of outcomes
    /// @return payouts Winner market payouts
    function _decodeWinnerMarket(SportsMarketData memory data, uint256 outcomeSlotCount)
        internal
        pure
        returns (uint256[] memory payouts)
    {
        payouts = new uint256[](outcomeSlotCount);

        if (data.homeScore > data.awayScore) {
            // Home team wins
            if (outcomeSlotCount >= 1) payouts[0] = 1; // Home Win
            if (outcomeSlotCount >= 2) payouts[1] = 0; // Away Win
            if (outcomeSlotCount >= 3) payouts[2] = 0; // Tie
        } else if (data.homeScore < data.awayScore) {
            // Away team wins
            if (outcomeSlotCount >= 1) payouts[0] = 0; // Home Win
            if (outcomeSlotCount >= 2) payouts[1] = 1; // Away Win
            if (outcomeSlotCount >= 3) payouts[2] = 0; // Tie
        } else {
            // Tie
            if (outcomeSlotCount >= 1) payouts[0] = 0; // Home Win
            if (outcomeSlotCount >= 2) payouts[1] = 0; // Away Win
            if (outcomeSlotCount >= 3) payouts[2] = 1; // Tie
        }
    }

    /// @notice Decode spread market (Home covers, Away covers, Push)
    /// @param data Sports market data
    /// @param outcomeSlotCount Number of outcomes
    /// @return payouts Spread market payouts
    function _decodeSpreadMarket(SportsMarketData memory data, uint256 outcomeSlotCount)
        internal
        pure
        returns (uint256[] memory payouts)
    {
        payouts = new uint256[](outcomeSlotCount);

        int256 margin = data.homeScore - data.awayScore;
        int256 adjustedMargin = margin - data.spreadLine;

        if (adjustedMargin > 0) {
            // Home team covers the spread
            if (outcomeSlotCount >= 1) payouts[0] = 1; // Home covers
            if (outcomeSlotCount >= 2) payouts[1] = 0; // Away covers
            if (outcomeSlotCount >= 3) payouts[2] = 0; // Push
        } else if (adjustedMargin < 0) {
            // Away team covers the spread
            if (outcomeSlotCount >= 1) payouts[0] = 0; // Home covers
            if (outcomeSlotCount >= 2) payouts[1] = 1; // Away covers
            if (outcomeSlotCount >= 3) payouts[2] = 0; // Push
        } else {
            // Push (exact spread)
            if (outcomeSlotCount >= 1) payouts[0] = 0; // Home covers
            if (outcomeSlotCount >= 2) payouts[1] = 0; // Away covers
            if (outcomeSlotCount >= 3) payouts[2] = 1; // Push
        }
    }

    /// @notice Decode total market (Over, Under, Push)
    /// @param data Sports market data
    /// @param outcomeSlotCount Number of outcomes
    /// @return payouts Total market payouts
    function _decodeTotalMarket(SportsMarketData memory data, uint256 outcomeSlotCount)
        internal
        pure
        returns (uint256[] memory payouts)
    {
        payouts = new uint256[](outcomeSlotCount);

        int256 totalScore = data.homeScore + data.awayScore;
        int256 difference = totalScore - data.totalLine;

        if (difference > 0) {
            // Over
            if (outcomeSlotCount >= 1) payouts[0] = 1; // Over
            if (outcomeSlotCount >= 2) payouts[1] = 0; // Under
            if (outcomeSlotCount >= 3) payouts[2] = 0; // Push
        } else if (difference < 0) {
            // Under
            if (outcomeSlotCount >= 1) payouts[0] = 0; // Over
            if (outcomeSlotCount >= 2) payouts[1] = 1; // Under
            if (outcomeSlotCount >= 3) payouts[2] = 0; // Push
        } else {
            // Push (exact total)
            if (outcomeSlotCount >= 1) payouts[0] = 0; // Over
            if (outcomeSlotCount >= 2) payouts[1] = 0; // Under
            if (outcomeSlotCount >= 3) payouts[2] = 1; // Push
        }
    }

    /*//////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Parse sports market data from price array
    /// @param price The price array from oracle
    /// @return data Parsed sports market data
    function _parseSportsData(int256[] memory price)
        internal
        pure
        returns (SportsMarketData memory data)
    {
        require(price.length >= 2, "Invalid price array length");

        data.homeScore = price[0];
        data.awayScore = price[1];

        // Parse additional data if available
        if (price.length >= 3) {
            data.spreadLine = price[2];
        }
        if (price.length >= 4) {
            data.totalLine = price[3];
        }
        if (price.length >= 5) {
            data.isCanceled = price[4] != 0;
        }
    }

    /// @notice Determine market type based on outcome count and price array length
    /// @param outcomeSlotCount Number of outcome slots
    /// @param priceArrayLength Length of price array
    /// @return marketType Determined market type
    function _determineMarketType(uint256 outcomeSlotCount, uint256 priceArrayLength)
        internal
        pure
        returns (MarketType marketType)
    {
        if (outcomeSlotCount == 2) {
            return MarketType.WINNER; // Binary winner market
        } else if (outcomeSlotCount == 3) {
            if (priceArrayLength >= 4) {
                return MarketType.TOTAL; // Total market with over/under/push
            } else if (priceArrayLength >= 3) {
                return MarketType.SPREAD; // Spread market with home/away/push
            } else {
                return MarketType.WINNER; // Winner market with tie
            }
        } else if (outcomeSlotCount >= 4) {
            if (priceArrayLength >= 3) {
                return MarketType.SPREAD; // Spread market
            } else {
                return MarketType.WINNER; // Multi-winner market
            }
        } else {
            return MarketType.WINNER; // Default to winner
        }
    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Convert decimal value to precision (18 decimals)
    /// @param value Value to convert
    /// @return Converted value with precision
    function toPrecision(int256 value) internal pure returns (int256) {
        return value * int256(PRECISION);
    }

    /// @notice Convert precision value back to decimal
    /// @param value Value with precision
    /// @return Converted decimal value
    function fromPrecision(int256 value) internal pure returns (int256) {
        return value / int256(PRECISION);
    }

    /// @notice Check if two values are equal within precision tolerance
    /// @param a First value
    /// @param b Second value
    /// @return True if values are equal
    function equals(int256 a, int256 b) internal pure returns (bool) {
        return a == b;
    }

    /// @notice Get the larger of two values
    /// @param a First value
    /// @param b Second value
    /// @return Larger value
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /// @notice Get the smaller of two values
    /// @param a First value
    /// @param b Second value
    /// @return Smaller value
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }
}
