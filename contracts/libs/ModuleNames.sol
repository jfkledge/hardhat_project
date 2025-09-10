// contracts/Constants.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

library ModuleNames {
    string public constant ROLE_ACCESS = 'RoleAccess';
    string public constant PROJECT_MANAGER = 'ProjectManager';
    string public constant FUND_MANAGER = 'FundManager';
    uint96 internal constant MIN_DONATION = 0;
    uint256 internal constant BUFFER_TIME = 900;
}
