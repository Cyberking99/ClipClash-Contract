// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ClipClash} from "../src/ClipClash.sol";

contract DeployScript is Script {
    ClipClash public clipClash;

    address public clashTokenAddress = vm.envAddress("CLASH_TOKEN_ADDRESS");

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        clipClash = new ClipClash(clashTokenAddress, msg.sender);

        console.log("ClipClash deployed at: ", address(clipClash));

        vm.stopBroadcast();
    }
}
