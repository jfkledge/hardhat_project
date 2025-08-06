// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

enum ProjectStatus {
    Uninitialized,
    Created,
    Fundraising,
    Successful,
    Failed,
    Claimed,
    Ended,
    Cancelled
}

enum PermissionType {
    Cancel,
    Withdraw,
    UpdateStatus
}

struct Project {
    address creator;
    string title;
    string description;
    uint96 goal;
    uint64 deadline;
    uint96 amountRaised;
    ProjectStatus status;
}

struct DonationRecord {
    uint64 projectId;
    uint96 amount;
    uint64 timestamp;
}
