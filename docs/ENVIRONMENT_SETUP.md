# Environment Configuration Setup

## Overview
This document describes the environment configuration files created for the CTF-exchange deployment across different networks.

## Environment Files

### 1. `.env.local` - Local Development (Ganache)
**Purpose**: Configuration for local blockchain development using Ganache

**Key Features**:
- Uses actual private key and admin address from `config.py`
- Configured for Ganache on port 7545
- Empty contract addresses (to be filled during deployment)
- Debug mode enabled
- Chain ID: 1337 (Ganache default)

**Usage**:
```bash
# Load local environment
source .env.local
# or
export $(cat .env.local | xargs)
```

### 2. `.env.testnet` - Testnet Deployment
**Purpose**: Configuration for testnet deployment (Amoy/Polygon Mumbai)

**Key Features**:
- **PLACEHOLDER VALUES** - All values need to be updated with actual testnet addresses
- Configured for Polygon Mumbai testnet
- Real contract addresses will be used (USDC, CTF, factories)
- Debug mode disabled
- Chain ID: 80001 (Polygon Mumbai)

**Important Notes**:
- All contract addresses are placeholders and must be replaced with actual testnet addresses
- Private key must be replaced with actual deployment key
- Admin address must be replaced with actual admin address

**Usage**:
```bash
# Load testnet environment
source .env.testnet
# or
export $(cat .env.testnet | xargs)
```

### 3. `.env` - Mainnet Deployment
**Purpose**: Configuration for production deployment on Polygon mainnet

**Key Features**:
- **PLACEHOLDER VALUES** - All values need to be updated with actual mainnet addresses
- Configured for Polygon mainnet
- Real contract addresses will be used (USDC, CTF, factories)
- Debug mode disabled
- Chain ID: 137 (Polygon mainnet)

**Security Warnings**:
- ⚠️ **CRITICAL**: Replace placeholder private key with secure key management
- ⚠️ **CRITICAL**: Verify all contract addresses before deployment
- ⚠️ **CRITICAL**: Use multi-signature wallets for production deployments

**Usage**:
```bash
# Load mainnet environment
source .env
# or
export $(cat .env | xargs)
```

## Environment Variables

### Required Variables
- `PK` - Private key for contract deployment
- `ADMIN` - Admin address for the exchange
- `RPC_URL` - Network RPC endpoint
- `COLLATERAL` - Collateral token address (USDC)
- `CTF` - ConditionalTokens Framework address
- `PROXY_FACTORY` - Polymarket proxy factory address
- `SAFE_FACTORY` - Gnosis Safe factory address

### Optional Variables
- `CHAIN_ID` - Network chain ID
- `GAS_LIMIT` - Gas limit for transactions
- `GAS_PRICE` - Gas price for transactions
- `ENVIRONMENT` - Environment identifier
- `DEBUG` - Debug mode flag

## Network Configuration

### Local Development (Ganache)
- **RPC URL**: `http://localhost:7545`
- **Chain ID**: 1337
- **Gas Limit**: 8,000,000
- **Gas Price**: 20 Gwei

### Testnet (Polygon Mumbai)
- **RPC URL**: `https://rpc-mumbai.maticvigil.com`
- **Chain ID**: 80001
- **Gas Limit**: 8,000,000
- **Gas Price**: 30 Gwei

### Mainnet (Polygon)
- **RPC URL**: `https://polygon-rpc.com`
- **Chain ID**: 137
- **Gas Limit**: 8,000,000
- **Gas Price**: 50 Gwei

## Contract Addresses

### Local Development
All contract addresses will be empty initially and filled during deployment:
- `COLLATERAL` - Mock USDC (deployed locally)
- `CTF` - Real ConditionalTokens (deployed locally)
- `PROXY_FACTORY` - Beacon Proxy Factory (deployed locally)
- `SAFE_FACTORY` - Gnosis Safe Factory (deployed locally)

### Testnet/Mainnet
Contract addresses need to be updated with actual deployed addresses:
- `COLLATERAL` - Real USDC contract address
- `CTF` - Real ConditionalTokens Framework address
- `PROXY_FACTORY` - Real Polymarket proxy factory address
- `SAFE_FACTORY` - Real Gnosis Safe factory address

## Security Considerations

### Private Key Management
- **Local**: Can use hardcoded key for development
- **Testnet**: Use dedicated testnet private key
- **Mainnet**: Use secure key management system (hardware wallet, multi-sig)

### Environment File Security
- All `.env*` files are in `.gitignore` to prevent accidental commits
- Never commit real private keys to version control
- Use environment-specific keys for each network

### Production Deployment
- Use multi-signature wallets for admin operations
- Implement timelock contracts for critical operations
- Regular security audits and monitoring
- Emergency pause mechanisms

## Next Steps

1. **Local Development**: Contract addresses will be filled during local deployment
2. **Testnet**: Update placeholder values with actual testnet contract addresses
3. **Mainnet**: Update placeholder values with actual mainnet contract addresses

## Troubleshooting

### Common Issues
1. **Invalid RPC URL**: Ensure RPC endpoint is accessible
2. **Wrong Chain ID**: Verify chain ID matches network
3. **Insufficient Gas**: Adjust gas limit/price for network
4. **Invalid Contract Addresses**: Verify addresses are correct for network

### Validation
Before deployment, validate environment configuration:
```bash
# Check environment variables are loaded
echo $PK
echo $ADMIN
echo $RPC_URL
echo $COLLATERAL
echo $CTF
echo $PROXY_FACTORY
echo $SAFE_FACTORY
``` 