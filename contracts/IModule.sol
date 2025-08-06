// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IModule {
    function getName() external pure returns (string memory);
}
