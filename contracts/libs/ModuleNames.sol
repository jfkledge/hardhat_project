// contracts/Constants.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

library ModuleNames {
    string public constant ROLE_ACCESS = 'RoleAccess';
    string public constant PROJECT_MANAGER = 'ProjectManager';
    string public constant FUND_MANAGER = 'FundManager';

    bytes32 public constant ROLE_ACCESS_HASH = keccak256(bytes(ROLE_ACCESS));
    bytes32 public constant PROJECT_MANAGER_HASH = keccak256(bytes(PROJECT_MANAGER));
    bytes32 public constant RUND_MANAGER_HASH = keccak256(bytes(FUND_MANAGER));
}
