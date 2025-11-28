// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

enum ProjectStatus {
    Uninitialized,
    Created,
    Fundraising,
    Successful,
    Failed,
    Ended,
    Cancelled
}

enum PermissionType {
    Cancel,
    Withdraw,
    UpdateStatus
}

struct Project {
    address creator; // slot 0
    uint96 goal; // slot ０
    uint96 amountRaised; // slot 1
    uint64 deadline; // slot 1
    ProjectStatus status; // slot １
    string title; // slot 3
    string description; // slot 4
}

struct DonationRecord {
    uint64 projectId;
    uint64 timestamp;
    uint96 amount;
}
