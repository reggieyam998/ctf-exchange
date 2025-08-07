# CTF Contract Verification Commands

These are Foundry cast commands to test your CTF contract deployed at `0xb8A035717410f4D45DbCBF8b693aa71caCb5EA5D` on local Ganache.

## Basic Contract Verification

### 1. Check if contract supports ERC1155 interface
```bash
cast call 0xb8A035717410f4D45DbCBF8b693aa71caCb5EA5D "supportsInterface(bytes4)" 0xd9b67a26 --rpc-url http://localhost:7545
```

### 2. Check balance for a specific address and token ID
```bash
# Replace with an actual address and token ID
cast call 0xb8A035717410f4D45DbCBF8b693aa71caCb5EA5D "balanceOf(address,uint256)" 0x1234567890123456789012345678901234567890 1 --rpc-url http://localhost:7545
```

### 3. Check approval status for an operator
```bash
# Check if address 0x1234... is approved for address 0x5678...
cast call 0xb8A035717410f4D45DbCBF8b693aa71caCb5EA5D "isApprovedForAll(address,address)" 0x1234567890123456789012345678901234567890 0x5678901234567890123456789012345678901234 --rpc-url http://localhost:7545
```

## CTF-Specific Functions

### 4. Get condition ID (pure function)
```bash
# Parameters: oracle address, question ID, outcome slot count
cast call 0xb8A035717410f4D45DbCBF8b693aa71caCb5EA5D "getConditionId(address,bytes32,uint256)" 0x1234567890123456789012345678901234567890 0x0000000000000000000000000000000000000000000000000000000000000001 2 --rpc-url http://localhost:7545
```

### 5. Get outcome slot count for a condition
```bash
# Replace with actual condition ID
cast call 0xb8A035717410f4D45DbCBF8b693aa71caCb5EA5D "getOutcomeSlotCount(bytes32)" 0x0000000000000000000000000000000000000000000000000000000000000001 --rpc-url http://localhost:7545
```

### 6. Get position ID (pure function)
```bash
# Parameters: collateral token address, collection ID
cast call 0xb8A035717410f4D45DbCBF8b693aa71caCb5EA5D "getPositionId(address,bytes32)" 0x1234567890123456789012345678901234567890 0x0000000000000000000000000000000000000000000000000000000000000001 --rpc-url http://localhost:7545
```

### 7. Get collection ID
```bash
# Parameters: parent collection ID, condition ID, index set
cast call 0xb8A035717410f4D45DbCBF8b693aa71caCb5EA5D "getCollectionId(bytes32,bytes32,uint256)" 0x0000000000000000000000000000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000000000000000000000000001 1 --rpc-url http://localhost:7545
```

## Batch Operations

### 8. Check batch balance
```bash
# Check balances for multiple addresses and token IDs
cast call 0xb8A035717410f4D45DbCBF8b693aa71caCb5EA5D "balanceOfBatch(address[],uint256[])" "[0x1234567890123456789012345678901234567890,0x5678901234567890123456789012345678901234]" "[1,2]" --rpc-url http://localhost:7545
```

## Notes

- Replace `0x1234567890123456789012345678901234567890` with actual addresses
- Replace `0x0000000000000000000000000000000000000000000000000000000000000001` with actual bytes32 values
- The `--rpc-url http://localhost:7545` assumes Ganache is running on port 7545
- For write operations, you'll need to add `--private-key` or use `cast send` instead of `cast call`

## Example with Real Values

Here's an example using the first Ganache account (usually the deployer):

```bash
# Get the first account address
cast wallet address --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Use that address to check balance
cast call 0xb8A035717410f4D45DbCBF8b693aa71caCb5EA5D "balanceOf(address,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 1 --rpc-url http://localhost:7545
``` 