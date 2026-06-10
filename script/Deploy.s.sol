// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Vesting} from "../src/Vesting.sol";

/// @notice Deploy script for Vesting contract
/// Run: forge script script/Deploy.s.sol --broadcast --rpc-url <RPC_URL>
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address beneficiary = vm.envAddress("BENEFICIARY");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        uint256 totalAmount = vm.envUint("TOTAL_AMOUNT");

        vm.startBroadcast(deployerPrivateKey);

        Vesting vesting = new Vesting(beneficiary, tokenAddress, totalAmount);

        vm.stopBroadcast();

        console.log("Vesting deployed at:", address(vesting));
        console.log("Beneficiary:", beneficiary);
        console.log("Token:", tokenAddress);
        console.log("Total amount:", totalAmount);
    }
}
