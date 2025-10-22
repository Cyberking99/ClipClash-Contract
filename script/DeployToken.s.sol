// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ClashToken} from "../src/ClashToken.sol";

contract DeployScript is Script {
    ClashToken public clashToken;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        clashToken = new ClashToken();

        console.log("ClashToken deployed at: ", address(clashToken));

        vm.stopBroadcast();
    }
}
