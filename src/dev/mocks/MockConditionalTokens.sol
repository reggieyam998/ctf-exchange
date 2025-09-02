// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @title Mock Conditional Tokens
/// @notice Mock ConditionalTokens contract for testing purposes
/// @author Fox Market
contract MockConditionalTokens {
    mapping(bytes32 => mapping(uint256 => uint256)) public payoutNumerators;
    mapping(bytes32 => uint256) public payoutDenominators;
    mapping(bytes32 => uint256) public outcomeSlotCounts;

    event PayoutsReported(bytes32 indexed questionId, uint256[] payouts);

    function prepareCondition(address oracle, bytes32 questionId, uint256 outcomeSlotCount) external {
        outcomeSlotCounts[questionId] = outcomeSlotCount;
    }

    function reportPayouts(bytes32 questionId, uint256[] calldata payouts) external {
        uint256 total = 0;
        for (uint256 i = 0; i < payouts.length; i++) {
            payoutNumerators[questionId][i] = payouts[i];
            total += payouts[i];
        }
        payoutDenominators[questionId] = total;
        
        emit PayoutsReported(questionId, payouts);
    }

    function getOutcomeSlotCount(bytes32 conditionId) external view returns (uint256) {
        return outcomeSlotCounts[conditionId];
    }

    function getConditionId(address oracle, bytes32 questionId, uint256 outcomeSlotCount)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(oracle, questionId, outcomeSlotCount));
    }

    function getCollectionId(bytes32 parentCollectionId, bytes32 conditionId, uint256 indexSet)
        external
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(parentCollectionId, conditionId, indexSet));
    }

    function getPositionId(IERC20 collateralToken, bytes32 collectionId) external pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(collateralToken, collectionId)));
    }

    function splitPosition(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external {
        // Mock implementation - just emit event
    }

    function mergePositions(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external {
        // Mock implementation - just emit event
    }

    function redeemPositions(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata indexSets
    ) external {
        // Mock implementation - just emit event
    }
}
