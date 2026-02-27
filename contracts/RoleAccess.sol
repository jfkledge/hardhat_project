// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import './ModuleBase.sol';
import { PermissionType, Project } from './ProjectEnum.sol';
import './interfaces/IRoleAccess.sol';
import './interfaces/IProjectManager.sol';

contract RoleAccess is ModuleBase, IRoleAccess {
    mapping(uint64 => mapping(PermissionType => mapping(address => bool))) private _permissions;

    function getName() external pure returns (string memory) {
        return ModuleConfig.ROLE_ACCESS;
    }

    modifier onlyProjectCreator(uint64 projectId) {
        bytes memory data = staticCall(
            getModuleAddress(ModuleConfig.PROJECT_MANAGER),
            'getProject(uint64)',
            abi.encode(projectId)
        );
        Project memory project = abi.decode(data, (Project));
        if (project.creator != msg.sender) revert NotProjectOwner();
        _;
    }

    // function name is not update, because this function is used by DeFundMe.sol
    function hasPermission(
        uint64 projectId,
        PermissionType permission,
        address user
    ) external view returns (bool) {
        return _permissions[projectId][permission][user];
    }

    function grantPermission(
        uint64 projectId,
        PermissionType permission,
        address user
    ) external onlyProjectCreator(projectId) {
        _permissions[projectId][permission][user] = true;
        emit PermissionGranted(projectId, permission, user);
    }

    function revokePermission(
        uint64 projectId,
        PermissionType permission,
        address user
    ) external onlyProjectCreator(projectId) {
        _permissions[projectId][permission][user] = false;
        emit PermissionRevoked(projectId, permission, user);
    }
}
