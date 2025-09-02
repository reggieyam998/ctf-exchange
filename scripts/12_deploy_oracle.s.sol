// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { FoxMinimalOracle } from "../src/oracle/FoxMinimalOracle.sol";
import { console2 } from "forge-std/console2.sol";

/// @title Deploy Fox Minimal Oracle
/// @notice Script to deploy the Fox Minimal Oracle to Base chain
/// @author Fox Market
contract DeployOracle is Script {
    // Base Mainnet addresses
    address constant USDT_BASE = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb; // USDC on Base (using as USDT)
    address constant CTF_BASE = 0x4D7C363DED4B3b4e1F954494d2Bc3955e49699cC; // ConditionalTokens on Base

    // Base Sepolia addresses (for testing)
    address constant USDT_SEPOLIA = 0x4e59b44847b379578588920cA78FbF26c0B4956C; // USDC on Base Sepolia
    address constant CTF_SEPOLIA = 0x4D7C363DED4B3b4e1F954494d2Bc3955e49699cC; // ConditionalTokens on Base Sepolia

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying Fox Minimal Oracle...");
        console2.log("Deployer:", deployer);

        // Determine network and addresses
        uint256 chainId = block.chainid;
        address bondToken;
        address ctf;

        if (chainId == 8453) {
            // Base Mainnet
            bondToken = USDT_BASE;
            ctf = CTF_BASE;
            console2.log("Network: Base Mainnet");
        } else if (chainId == 84532) {
            // Base Sepolia
            bondToken = USDT_SEPOLIA;
            ctf = CTF_SEPOLIA;
            console2.log("Network: Base Sepolia");
        } else {
            // Local/other networks - use provided addresses or defaults
            try vm.envString("BOND_TOKEN") returns (string memory envBondToken) {
                bondToken = vm.parseAddress(envBondToken);
            } catch {
                bondToken = USDT_SEPOLIA;
            }
            
            try vm.envString("CTF_ADDRESS") returns (string memory envCtf) {
                ctf = vm.parseAddress(envCtf);
            } catch {
                ctf = CTF_SEPOLIA;
            }
            console2.log("Network: Local/Other (Chain ID:", chainId, ")");
        }

        console2.log("Bond Token:", bondToken);
        console2.log("CTF Address:", ctf);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the oracle
        FoxMinimalOracle oracle = new FoxMinimalOracle(bondToken, ctf);

        vm.stopBroadcast();

        console2.log("Fox Minimal Oracle deployed at:", address(oracle));
        console2.log("Owner:", oracle.owner());
        console2.log("Min Bond:", oracle.minBond());
        console2.log("Default Liveness:", oracle.defaultLiveness());

        // Log deployment info to console instead of writing to file
        console2.log("=== DEPLOYMENT SUMMARY ===");
        console2.log("Oracle Address:", address(oracle));
        console2.log("Owner:", oracle.owner());
        console2.log("Bond Token:", bondToken);
        console2.log("CTF Address:", ctf);
        console2.log("Min Bond:", oracle.minBond());
        console2.log("Default Liveness:", oracle.defaultLiveness(), "seconds");
        console2.log("==========================");
    }
}
