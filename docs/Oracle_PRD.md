# Fox Market Product Requirement Document (PRD): Mini Oracle on Base Chain

**Version**: 1.0  
**Date**: September 01, 2025  
**Authors**: Reg – Business Partners, Fox Market Startup  
**Status**: Approved

## 1. Overview
### 1.1 Product Description
The Mini Oracle is a lightweight, standalone oracle solution deployed on the Base chain, designed to provide fast, trustless resolutions for prediction markets in Fox Market. It replaces reliance on external oracles like UMA’s MOOV2, enabling us to manage resolutions internally with admin or whitelisted proposers. Built as a simple smart contract, it handles binary queries for general markets (e.g., "Will Event X happen? Yes/No") and multi-outcome queries for sports markets (e.g., winner, spreads like +5.5 points, totals over/under), with short liveness periods. It integrates seamlessly with our existing CTF (Conditional Tokens Framework), Proxy Factories, and CTF-Exchange backend.

This oracle prioritizes speed (<10 minutes for 99% of resolutions), low gas costs (~$0.02-0.04/tx on Base), and full control to minimize disputes and external dependencies. It’s our key differentiator: While Polymarket waits hours (or days for DVM), Fox delivers near-instant settlements to retain users and boost trading volume, especially in high-volume sports markets.

### 1.2 Problem Statement
Our prediction market needs rapid resolutions to compete—users hate delays in sports bets or events, leading to churn. External oracles like UMA introduce dependencies, potential centralization risks, and delays (2+ hours liveness, 48-72 hour DVM). With our capital desperate low, we can’t afford audits for complex systems or fees from third parties. The Mini Oracle solves this by being lightweight, fast, and self-managed, ensuring we control our destiny for both general binary markets and sports multi-outcome markets.

### 1.3 Target Users
- **Traders/Betters**: Crypto users (800K+ DAU on Base) placing micro-bets ($0.10+) on general events (binary) or sports (multi-outcome), seeking instant payouts.
- **Market Creators**: Admins or power users creating general markets (e.g., "Election winner?") or sports markets (e.g., "NBA game: Winner/Spread/Total"), needing reliable resolutions.
- **Internal Team**: Us, as proposers/disputers, managing the oracle to bootstrap liquidity.

### 1.4 Key Assumptions
- Base chain’s low fees and EVM compatibility support our ERC20 (USDT) bets and Proxy Factories for gasless UX.
- 99% of resolutions are undisputed with whitelisting; disputes are rare and handled by admin initially.
- Integration with CTF-Exchange backend (your Python prototype) for off-chain monitoring/proposals, handling both binary and multi-outcome data.

## 2. Goals and Objectives
### 2.1 Business Goals
- Achieve 99% resolutions under 10 minutes to increase user retention by 30-50% vs. Polymarket’s delays, with emphasis on sports multi-outcome markets for high-volume trading.
- Bootstrap $500K TVL by Q1 2026 through fast sports markets, targeting Base’s 800K+ DAU and Coinbase ecosystem.
- Generate revenue: 1% rake on trades ($100K/month goal) plus optional oracle fees (0.1% for proposals).
- Minimize costs: Deploy under $1 total gas; no external oracle fees or audits beyond basic review (~$5K).

### 2.2 Technical Objectives
- Deploy a standalone oracle contract on Base with <10 min average resolution time, supporting binary (general markets) and multi-outcome (sports markets).
- Integrate with CTF for automatic payouts and Proxy Factories for gasless user interactions.
- Support 1,000+ daily requests with low gas (~$0.02/tx) and high uptime (99.9%).

### 2.3 Success Metrics
- **Resolution Speed**: 95% <5 mins, 99% <10 mins (tracked via on-chain events).
- **Dispute Rate**: <1% of markets disputed (monitored via oracle logs).
- **User Growth**: 10K active users by Q1 2026, with 50% repeat bets due to fast settlements in sports multi-outcome markets.
- **Cost Efficiency**: Total oracle ops <0.5% of trading volume in gas fees.
- **Uptime**: 99.9% availability, measured by Base chain metrics.

