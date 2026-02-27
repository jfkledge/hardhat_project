// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IModuleBase {
    struct ModuleInfo {
        string name;
        address moduleAddress;
    }

    event registerModuleEvent(address indexed _contractAddress);

    event unRegisterModuleEvent(string indexed name, address indexed _oldAddress);

    event updateModuleEvent(
        string indexed name,
        address indexed newAddress,
        address indexed oldAddress
    );

    error ModuleNotFound();

    error AlreadySet();

    error NotSet();

    error CallFailed();

    error UnauthorizedCaller();

    function getName() external pure returns (string memory);
}
