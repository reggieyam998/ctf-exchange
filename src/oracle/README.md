# Fox Minimal Oracle

A lightweight, standalone oracle solution for fast resolutions of prediction markets on the Base chain. Designed to provide <10-minute resolutions for 99% of markets with minimal gas costs and full control.

## Features

### Core Functionality
- **Binary Markets**: Support for Yes/No outcomes (e.g., "Will Event X happen?")
- **Sports Markets**: Multi-outcome support for winner, spread, and total markets
- **Whitelisted Proposers**: Controlled access for trusted proposers (team + AI bots)
- **Dispute Mechanism**: Bond-based dispute system with admin resolution
- **CTF Integration**: Seamless integration with Conditional Tokens Framework
- **Gas Optimization**: <100K gas per request for cost efficiency

### Market Types Supported

#### Binary Markets (General)
- **Outcomes**: Yes (1), No (0), Invalid (0.5)
- **Example**: "Will Bitcoin reach $100K by end of 2024?"
- **Price Format**: `[1e18]` for Yes, `[0]` for No, `[0.5e18]` for Invalid

#### Sports Markets (Multi-outcome)
- **Winner Markets**: Home Win, Away Win, Tie
- **Spread Markets**: Home covers, Away covers, Push
- **Total Markets**: Over, Under, Push
- **Price Format**: `[homeScore, awayScore, spreadLine?, totalLine?, canceledFlag]`

## Contract Architecture

### Main Contract: `FoxMinimalOracle.sol`
- Core oracle logic for requests, proposals, disputes, and settlements
- Integration with CTF for automatic payouts
- Admin functions for whitelist management

### Library: `PayoutDecoderLib.sol`
- Decodes multi-outcome sports data into CTF payouts
- Handles winner, spread, and total market calculations
- Supports up to 7 outcomes per market

### Interface: `IFoxMinimalOracle.sol`
- Complete interface for easy integration
- Event definitions for monitoring
- Struct definitions for data handling

## Usage

### 1. Request a Price Resolution

```solidity
// Request a binary market
bytes32 requestId = keccak256("bitcoin-100k-2024");
bytes memory ancillaryData = "Bitcoin price prediction: Will BTC reach $100K by end of 2024?";
uint256 bond = 20 * 10**6; // $20 USDT
uint256 liveness = 300; // 5 minutes

oracle.requestPrice(requestId, ancillaryData, bond, liveness);
```

### 2. Propose a Price

```solidity
// Binary market proposal
int256[] memory price = new int256[](1);
price[0] = 1e18; // Yes outcome
oracle.proposePrice(requestId, price);

// Sports market proposal
int256[] memory sportsPrice = new int256[](2);
sportsPrice[0] = 105; // Home score
sportsPrice[1] = 98;  // Away score
oracle.proposePrice(requestId, sportsPrice);
```

### 3. Dispute a Price (Optional)

```solidity
uint256 disputeBond = 15 * 10**6; // $15 USDT
oracle.disputePrice(requestId, disputeBond);
```

### 4. Settle the Request

```solidity
// Auto-settle undisputed requests after liveness period
oracle.settleRequest(requestId, new int256[](0));

// Manual settle disputed requests (owner only)
int256[] memory finalPrice = new int256[](1);
finalPrice[0] = 0; // No outcome
oracle.settleRequest(requestId, finalPrice);
```

### 5. Report to CTF

```solidity
bytes32 questionId = keccak256("bitcoin-question");
uint256 outcomeSlotCount = 2; // Binary market
oracle.reportPayoutsToCTF(requestId, questionId, outcomeSlotCount);
```

## Deployment

### Prerequisites
- Foundry installed
- Private key with Base ETH for deployment
- USDT token address on Base
- CTF contract address on Base

### Deploy to Base Mainnet

```bash
# Set environment variables
export PRIVATE_KEY=your_private_key
export RPC_URL=https://mainnet.base.org

# Deploy
forge script scripts/12_deploy_oracle.s.sol:DeployOracle --rpc-url $RPC_URL --broadcast --verify
```

### Deploy to Base Sepolia (Testing)

