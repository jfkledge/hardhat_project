// contracts/Constants.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;
import { Project, ProjectStatus } from '../ProjectEnum.sol';
import '../interfaces/IProjectManager.sol';

library ProjectUtils {
    function checkStatus(Project memory project, ProjectStatus projectStatus) external pure {
        if (project.status != projectStatus) {
            revert IProjectManager.NotInStatus(projectStatus, project.status);
        }
    }

    function checkStatus1(
        Project memory project,
        ProjectStatus projectStatus1,
        ProjectStatus projectStatus2
    ) external pure {
        if (project.status != projectStatus1 && project.status != projectStatus2) {
            revert IProjectManager.NotInStatus(projectStatus1, project.status);
        }
    }

    function checkExists(Project memory project) external pure {
        if (project.status == ProjectStatus.Uninitialized) {
            revert IProjectManager.ProjectNotFound();
        }
    }
}
