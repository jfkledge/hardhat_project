// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import './ModuleBase.sol';
import { PermissionType, Project } from './ProjectEnum.sol';
import { ProjectConfig } from './libs/ProjectConfig.sol';
import './interfaces/IProjectManager.sol';

// contract 關鍵字用於宣告一個新的合約（contract），在 Solidity 中它類似於其他語言的 class，但專門針對區塊鏈上的智能合約設計。
// 例如下面這行表示我們聲明了一個名為 ProjectStorage 的智能合約：
contract ProjectStorage {
    uint64 public nextProjectId;
    mapping(uint64 => Project) public projects;
    mapping(address => uint64[]) public creatorProjects;

    function getProject(uint64 projectId) external view returns (Project memory) {
        Project memory project = projects[projectId];
        project.checkExists();
        return project;
    }

    /**
     * get project struct by projectId
     */
    function _getProject(uint64 projectId) internal view returns (Project storage) {
        Project storage project = projects[projectId];
        project.checkExists();
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

contract ProjectManager is ModuleBase, ProjectStorage, IProjectManager {

    function getName() external pure returns (string memory) {
        return ModuleConfig.PROJECT_MANAGER;
    }

    //create projet
    function createProject(
        string calldata title,
        string calldata description,
        uint96 goal,
        uint64 deadline,
        bool openDonationNow
    ) external {
        if (goal == ProjectConfig.MIN_DONATION) revert InvalidGoal();
        if (deadline <= block.timestamp + ProjectConfig.BUFFER_TIME) revert InvalidDeadline();
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
            amountRaised: ProjectConfig.MIN_DONATION,
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
            bytes memory data = staticCall(
                getModuleAddress(ModuleConfig.ROLE_ACCESS),
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
        project.checkStatus(ProjectStatus.Created);
        project.status = ProjectStatus.Fundraising;
        emit ProjectUpdateStatus(projectId, ProjectStatus.Fundraising);
    }

    function pauseFundraising(
        uint64 projectId
    ) external onlyProjectOwner(projectId, PermissionType.UpdateStatus) {
        Project storage project = _getProject(projectId);
        project.checkStatus(ProjectStatus.Fundraising);
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
            if (nowTimestamp + ProjectConfig.BUFFER_TIME > deadline) {
                if (amountRaised < goal) {
                    newStatus = ProjectStatus.Failed;
                } else {
                    newStatus = ProjectStatus.Successful;
                }
            }
        } else if (
            oldStatus == ProjectStatus.Successful &&
            project.amountRaised == ProjectConfig.MIN_DONATION
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
        project.checkStatus1(ProjectStatus.Created, ProjectStatus.Fundraising);
        project.status = ProjectStatus.Cancelled;
        emit ProjectUpdateStatus(projectId, ProjectStatus.Cancelled);
    }

    function donate(
        uint64 projectId,
        uint96 msgValue,
        uint64 timestamp
    ) external onlyAuthorizedContract(ModuleConfig.FUND_MANAGER) {
        if (msgValue == ProjectConfig.MIN_DONATION) revert DonationTooSmall();
        Project storage project = _getProject(projectId);
        project.checkStatus(ProjectStatus.Fundraising);
        if (timestamp + ProjectConfig.BUFFER_TIME > project.deadline) {
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
    ) external onlyAuthorizedContract(ModuleConfig.FUND_MANAGER) {
        Project storage project = _getProject(projectId);
        project.amountRaised = ProjectConfig.MIN_DONATION;
        updateProjectStatus(projectId);
        emit ProjectUpdateStatus(projectId, project.status);
    }

    function refund(
        uint64 projectId,
        uint96 amount
    ) external onlyAuthorizedContract(ModuleConfig.FUND_MANAGER) {
        Project storage project = _getProject(projectId);
        unchecked {
            project.amountRaised -= amount;
        }
    }
}