## 3. Features and Functionality
### 3.1 Core Features
- **Price Requests**: Users/admins request resolutions for general markets (binary, e.g., "Will Event X happen?") or sports markets (multi-outcome, e.g., "NBA game: Home Win/Away Win/Tie, Spread +5.5, Total Over 200") with ancillary data (e.g., scores), bond (USDT, ~$10), and custom liveness (5-10 mins).
- **Proposals**: Whitelisted proposers (initially 5-10 addresses: team + AI bots) submit outcomes with bonds; supports binary prices (int256, e.g., 1 for Yes) or multi-values (int256[], e.g., [homeScore, awayScore] for sports).
- **AI Proposals (Enhancement)**: Integrate AI bots (off-chain Python backend) for automated proposals in general binary markets (e.g., int256: 1 for Yes) and sports multi-outcome (e.g., int256[]: [homeScore, awayScore, canceledFlag]). Bots scrape multiple sources (e.g., APIs), propose with whitelisted keys, and support accuracy thresholds (>95%). For multi-outcome, decode arrays to compute payouts (e.g., winner: 1 if home > away; spread: 1 if (home - away) > line; 0.5 for push/cancel). Optional for MVP; enables <5-min resolutions.
- **Dispute Mechanism**: Any user disputes with a bond during liveness; if disputed, admin resolves in ~5 mins (later upgrade to small DAO), handling binary or multi-outcome data.
- **Settlement**: Auto-reports outcomes to CTF for payouts; refunds bonds to winners, slashes losers. For sports, decodes multi-values to compute payouts (e.g., winner: 1 if home > away; spread: 1 if home - away > line; 0.5 for push/cancel).
- **Whitelisting**: Admin adds/removes proposers for spam control (e.g., accuracy >95%).
- **Events and Monitoring**: Emit events for proposals/disputes/settlements; integrate with Python backend for alerts.

### 3.2 Non-Functional Requirements
- **Performance**: Handle 1,000 requests/day; resolution latency <10 mins.
- **Security**: Bonds deter spam; admin multi-sig (3-of-5) for resolutions; OpenZeppelin libs for access control. Basic audit (~$5K) before launch.
- **Scalability**: Gas-optimized (<100K gas/request); deploy on Base for low costs.
- **Reliability**: 99.9% uptime; fallback to manual admin resolution if needed.
- **Usability**: Gasless via Proxy Factories; frontend integration for proposals (your Python backend handles off-chain logic).

### 3.3 Out of Scope
- Full decentralization (e.g., tokenholder voting)—start admin-controlled, upgrade to DAO later.
- Advanced data feeds (e.g., Chainlink integration)—stick to whitelisted proposals.
- Multi-chain support—focus on Base; Polygon as backup.

## 4. Technical Specifications
### 4.1 Architecture
- **Contract**: Single Solidity ^0.8.0 contract (FoxMinimalOracle.sol), ~200 lines, inheriting OpenZeppelin Ownable for admin.
- **Integration**:
  - CTF: Call `reportPayouts` for settlements.
  - Proxy Factories: Gasless proposals via GSN relayers.
  - Backend: Python script monitors events, auto-proposes via whitelisted keys.
- **Deployment**: Base mainnet (chain ID 8453); use Foundry for scripts.
- **Dependencies**: OpenZeppelin contracts, IERC20 (USDT), IConditionalTokens.

### 4.2 Data Flow
1. Market Creation: CTF prepares condition, requests oracle via Mini Oracle.
2. Proposal: Whitelisted bot submits price (e.g., 1 for binary win; [homeScore, awayScore] for sports).
3. Liveness: 5-10 mins for disputes.
4. Settlement: If undisputed, auto-payout; if disputed, admin resolves.
5. Payout: CTF reports, users redeem tokens.

### 4.3 Security Considerations
- **Bonds**: Require >$10 USDT to deter spam.
- **Admin Risks**: Multi-sig wallet; audit for reentrancy, overflow.
- **Upgrades**: Proxy pattern (inspired by our Proxy Factories) for future versions.
- **Audits**: Basic code review (~$5K); inherit OpenZeppelin audits.

## 5. User Experience
- **Frontend Flow**: Users create markets; oracle status shown in dashboard (e.g., "Resolving in 5 mins").
- **Mobile/Web**: Integrate with MetaMask/Coinbase Wallet for gasless txs.
- **Notifications**: Backend pushes alerts for disputes (e.g., via email/Push Protocol).
- **Edge Cases**: Disputed markets show "Admin Reviewing" with ETA <15 mins.

## 6. Risks and Mitigations
- **Risk: Admin Centralization**: Mitigate with transparent logs, community whitelist expansion.
- **Risk: Disputes Slowing UX**: Mitigate with short liveness, high bonds (~$100 for high-stakes).
- **Risk: Gas Spikes**: Mitigate with Base’s low fees, GSN subsidies.
- **Risk: Code Bugs**: Mitigate with Ganache testing, basic audit.

## 7. Timeline and Milestones
- **Q4 2025 (MVP)**: Code Mini Oracle (1-2 weeks), integrate with prototypes (1 week), test on Base Sepolia (1 week). Launch internal alpha.
- **Q1 2026 (Beta)**: Audit tweaks, mainnet deploy, onboard 10K users via sports hype (e.g., NBA season). Hit $500K TVL.
- **Q2 2026 (V1)**: Upgrade to DAO for resolutions, expand to Polygon backup.
