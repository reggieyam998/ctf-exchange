# Negative Risk (NegRisk) Summary

## What is Negative Risk?
Negative Risk (NegRisk) is a system used by Polymarket to manage **multi-outcome prediction markets**, like betting on which candidate (e.g., Alice, Bob, or Charlie) will win an election, where only one outcome can be true. It treats the market as a set of linked YES/NO bets for each option and allows users to **convert "NO" bets into "YES" bets plus cash (USDC)**, creating positions with predictable, low-risk payouts. This makes betting easier, more flexible, and less risky, hence the name "Negative Risk."

**Analogy**: It’s like a raffle where you bet on which horse won’t win. NegRisk lets you swap "NO" tickets for a "YES" ticket on another horse plus some cash, making your bet simpler and safer.

## How Does NegRisk Work?
NegRisk uses smart contracts to manage multi-outcome markets on the Polygon blockchain, integrating with the **Gnosis Conditional Tokens Framework (CTF)** and **UMA’s Optimistic Oracle**. Here’s the process in simple terms:

1. **Market Setup**:
   - A multi-outcome market (e.g., "Who will win the election?") is split into YES/NO bets for each option (e.g., Alice, Bob, Charlie).
   - The **NegRiskOperator** (a smart contract) lets admins set up these bets, ensuring only one can resolve to YES (e.g., if Alice wins, Bob and Charlie lose).
   - The **UmaCtfAdapter** connects each bet to the UMA oracle, which will decide the winner.

2. **Trading**:
   - Users buy YES or NO tokens (like raffle tickets) using USDC via the **NegRiskCtfExchange**, a trading platform tailored for NegRisk markets.
   - An off-chain system (CLOB) matches buy/sell orders to make trading fast and cheap, settling trades on-chain.
   - **Proxy wallets** hold users’ tokens and USDC, making trades seamless with no gas fees (using the Gas Station Network).

3. **Converting Bets**:
   - The **NegRiskAdapter** lets users convert multiple NO bets (e.g., NO Alice + NO Bob) into a YES bet (e.g., YES Charlie) plus USDC.
   - **Example**: In an election market:
     - 1 NO Alice + 1 NO Bob pays:
       - 1 USDC if Alice wins (NO Bob is correct).
       - 1 USDC if Bob wins (NO Alice is correct).
       - 2 USDC if Charlie wins (both NOs are correct).
     - This is equivalent to 1 USDC + 1 YES Charlie, which the NegRiskAdapter converts to, using **WrappedCollateral** (a special USDC token) to release cash.
   - A small fee for conversions goes to the **Vault** contract.

4. **Resolution**:
   - The **UmaCtfAdapter** asks the **UMA Optimistic Oracle** to determine the outcome (e.g., "Alice won").
   - Proposers suggest answers (e.g., YES Alice) with a USDC deposit. Others can dispute for ~2 hours. If disputed twice, UMA’s voting system (DVM) decides in 48–72 hours.
   - The NegRiskAdapter ensures only one YES outcome (e.g., YES Alice, NO Bob, NO Charlie). If the oracle suggests a tie, it rejects it.
   - The outcome is reported to the CTF contract, locking in winning tokens.

5. **Redemption**:
   - Users with winning tokens (e.g., YES Alice or NO Bob/Charlie) use their proxy wallets to cash them in for USDC via the CTF contract.

## Why Is It Called Negative Risk?
It’s called Negative Risk because converting NO bets (e.g., NO Alice + NO Bob) into YES bets plus USDC (e.g., YES Charlie + 1 USDC) creates a position with **predictable, low-risk payouts**. For example:
- NO Alice + NO Bob is worth 1 USDC if Alice or Bob wins, 2 USDC if Charlie wins.
- 1 USDC + 1 YES Charlie is worth the same in all cases, but the USDC is guaranteed value, reducing uncertainty.
- This feels "less risky" (like negative risk) because the position is hedged, with stable value across outcomes.

It’s not truly risk-free due to:
- Fees for conversions.
- Oracle risks (e.g., disputes or errors).
- Potential market misconfigurations (e.g., ties).

## Benefits of NegRisk
- **Simpler Betting**: Converts complex NO bets into simpler YES bets plus cash, making it easier to manage positions.
- **Increased Liquidity**: Easier-to-trade YES tokens and USDC attract more buyers/sellers, making the market more active.
- **Greater Depth**: Conversions focus trading on YES tokens, creating more buy/sell orders at various prices.
- **Fair Resolution**: The UMA oracle ensures trustworthy outcomes, encouraging more people to trade.
- **Efficiency**: Off-chain order matching and proxy wallets reduce costs, boosting participation.

## Key Contracts
- **NegRiskCtfExchange**: Handles trading of YES/NO tokens.
- **NegRiskAdapter**: Converts NO bets to YES bets plus USDC.
- **NegRiskOperator**: Sets up markets, ensuring one YES outcome.
- **UmaCtfAdapter**: Connects to UMA’s oracle for resolution.
- **Vault**: Collects conversion fees.
- **WrappedCollateral**: Wraps USDC for conversions.
- **CTF**: Manages YES/NO tokens and redemptions.

## Why It Matters
NegRisk makes multi-outcome markets (like elections) more appealing by reducing risk and simplifying trades. It encourages more people to join, increases trading activity, and ensures fair payouts, making Polymarket’s betting system more robust and user-friendly.