// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import './ModuleBase.sol';

contract RoleAccess is ModuleBase {
    mapping(uint64 => mapping(PermissionType => mapping(address => bool))) private _permissions;

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

    function getName() external pure returns (string memory) {
        return ModuleNames.ROLE_ACCESS;
    }

    modifier onlyProjectCreator(uint64 projectId) {
        bytes memory data = callModuleView(
            getModuleAddress(ModuleNames.PROJECT_MANAGER),
            'getProjectCreator(uint64)',
            abi.encode(projectId)
        );
        address projectOwner = abi.decode(data, (address));
        if (projectOwner != msg.sender) revert NotProjectOwner();
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