```bash
# Set environment variables
export PRIVATE_KEY=your_private_key
export RPC_URL=https://sepolia.base.org

# Deploy
forge script scripts/12_deploy_oracle.s.sol:DeployOracle --rpc-url $RPC_URL --broadcast --verify
```

## Testing

### Run All Tests

```bash
forge test --match-contract FoxMinimalOracleTest -vv
```

### Run Specific Test Categories

```bash
# Basic functionality tests
forge test --match-test test_Constructor -vv

# Proposal tests
forge test --match-test test_ProposePrice -vv

# Dispute tests
forge test --match-test test_DisputePrice -vv

# Settlement tests
forge test --match-test test_SettleRequest -vv

# CTF integration tests
forge test --match-test test_ReportPayoutsToCTF -vv
```

## Configuration

### Default Parameters
- **Minimum Bond**: 10 USDT ($10)
- **Default Liveness**: 300 seconds (5 minutes)
- **Maximum Outcomes**: 7 per market
- **Liveness Range**: 300-600 seconds

### Admin Functions

```solidity
// Add proposer to whitelist
oracle.addProposer(address);

// Remove proposer from whitelist
oracle.removeProposer(address);

// Update minimum bond
oracle.setMinBond(uint256);

// Update default liveness
oracle.setDefaultLiveness(uint256);

// Emergency token withdrawal
oracle.emergencyWithdraw(address, address, uint256);
```

## Integration with CTF Exchange

The oracle integrates seamlessly with the existing CTF Exchange:

1. **Market Creation**: CTF prepares conditions and requests oracle resolution
2. **Price Proposals**: Whitelisted proposers submit outcomes
3. **Settlement**: Oracle automatically reports payouts to CTF
4. **Token Redemption**: Users redeem CTF tokens based on oracle outcomes

### Example Integration Flow

```solidity
// 1. CTF prepares condition
ctf.prepareCondition(oracleAddress, questionId, outcomeSlotCount);

// 2. Oracle resolves market
oracle.requestPrice(requestId, ancillaryData, bond, liveness);
oracle.proposePrice(requestId, price);
oracle.settleRequest(requestId, finalPrice);

// 3. Report payouts to CTF
oracle.reportPayoutsToCTF(requestId, questionId, outcomeSlotCount);

// 4. Users redeem tokens
ctf.redeemPositions(collateralToken, parentCollectionId, conditionId, indexSets);
```

## Security Considerations

### Access Control
- Owner-only admin functions
- Whitelisted proposer system
- Bond requirements for disputes

### Economic Security
- Minimum bond requirements deter spam
- Dispute bonds ensure serious challenges
- Bond slashing for bad actors

### Technical Security
- ReentrancyGuard protection
- Input validation for all parameters
- Safe math operations (Solidity 0.8+)

## Gas Optimization

### Optimizations Implemented
- Immutable variables for contract addresses
- Efficient data structures
- Minimal storage operations
- Optimized payout decoding

### Gas Costs (Estimated)
- **Request Price**: ~80K gas
- **Propose Price**: ~60K gas
- **Dispute Price**: ~50K gas
- **Settle Request**: ~40K gas
- **Report to CTF**: ~30K gas

## Monitoring and Events

### Key Events
- `PriceRequested`: New price request created
- `PriceProposed`: Price proposed by whitelisted proposer
- `PriceDisputed`: Price disputed by user
- `PriceSettled`: Request settled with final price
- `ProposerWhitelisted`: Proposer added/removed from whitelist

### Off-chain Monitoring
- Monitor events for automated responses
- Track dispute rates and resolution times
- Alert on unusual activity patterns

## Future Enhancements

### Phase 2: AI Integration
- Automated price proposals via AI bots
- Multi-source data aggregation
- Confidence scoring for proposals

### Phase 3: DAO Governance
- Community voting for disputed resolutions
- Decentralized proposer whitelist management
- Token-based governance system

## Support

For questions, issues, or contributions:
- Check the test files for usage examples
- Review the interface for complete API documentation
- Run tests to verify functionality
- Monitor events for integration debugging
