// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;
import { Project, ProjectStatus } from './ProjectEnum.sol';
import { IProjectManagerError } from './interfaces/IError.sol';

contract ProjectStorage is IProjectManagerError {
    uint64 public nextProjectId;
    mapping(uint64 => Project) public projects;
    mapping(address => uint64[]) public creatorProjects;

    function getProjectDetail(uint64 projectId) external view returns (Project memory) {
        Project memory project = projects[projectId];
        if (project.status == ProjectStatus.Uninitialized) revert ProjectNotFound();
        return project;
    }

    function getMyProjectIds() external view returns (uint64[] memory) {
        return creatorProjects[msg.sender];
    }

    function getMyCreatedProjects() external view returns (Project[] memory) {
        uint64[] memory projectIds = creatorProjects[msg.sender];
        Project[] memory myProjects = new Project[](projectIds.length);
        for (uint256 i = 0; i < projectIds.length; i++) {
            myProjects[i] = projects[projectIds[i]];
        }
        return myProjects;
    }
}
