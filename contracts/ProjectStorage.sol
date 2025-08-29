// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import './ModuleBase.sol';

contract ProjectStorage is ModuleBase {
    function getName() external pure returns (string memory) {
        return ModuleNames.PROJECT_STORAGE;
    }
}
