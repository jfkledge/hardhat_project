// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IModuleBase {
    event registerModuleEvent(address indexed _contractAddress);
    event unRegisterModuleEvent(string indexed name, address indexed _oldAddress);
    event updateModuleEvent(
        string indexed name,
        address indexed newAddress,
        address indexed oldAddress
    );

    function getName() external pure returns (string memory);
}
