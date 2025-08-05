# Deployment Scripts

This folder contains Foundry deployment scripts for the CTF Exchange system.

## Script Overview

### 01_deploy_local.s.sol
**Purpose**: Local development deployment with hardcoded values  
**Usage**: `forge script scripts/01_deploy_local.s.sol --rpc-url http://localhost:7545 --broadcast --sender 0xB6f0bf48ACf3Edc3d86717B5819640dA7F078B3B`  
**Features**:
- Uses hardcoded local development values (no environment variables)
- Deploys complete Polymarket-compatible system
- Includes beacon proxy system for upgrades
- Configures admin roles automatically
- Tests Polymarket patterns (CREATE2, salt-based addressing)

### 02_deploy_testnet.s.sol
**Purpose**: Testnet deployment using environment variables  
**Usage**: `forge script scripts/02_deploy_testnet.s.sol --rpc-url <testnet-rpc> --broadcast --sender <deployer-address>`  
**Features**:
- Uses environment variables for configuration
- Designed for testnet deployment (Polygon Mumbai, etc.)
- Same Polymarket-compatible architecture as local
- Requires proper `.env.testnet` configuration

### 03_verify_deployment.s.sol
**Purpose**: Verify deployed contracts are accessible and functional  
**Usage**: `forge script scripts/03_verify_deployment.s.sol --rpc-url <rpc-url>`  
**Features**:
- Checks contract addresses and code size
- Verifies USDC, CTF, and Exchange configurations
- Validates contract functionality
- Useful for post-deployment verification

### 04_test_ctf.s.sol
**Purpose**: Test ConditionalTokens Framework deployment  
**Usage**: `forge script scripts/04_test_ctf.s.sol --rpc-url <rpc-url>`  
**Features**:
- Tests CTF deployment using Deployer.ConditionalTokens()
- Verifies CTF contract has code
- Tests basic CTF functionality (condition preparation)
- Useful for debugging CTF issues

## Deployment Order

1. **Local Development**: Use `01_deploy_local.s.sol`
2. **Testnet**: Use `02_deploy_testnet.s.sol` (after configuring `.env.testnet`)
3. **Verification**: Use `03_verify_deployment.s.sol` to verify deployment
4. **CTF Testing**: Use `04_test_ctf.s.sol` if CTF issues arise

## Environment Configuration

### Local Development
- Uses hardcoded values in `01_deploy_local.s.sol`
- No environment file required
- Works with Ganache on localhost:7545

### Testnet/Mainnet
- Requires proper environment configuration
- Use `.env.testnet` for testnet deployment
- Use `.env` for mainnet deployment
- See `docs/ENVIRONMENT_SETUP.md` for details

## Contract Architecture

All scripts deploy the same architecture:
- **Mock USDC**: ERC20 token for collateral
- **Real ConditionalTokens**: Gnosis CTF contract
- **Exchange Beacon**: Centralized upgrade mechanism
- **Polymarket-Compatible Proxy Factory**: CREATE2-based proxy creation
- **Enhanced Gnosis Safe Factory**: 1-of-1 multisig wallets
- **CTF Exchange**: Main exchange contract

## Troubleshooting

### Environment Variable Issues
- Use `01_deploy_local.s.sol` for local development (no env vars needed)
- Ensure `.env.testnet` is properly configured for testnet deployment
- Check `docs/ENVIRONMENT_SETUP.md` for environment configuration

### Deployment Verification
- Use `03_verify_deployment.s.sol` to check deployment status
- Use `04_test_ctf.s.sol` to debug CTF-specific issues
- Check contract addresses in deployment logs

### Common Issues
- **"No associated wallet"**: This is a Foundry warning, not an error
- **"Environment variable not found"**: Use local script or check env file
- **"Contract verification failed"**: Check contract addresses and network 