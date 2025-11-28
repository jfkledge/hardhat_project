// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;
import { PermissionType } from '../ProjectEnum.sol';

interface IRoleAccess {
    event PermissionGranted(
        uint64 indexed projectId,
        PermissionType permission,
        address indexed user
    );
    event PermissionRevoked(
        uint64 indexed projectId,
        PermissionType permission,
        address indexed user
    );
}
