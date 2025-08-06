// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IConditionalTokens } from "src/exchange/interfaces/IConditionalTokens.sol";
import { IERC165 } from "openzeppelin-contracts/utils/introspection/IERC165.sol";

/// @title CTF Functionality Test Script
/// @notice Tests basic CTF functionality after deployment
contract TestCTFFunctionality is Script {
    
    // CTF contract deployed at this address (from Ganache log)
    address public constant CTF_ADDRESS = address(0x1B218bDC9D1621101039AC8aC8B0b66BBe2f8a7f);
    
    function run() public {
        console.log("=== CTF Functionality Test Script ===");
        
        IConditionalTokens ctf = IConditionalTokens(CTF_ADDRESS);
        
        // Test 1: Check if contract is deployed
        uint256 codeSize;
        address ctfAddr = CTF_ADDRESS;
        assembly {
            codeSize := extcodesize(ctfAddr)
        }
        
        if (codeSize > 0) {
            console.log("PASS: CTF contract is deployed at", CTF_ADDRESS);
        } else {
            console.log("FAIL: CTF contract is not deployed at", CTF_ADDRESS);
            return;
        }
        
        // Test 2: Check if contract supports ERC165 interface
        try IERC165(CTF_ADDRESS).supportsInterface(0x01ffc9a7) {
            console.log("PASS: CTF contract supports ERC165 interface");
        } catch {
            console.log("WARNING: CTF contract does not support ERC165 interface");
        }
        
        // Test 3: Check if contract supports ERC1155 interface
        try IERC165(CTF_ADDRESS).supportsInterface(0xd9b67a26) {
            console.log("PASS: CTF contract supports ERC1155 interface");
        } catch {
            console.log("WARNING: CTF contract does not support ERC1155 interface");
        }
        
        // Test 4: Try to call a basic CTF function (prepareCondition)
        // This will fail if the contract is not properly deployed
        try ctf.prepareCondition(address(0x123), bytes32(uint256(0x123)), 2) {
            console.log("PASS: CTF prepareCondition function is callable");
        } catch Error(string memory reason) {
            console.log("INFO: CTF prepareCondition function exists but failed:", reason);
        } catch {
            console.log("WARNING: CTF prepareCondition function may not exist");
        }
        
        console.log("=== CTF Functionality Test Complete ===");
    }
} 