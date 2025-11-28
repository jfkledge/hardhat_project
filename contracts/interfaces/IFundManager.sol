// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IFundManager {
    event ProjectClaimFunds(uint64 indexed projectId, address indexed creator, uint96 amountRaised);
    event ProjectDonate(uint64 indexed projectId, address indexed user, uint96 amount);
    event ProjectRefund(uint64 indexed projectId, address indexed user, uint96 amount);
}
