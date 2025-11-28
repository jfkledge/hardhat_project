// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import './ModuleBase.sol';
import './ProjectStorage.sol';
import './interfaces/IProjectManager.sol';
import { Project, PermissionType } from './ProjectEnum.sol';

contract ProjectManager is ModuleBase, ProjectStorage, IProjectManager {
    function getName() external pure returns (string memory) {
        return ModuleNames.PROJECT_MANAGER;
    }

    //create projet
    function createProject(
        string calldata title,
        string calldata description,
        uint96 goal,
        uint64 deadline,
        bool openDonationNow
    ) external {
        if (goal == ModuleNames.MIN_DONATION) revert InvalidGoal();
        if (deadline <= block.timestamp + ModuleNames.BUFFER_TIME) revert InvalidDeadline();
        ProjectStatus status = openDonationNow ? ProjectStatus.Fundraising : ProjectStatus.Created;
        uint64 projectId = nextProjectId;
        unchecked {
            nextProjectId++;
        }
        projects[projectId] = Project({
            creator: msg.sender,
            title: title,
            description: description,
            goal: goal,
            deadline: deadline,
            amountRaised: ModuleNames.MIN_DONATION,
            status: status
        });
        creatorProjects[msg.sender].push(projectId);
        emit ProjectCreated(projectId, msg.sender, goal, deadline);
    }

    modifier onlyProjectOwner(uint64 projectId, PermissionType permission) {
        Project memory project = _getProject(projectId);
        address currentMsgSender = msg.sender;
        if (currentMsgSender == project.creator) {
            _;
        } else {
            bytes memory data = callModuleView(
                getModuleAddress(ModuleNames.ROLE_ACCESS),
                'hasPermission(uint64,PermissionType,address)',
                abi.encode(projectId, permission, currentMsgSender)
            );
            bool result = abi.decode(data, (bool));
            if (!result) revert NotProjectOwner();
            _;
        }
    }

    function startFundraising(
        uint64 projectId
    ) external onlyProjectOwner(projectId, PermissionType.UpdateStatus) {
        Project storage project = _getProject(projectId);
        if (project.status != ProjectStatus.Created) {
            revert NotInStatus(ProjectStatus.Created, project.status);
        }
        project.status = ProjectStatus.Fundraising;
        emit ProjectUpdateStatus(projectId, ProjectStatus.Fundraising);
    }

    function pauseFundraising(
        uint64 projectId
    ) external onlyProjectOwner(projectId, PermissionType.UpdateStatus) {
        Project storage project = _getProject(projectId);
        if (project.status != ProjectStatus.Fundraising) {
            revert NotInStatus(ProjectStatus.Fundraising, project.status);
        }
        project.status = ProjectStatus.Created;
        emit ProjectUpdateStatus(projectId, ProjectStatus.Created);
    }

    //update project status
    function updateProjectStatus(uint64 projectId) private {
        Project storage project = _getProject(projectId);
        ProjectStatus oldStatus = project.status;
        ProjectStatus newStatus = oldStatus;
        if (oldStatus == ProjectStatus.Created) {
            newStatus = ProjectStatus.Fundraising;
        } else if (oldStatus == ProjectStatus.Fundraising) {
            uint256 nowTimestamp = block.timestamp;
            uint96 goal = project.goal;
            uint96 amountRaised = project.amountRaised;
            uint64 deadline = project.deadline;
            if (nowTimestamp + ModuleNames.BUFFER_TIME > deadline) {
                if (amountRaised < goal) {
                    newStatus = ProjectStatus.Failed;
                } else {
                    newStatus = ProjectStatus.Successful;
                }
            }
        } else if (
            oldStatus == ProjectStatus.Successful &&
            project.amountRaised == ModuleNames.MIN_DONATION
        ) {
            newStatus = ProjectStatus.Ended;
        }
        if (newStatus != oldStatus) {
            project.status = newStatus;
            emit ProjectUpdateStatus(projectId, newStatus);
        }
    }

    function cancelProject(
        uint64 projectId
    ) external onlyProjectOwner(projectId, PermissionType.Cancel) {
        Project storage project = _getProject(projectId);
        ProjectStatus oldStatus = project.status;
        if (oldStatus != ProjectStatus.Created && oldStatus != ProjectStatus.Fundraising) {
            revert NotInStatus(ProjectStatus.Created, oldStatus);
        }
        project.status = ProjectStatus.Cancelled;
        emit ProjectUpdateStatus(projectId, ProjectStatus.Cancelled);
    }

    function donate(
        uint64 projectId,
        uint96 msgValue,
        uint64 timestamp
    ) external onlyAuthorizedContract(ModuleNames.FUND_MANAGER) {
        if (msgValue == ModuleNames.MIN_DONATION) revert DonationTooSmall();
        Project storage project = _getProject(projectId);
        if (project.status != ProjectStatus.Fundraising) {
            revert NotInStatus(ProjectStatus.Fundraising, project.status);
        }
        if (timestamp + ModuleNames.BUFFER_TIME > project.deadline) {
            updateProjectStatus(projectId);
            revert ProjectDeadlinePassed();
        }
        unchecked {
            project.amountRaised += msgValue;
        }
        if (project.amountRaised >= project.goal) {
            updateProjectStatus(projectId);
        }
        emit ProjectUpdateStatus(projectId, project.status);
    }

    function claimFunds(
        uint64 projectId
    ) external onlyAuthorizedContract(ModuleNames.FUND_MANAGER) {
        Project storage project = _getProject(projectId);
        project.amountRaised = ModuleNames.MIN_DONATION;
        updateProjectStatus(projectId);
        emit ProjectUpdateStatus(projectId, project.status);
    }

    function refund(
        uint64 projectId,
        uint96 amount
    ) external onlyAuthorizedContract(ModuleNames.FUND_MANAGER) {
        Project storage project = _getProject(projectId);
        unchecked {
            project.amountRaised -= amount;
        }
    }

    /**
     * get project struct by projectId
     */
    function _getProject(uint64 projectId) internal view returns (Project storage) {
        Project storage project = projects[projectId];
        if (project.status == ProjectStatus.Uninitialized) {
            revert ProjectNotFound();
        }
        return project;
    }
}
