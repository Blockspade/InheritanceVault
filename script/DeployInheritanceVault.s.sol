// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {InheritanceVault} from "../src/InheritanceVault.sol";

// deploy inheritance vault
contract DeployInheritanceVault is Script {
    function run() external returns (InheritanceVault) {
        // Get the deployer's private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get the heir address from environment (or use a default for testing)
        address heir = vm.envAddress("HEIR_ADDRESS");
        
        require(heir != address(0), "Heir address must be set");
        
        console2.log("Deploying InheritanceVault...");
        console2.log("Deployer:", vm.addr(deployerPrivateKey));
        console2.log("Heir:", heir);
        
        vm.startBroadcast(deployerPrivateKey);
        
        InheritanceVault vault = new InheritanceVault(heir);
        
        vm.stopBroadcast();
        
        console2.log("InheritanceVault deployed at:", address(vault));
        console2.log("Owner:", vault.owner());
        console2.log("Heir:", vault.heir());
        console2.log("Inactivity Period:", vault.INACTIVITY_PERIOD() / 1 days, "days");
        
        return vault;
    }
    
    function deployWithHeir(address heirAddress) external returns (InheritanceVault) {
        require(heirAddress != address(0), "Invalid heir address");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        InheritanceVault vault = new InheritanceVault(heirAddress);
        
        vm.stopBroadcast();
        
        return vault;
    }
}

