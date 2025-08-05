# Polymarket CTF Exchange

[![Version][version-badge]][version-link]
[![License][license-badge]][license-link]
[![Test][ci-badge]][ci-link]

[version-badge]: https://img.shields.io/github/v/release/polymarket/ctf-exchange.svg?label=version
[version-link]: https://github.com/Polymarket/ctf-exchange/releases
[license-badge]: https://img.shields.io/github/license/polymarket/ctf-exchange
[license-link]: https://github.com/Polymarket/ctf-exchange/blob/main/LICENSE.md
[ci-badge]: https://github.com/Polymarket/ctf-exchange/actions/workflows/Tests.yml/badge.svg
[ci-link]: https://github.com/Polymarket/ctf-exchange/actions/workflows/Tests.yml

## Background

The Polymarket CTF Exchange is an exchange protocol that facilitates atomic swaps between [Conditional Tokens Framework(CTF)](https://docs.gnosis.io/conditionaltokens/) ERC1155 assets and an ERC20 collateral asset.

It is intended to be used in a hybrid-decentralized exchange model wherein there is an operator that provides offchain matching services while settlement happens on-chain, non-custodially.


## Documentation

Docs for the CTF Exchange are available in this repo [here](./docs/Overview.md).

## Audit

These contracts have been audited by Chainsecurity and the report is available [here](./audit/ChainSecurity_Polymarket_Exchange_audit.pdf).


## Deployments

| Network          | Address                                                                           |
| ---------------- | --------------------------------------------------------------------------------- |
| Polygon          | [0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E](https://polygonscan.com/address/0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E)|
| Amoy           | [0xdFE02Eb6733538f8Ea35D585af8DE5958AD99E40](https://amoy.polygonscan.com/address/0xdfe02eb6733538f8ea35d585af8de5958ad99e40)|


## Development

Install [Foundry](https://github.com/foundry-rs/foundry/).

Foundry has daily updates, run `foundryup` to update `forge` and `cast`.

## Deployment

### Local Development
```bash
# Deploy to local Ganache chain
forge script scripts/01_deploy_local.s.sol --rpc-url http://localhost:7545 --broadcast --sender 0xB6f0bf48ACf3Edc3d86717B5819640dA7F078B3B
```

### Testnet Deployment
```bash
# Configure .env.testnet first, then deploy
forge script scripts/02_deploy_testnet.s.sol --rpc-url <testnet-rpc> --broadcast --sender <deployer-address>
```

### Verification
```bash
# Verify deployment
forge script scripts/03_verify_deployment.s.sol --rpc-url <rpc-url>
```

See [scripts/README.md](scripts/README.md) for detailed deployment documentation.

---

## Testing

To run all tests: `forge test`

To run test functions matching a regex pattern `forge test -m PATTERN`

To run tests in contracts matching a regex pattern `forge test --mc PATTERN`

Set `-vvv` to see a stack trace for a failed test.

---

To install new foundry submodules: `forge install UserName/RepoName@CommitHash`

To remove: `forge remove UserName/RepoName`