// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title MockImplementation
/// @notice Mock implementation contract for testing beacon proxy system
contract MockImplementation {
    uint256 public value;
    string public name;
    
    event ValueSet(uint256 newValue);
    event NameSet(string newName);
    
    /// @notice Sets a value
    /// @param newValue New value to set
    function setValue(uint256 newValue) external {
        value = newValue;
        emit ValueSet(newValue);
    }
    
    /// @notice Sets a name
    /// @param newName New name to set
    function setName(string memory newName) external {
        name = newName;
        emit NameSet(newName);
    }
    
    /// @notice Returns the current value
    /// @return Current value
    function getValue() external view returns (uint256) {
        return value;
    }
    
    /// @notice Returns the current name
    /// @return Current name
    function getName() external view returns (string memory) {
        return name;
    }
    
    /// @notice Returns the version
    /// @return Version string
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
} 