// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { ProjectStatus } from '../ProjectEnum.sol';
interface IProjectManager {
    event ProjectCreated(
        uint64 indexed projectId,
        address indexed creator,
        uint96 goal,
        uint64 deadline
    );

    event ProjectUpdateStatus(uint64 indexed projectId, ProjectStatus status);
}
