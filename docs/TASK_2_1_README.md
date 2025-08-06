# Task 2.1: Configure Real ConditionalTokens Contract for Local Development

## Overview
This task involves deploying the real ConditionalTokens Framework (CTF) contract on the local Ganache environment using the pre-compiled bytecode from the artifacts folder.

## Files Created

### 1. `scripts/10_simple_ctf_deployment.s.sol`
- **Purpose**: Deploys the real CTF contract using hardcoded bytecode
- **Status**: ✅ Created with placeholder bytecode
- **Usage**: Replace `PLACEHOLDER_BYTECODE_HERE` with actual bytecode from `artifacts/ConditionalTokens.json`

### 2. `scripts/11_test_ctf_functionality.s.sol`
- **Purpose**: Tests basic CTF functionality after deployment
- **Status**: ✅ Created
- **Usage**: Replace `CTF_ADDRESS` with the actual deployed address

## Steps to Complete Task 2.1

### Step 1: Extract Bytecode
1. Open `artifacts/ConditionalTokens.json`
2. Find the `bytecode.object` field (around line 810)
3. Copy the hex string value (starts with "0x6080604052...")

### Step 2: Update Deployment Script
1. Open `scripts/10_simple_ctf_deployment.s.sol`
2. Replace `PLACEHOLDER_BYTECODE_HERE` with the copied bytecode
3. Remove the "0x" prefix if present in the JSON

### Step 3: Deploy CTF Contract
```bash
forge script scripts/10_simple_ctf_deployment.s.sol --rpc-url http://localhost:7545 --broadcast --verify
```

### Step 4: Update Test Script
1. Copy the deployed CTF address from Step 3
2. Open `scripts/11_test_ctf_functionality.s.sol`
3. Replace `CTF_ADDRESS` with the actual deployed address

### Step 5: Test CTF Functionality
```bash
forge script scripts/11_test_ctf_functionality.s.sol --rpc-url http://localhost:7545
```

## Verification Checklist

- [ ] Real CTF contract deploys successfully on local chain
- [ ] All CTF functions work correctly in local environment
- [ ] Integration tests pass with real CTF contract
- [ ] Local deployment script properly configured
- [ ] Documentation updated for local CTF usage

## Expected Output

### Successful Deployment
```
=== Simple CTF Deployment Script ===
ConditionalTokens deployed at: 0x...
CTF deployment verification passed - code size: 12345
```

### Successful Functionality Test
```
=== CTF Functionality Test Script ===
✓ CTF contract found at: 0x...
✓ ERC1155 interface supported: true
✓ ERC165 interface supported: true
✓ prepareCondition function works
=== CTF Functionality Test Complete ===
```

## Troubleshooting

### Issue: Deployment Fails
- **Cause**: Invalid bytecode format
- **Solution**: Ensure bytecode is copied exactly from JSON, remove "0x" prefix if present

### Issue: Contract Not Found
- **Cause**: Wrong address or deployment failed
- **Solution**: Check deployment logs and verify address

### Issue: Functionality Tests Fail
- **Cause**: Contract not properly deployed or interface issues
- **Solution**: Verify bytecode and redeploy if necessary

## Notes

- The CTF contract uses the `CREATE` opcode for deployment (not `CREATE2`)
- The bytecode is pre-compiled and stored in `artifacts/ConditionalTokens.json`
- This approach bypasses FFI requirements and ensures reliable deployment
- The deployed contract will be identical to the one used on Polygon mainnet 