# Market Creation Scripts

This directory contains scripts for creating prediction markets using the CTF-exchange smart contracts.

## Scripts Overview

### `05_create_prediction_market.s.sol`
Basic market creation script with predefined examples:
- Bitcoin price prediction market
- US Presidential Election market

### `06_market_helpers.s.sol`
Advanced helper script with utility functions:
- Custom binary market creation
- Multi-outcome market creation
- Market information retrieval
- Pre-built market templates

## Environment Setup

Before running the scripts, set up your environment variables:

```bash
# Core contract addresses
export CTF_ADDRESS="0x..."
export EXCHANGE_ADDRESS="0x..."
export USDC_ADDRESS="0x..."

# Oracle addresses for different market types
export BITCOIN_ORACLE_ADDRESS="0x..."
export ELECTION_ORACLE_ADDRESS="0x..."
export SPORTS_ORACLE_ADDRESS="0x..."
export WEATHER_ORACLE_ADDRESS="0x..."
export POLITICAL_ORACLE_ADDRESS="0x..."
export CRYPTO_ORACLE_ADDRESS="0x..."
export ENTERTAINMENT_ORACLE_ADDRESS="0x..."
```

## Usage Examples

### 1. Basic Market Creation

```bash
# Run the basic market creation script
forge script scripts/05_create_prediction_market.s.sol --rpc-url $RPC_URL --broadcast
```

This will create:
- Bitcoin price prediction market
- US Presidential Election market

### 2. Using Helper Functions

```bash
# Run the helper script
forge script scripts/06_market_helpers.s.sol --rpc-url $RPC_URL --broadcast
```

### 3. Creating Custom Markets

You can call specific functions from the helper script:

```bash
# Create a custom binary market
forge script scripts/06_market_helpers.s.sol:MarketHelpers --sig "createBinaryMarket(string,address)" \
  --rpc-url $RPC_URL --broadcast \
  -- "Will Tesla stock reach $300 by end of 2024?" $ORACLE_ADDRESS

# Create a multi-outcome market
forge script scripts/06_market_helpers.s.sol:MarketHelpers --sig "createMultiOutcomeMarket(string,address,uint256)" \
  --rpc-url $RPC_URL --broadcast \
  -- "Which team will win the World Cup 2026?" $ORACLE_ADDRESS 8
```

### 4. Pre-built Market Templates

The helper script includes several pre-built market templates:

```bash
# Sports betting market
forge script scripts/06_market_helpers.s.sol:MarketHelpers --sig "createSportsMarket()" \
  --rpc-url $RPC_URL --broadcast

# Weather prediction market
forge script scripts/06_market_helpers.s.sol:MarketHelpers --sig "createWeatherMarket()" \
  --rpc-url $RPC_URL --broadcast

# Political market
forge script scripts/06_market_helpers.s.sol:MarketHelpers --sig "createPoliticalMarket()" \
  --rpc-url $RPC_URL --broadcast

# Crypto market
forge script scripts/06_market_helpers.s.sol:MarketHelpers --sig "createCryptoMarket()" \
  --rpc-url $RPC_URL --broadcast

# Entertainment market
forge script scripts/06_market_helpers.s.sol:MarketHelpers --sig "createEntertainmentMarket()" \
  --rpc-url $RPC_URL --broadcast
```

## Market Creation Process

### Step 1: Prepare Condition
```solidity
// Anyone can prepare a condition
ctf.prepareCondition(oracle, questionId, outcomeSlotCount);
```

### Step 2: Generate Position IDs
```solidity
// For binary markets
bytes32 yesCollectionId = ctf.getCollectionId(bytes32(0), conditionId, 2);
bytes32 noCollectionId = ctf.getCollectionId(bytes32(0), conditionId, 1);

uint256 yesPositionId = ctf.getPositionId(usdc, yesCollectionId);
uint256 noPositionId = ctf.getPositionId(usdc, noCollectionId);
```

### Step 3: Register for Trading
```solidity
// Only admin can register tokens
exchange.registerToken(yesPositionId, noPositionId, conditionId);
```

## Real-World Examples

### Example 1: Bitcoin Price Prediction
```solidity
Question: "Will Bitcoin reach $100,000 by December 31, 2024?"
Oracle: Chainlink Price Oracle
Outcomes: YES/NO
```

### Example 2: US Presidential Election
```solidity
Question: "Who will win the 2024 US Presidential Election?"
Oracle: UMA Optimistic Oracle
Outcomes: Candidate A, Candidate B, Candidate C, Candidate D
```

### Example 3: Sports Betting
```solidity
Question: "Will the Lakers win the NBA Championship 2024?"
Oracle: Sports Data Oracle
Outcomes: YES/NO
```

## Market Information

### Get Market Status
```bash
# Check if market is resolved
forge script scripts/06_market_helpers.s.sol:MarketHelpers --sig "getMarketInfo(bytes32)" \
  --rpc-url $RPC_URL \
  -- $CONDITION_ID
```

### Simulate Oracle Resolution
```bash
# Simulate oracle reporting results (for testing)
forge script scripts/06_market_helpers.s.sol:MarketHelpers --sig "simulateOracleResolution(bytes32,uint256[])" \
  --rpc-url $RPC_URL --broadcast \
  -- $QUESTION_ID "[100,0]"  # YES wins, NO loses
```

## Role Requirements

### Market Creation Roles:
- **Anyone** can prepare conditions
- **Only Admin** can register tokens for trading
- **Only Oracle** can resolve markets

### Required Permissions:
```solidity
// Admin role required for token registration
modifier onlyAdmin() {
    if (admins[msg.sender] != 1) revert NotAdmin();
    _;
}

// Oracle role required for market resolution
function reportPayouts(bytes32 questionId, uint256[] calldata payouts) external;
```

## Best Practices

### 1. Question Clarity
- Make questions unambiguous
- Include specific criteria for resolution
- Set clear deadlines

### 2. Oracle Selection
- Choose reliable oracles (Chainlink, UMA, etc.)
- Ensure oracle has access to required data
- Consider oracle costs and timing

### 3. Market Design
- Start with binary markets for simplicity
- Use multi-outcome markets for complex scenarios
- Consider liquidity requirements

### 4. Testing
- Test on local networks first
- Verify oracle integration
- Test market resolution scenarios

## Troubleshooting

### Common Issues:

1. **"CTF not deployed"**
   - Ensure CTF_ADDRESS is set correctly
   - Verify ConditionalTokens contract is deployed

2. **"Exchange not deployed"**
   - Ensure EXCHANGE_ADDRESS is set correctly
   - Verify CTFExchange contract is deployed

3. **"NotAdmin" error**
   - Ensure caller has admin role
   - Check if admin was set during deployment

4. **"Oracle not found"**
   - Ensure oracle address is set in environment
   - Verify oracle contract is deployed and accessible

### Debug Commands:
```bash
# Check contract addresses
forge script scripts/06_market_helpers.s.sol:MarketHelpers --sig "_loadEnvironment()" \
  --rpc-url $RPC_URL

# Verify admin role
forge script scripts/06_market_helpers.s.sol:MarketHelpers --sig "exchange.isAdmin(address)" \
  --rpc-url $RPC_URL -- $ADMIN_ADDRESS
```

## Next Steps

After creating markets:

1. **Monitor Trading**: Watch for trading activity
2. **Manage Liquidity**: Ensure sufficient trading volume
3. **Oracle Resolution**: Wait for oracle to report results
4. **Token Redemption**: Users can redeem winning tokens

For more information, see the main project documentation in `docs/`. 