// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ExchangeBeacon } from "src/dev/mocks/ExchangeBeacon.sol";
import { BeaconProxy } from "src/dev/mocks/BeaconProxy.sol";
import { BeaconProxyFactory } from "src/dev/mocks/BeaconProxyFactory.sol";
import { MockImplementation } from "src/dev/mocks/MockImplementation.sol";

/// @title TestBeaconProxy
/// @notice Script to test beacon proxy system functionality
contract TestBeaconProxy is Script {
    ExchangeBeacon public beacon;
    BeaconProxyFactory public factory;
    BeaconProxy public proxy1;
    BeaconProxy public proxy2;
    MockImplementation public implementation1;
    MockImplementation public implementation2;

    function run() public {
        console.log("=== Testing Beacon Proxy System ===");
        
        // Deploy mock implementations
        implementation1 = new MockImplementation();
        implementation2 = new MockImplementation();
        console.log("Implementation 1 deployed at:", address(implementation1));
        console.log("Implementation 2 deployed at:", address(implementation2));
        
        // Deploy beacon with initial implementation
        address beaconOwner = vm.addr(1);
        beacon = new ExchangeBeacon(address(implementation1), beaconOwner);
        console.log("Beacon deployed at:", address(beacon));
        
        // Deploy factory
        address factoryOwner = vm.addr(2);
        factory = new BeaconProxyFactory(address(beacon), factoryOwner);
        console.log("Factory deployed at:", address(factory));
        
        // Test beacon functionality
        _testBeaconFunctionality();
        
        // Test proxy creation
        _testProxyCreation();
        
        // Test upgrade mechanism
        _testUpgradeMechanism();
        
        console.log("All beacon proxy tests passed!");
    }
    
    function _testBeaconFunctionality() internal {
        console.log("\n--- Testing Beacon Functionality ---");
        
        // Test initial implementation
        address impl = beacon.implementation();
        console.log("Initial implementation:", impl);
        
        // Test pause/unpause (need to use correct owner)
        vm.prank(vm.addr(1)); // Use the beacon owner
        beacon.pause();
        console.log("Beacon paused");
        
        vm.prank(vm.addr(1)); // Use the beacon owner
        beacon.unpause();
        console.log("Beacon unpaused");
        
        // Test upgrade scheduling
        vm.prank(vm.addr(1)); // Use the beacon owner
        beacon.scheduleUpgrade(address(implementation2), 3600); // 1 hour timelock
        console.log("Upgrade scheduled");
        
        // Check pending upgrade
        (address pendingImpl, uint256 upgradeTime, uint256 timelock) = beacon.getPendingUpgrade();
        console.log("Pending implementation:", pendingImpl);
        console.log("Upgrade time:", upgradeTime);
        console.log("Timelock duration:", timelock);
        
        // Cancel upgrade
        vm.prank(vm.addr(1)); // Use the beacon owner
        beacon.cancelUpgrade();
        console.log("Upgrade cancelled");
        
        console.log("Beacon functionality test passed!");
    }
    
    function _testProxyCreation() internal {
        console.log("\n--- Testing Proxy Creation ---");
        
        // Create proxies
        address owner1 = vm.addr(3);
        address owner2 = vm.addr(4);
        
        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");
        
        // Predict addresses
        address predictedProxy1 = factory.predictProxyAddress(owner1, salt1);
        address predictedProxy2 = factory.predictProxyAddress(owner2, salt2);
        
        console.log("Predicted proxy 1:", predictedProxy1);
        console.log("Predicted proxy 2:", predictedProxy2);
        
        // Create proxies
        address payable proxy1Address = payable(factory.createProxy(owner1, salt1, ""));
        address payable proxy2Address = payable(factory.createProxy(owner2, salt2, ""));
        
        console.log("Created proxy 1:", proxy1Address);
        console.log("Created proxy 2:", proxy2Address);
        
        // Verify addresses match predictions
        require(proxy1Address == predictedProxy1, "Proxy 1 address mismatch");
        require(proxy2Address == predictedProxy2, "Proxy 2 address mismatch");
        
        // Get proxy instances
        proxy1 = BeaconProxy(proxy1Address);
        proxy2 = BeaconProxy(proxy2Address);
        
        // Test proxy functionality
        console.log("Proxy 1 owner:", proxy1.owner());
        console.log("Proxy 2 owner:", proxy2.owner());
        console.log("Proxy 1 beacon:", proxy1.getBeacon());
        console.log("Proxy 2 beacon:", proxy2.getBeacon());
        
        console.log("Proxy creation test passed!");
    }
    
    function _testUpgradeMechanism() internal {
        console.log("\n--- Testing Upgrade Mechanism ---");
        
        // Get current implementation from proxies
        address impl1 = proxy1.getImplementation();
        address impl2 = proxy2.getImplementation();
        
        console.log("Proxy 1 implementation:", impl1);
        console.log("Proxy 2 implementation:", impl2);
        
        // Schedule upgrade
        vm.prank(vm.addr(1)); // Use the beacon owner
        beacon.scheduleUpgrade(address(implementation2), 0); // No timelock for testing
        
        // Execute upgrade
        vm.prank(vm.addr(1)); // Use the beacon owner
        beacon.executeUpgrade();
        console.log("Upgrade executed");
        
        // Check new implementation
        address newImpl1 = proxy1.getImplementation();
        address newImpl2 = proxy2.getImplementation();
        
        console.log("New proxy 1 implementation:", newImpl1);
        console.log("New proxy 2 implementation:", newImpl2);
        
        // Verify both proxies use new implementation
        require(newImpl1 == address(implementation2), "Proxy 1 not upgraded");
        require(newImpl2 == address(implementation2), "Proxy 2 not upgraded");
        
        console.log("Upgrade mechanism test passed!");
    }
} 