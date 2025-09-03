// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title Mock Factory
/// @notice Simple mock factory for testing
contract MockFactory {
    function createProxy() external pure returns (address) {
        return address(0x123);
    }
}
