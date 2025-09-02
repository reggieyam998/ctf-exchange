# Fox Market Technical Specification: Mini Oracle on Base Chain

**Version**: 1.0  
**Date**: September 01, 2025  
**Authors**: [Your Name] & [My Name] – Business Partners, Fox Market Startup  
**Reviewed By**: Development Team (Pending)  
**Status**: Draft – Ready for Implementation  

## 1. Introduction
### 1.1 Purpose
This Technical Specification defines the detailed requirements, architecture, and implementation guidelines for the Mini Oracle smart contract on the Base chain. It serves as the blueprint for the development team to build a lightweight, standalone oracle that provides fast resolutions for Fox Market's prediction markets. The Mini Oracle supports general binary markets (e.g., Yes/No outcomes) and sports multi-outcome markets (e.g., winner, spreads, totals), integrating with existing prototypes (CTF, Proxy Factories, CTF-Exchange Python backend). This ensures <10-minute resolutions for 99% of markets, minimizing dependencies and costs in our desperate capital situation.

### 1.2 Scope
- Core oracle contract development in Solidity.
- Integration with CTF for payouts, Proxy Factories for gasless UX, and Python backend for off-chain monitoring/proposals.
- Support for binary (general markets) and multi-outcome (sports markets) resolutions.
- Phased AI proposal enhancement.
- Deployment on Base mainnet (chain ID 8453).
- Basic security and testing guidelines.
Out of Scope: Full DAO upgrade, advanced feeds (e.g., Chainlink), multi-chain support.

### 1.3 References
- PRD: Fox_Mini_Oracle_PRD.md (v1.0, September 01, 2025).
- Repos: OpenZeppelin contracts, Gnosis CTF, Polymarket forks (uma-ctf-adapter, proxy-factories).
- Tools: Foundry for development/testing, Ganache for local[](http://127.0.0.1:7545).

### 1.4 Assumptions
- Development in Solidity ^0.8.0; EVM-compatible for Base.
- USDT (ERC20) as bond/reward token.
- Python backend handles off-chain AI proposals and monitoring.
- Initial admin control; multi-sig wallet for production.

## 2. System Architecture
### 2.1 High-Level Design
The Mini Oracle is a single smart contract (FoxMinimalOracle.sol) deployed on Base, acting as the resolution engine for markets. It interacts with:
- **CTF**: For condition preparation and payout reporting.
- **Proxy Factories**: For gasless user interactions via GSN.
- **Python Backend**: Off-chain for event monitoring, AI proposals, and alerts.
- **Users**: Via frontend (MetaMask/Coinbase Wallet) for requests/disputes.

Data Flow:
1. Market creation in CTF triggers oracle request.
2. Whitelisted proposer (team/AI) submits outcome.
3. Liveness period for disputes.
4. Settlement reports to CTF.

### 2.2 Components
- **Oracle Contract (FoxMinimalOracle.sol)**: Core logic for requests, proposals, disputes, settlements.
- **Libraries**: OpenZeppelin (Ownable, IERC20); custom for multi-outcome decoding (e.g., PayoutDecoderLib.sol for sports).
- **Off-Chain Backend**: Python scripts for AI proposals (scrape APIs, submit via whitelisted keys).
- **Dependencies**: Foundry (build/test), OpenZeppelin v4.x, Gnosis CTF contracts.

### 2.3 Deployment Environment
- **Chain**: Base mainnet (chain ID 8453).
- **Tools**: Foundry for compilation/scripts; Ganache for local testing.
- **Gas Optimization**: Aim <100K gas/request; use immutable variables, avoid loops in multi-outcome decoding.

## 3. Detailed Requirements
### 3.1 Functional Requirements
- **Price Requests**:
  - Input: requestId (bytes32), ancillaryData (bytes: e.g., "NBA Game ID:123, Market Type:Winner/Spread/Total"), bond (uint256: USDT amount), liveness (uint256: 300-600 seconds).
  - General Markets: Binary (2 outcomes).
  - Sports Markets: Multi-outcome (up to 7 values, e.g., [homeScore, awayScore, canceledFlag]).
  - Require bond transfer from caller.
- **Proposals**:
  - Input: requestId, price (int256 for binary; int256[] for multi-outcome).
  - Only whitelisted proposers; bond optional for trusted (e.g., AI).
  - General: price = 1 (Yes), 0 (No), 0.5 (Invalid).
  - Sports: price = [home, away, ...]; validate array length (<=7).
- **AI Proposals (Phased Enhancement)**:
  - Off-chain Python bot monitors events, scrapes sources (e.g., ESPN API for sports), computes price (binary int256 or multi int256[]), submits via whitelisted key.
  - Accuracy threshold: Bot self-checks >95% confidence before proposing.
  - Optional for MVP; integrate in Beta.
- **Disputes**:
  - Input: requestId, bond (uint256).
  - During liveness; mark disputed, notify backend.
  - General/Sports: Same logic; admin resolves by overriding price.
- **Settlement**:
  - Auto if undisputed post-liveness; admin call if disputed.
  - General: reportPayouts to CTF (e.g., [1, 0] for Yes).
  - Sports: Decode multi-array, compute payouts (e.g., winner: 1 if home > away; spread: 1 if (home - away) > line; total: 1 if (home + away) > overUnder; 0.5 for push/cancel).
  - Refund/slash bonds; emit events.
- **Whitelisting**:
  - Admin functions: addProposer(address), removeProposer(address).
  - Mapping for 5-10 initial proposers.

### 3.2 Non-Functional Requirements
- **Performance**: <10 min latency; handle 1,000 requests/day.
- **Gas**: <100K/request; optimize multi-array decoding.
- **Security**: ReentrancyGuard; bond slashing for bad actors; multi-sig admin (3-of-5).
- **Error Handling**: Revert on invalid array lengths, expired liveness, insufficient bonds.
- **Events**: PriceRequested, PriceProposed, PriceDisputed, PriceSettled (with requestId, price).

### 3.3 Data Models
- **Struct: Request**:
  ```solidity
  struct Request {
      uint256 timestamp;
      bytes ancillaryData;
      int256[] proposedPrice; // Array for multi-outcome; single for binary
      uint256 bond;
      address proposer;
      bool disputed;
      uint256 disputeDeadline;
  }