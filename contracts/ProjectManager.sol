// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import './ModuleBase.sol';

contract ProjectManager is ModuleBase {
    uint64 public nextProjectId;
    mapping(uint64 => Project) public projects;
    mapping(address => uint64[]) public creatorProjects;

    event ProjectCreated(
        uint64 indexed projectId,
        address indexed creator,
        uint96 goal,
        uint64 deadline
    );
    event ProjectUpdateStatus(uint64 indexed projectId, ProjectStatus status);

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
                ModuleNames.ROLE_ACCESS_HASH,
                'hasPermission(uint64,PermissionType,address)',
                abi.encode(projectId, permission, currentMsgSender)
            );
            bool result = abi.decode(data, (bool));
            if (!result) revert NotProjectOwner();
            _;
        }
    }

    //update project status
    function updateProjectStatus(
        uint64 projectId
    ) public onlyProjectOwner(projectId, PermissionType.UpdateStatus) {
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
            if (nowTimestamp + ModuleNames.BUFFER_TIME > deadline && amountRaised < goal) {
                newStatus = ProjectStatus.Failed;
            } else if (amountRaised >= goal) {
                newStatus = ProjectStatus.Successful;
            }
        } else if (
            (oldStatus == ProjectStatus.Failed || oldStatus == ProjectStatus.Claimed) &&
            project.amountRaised == ModuleNames.MIN_DONATION
        ) {
            newStatus = ProjectStatus.Ended;
        }
        if (newStatus != oldStatus) {
            project.status = newStatus;
            emit ProjectUpdateStatus(projectId, newStatus);
        }
    }

    function setProjectAmountRaised(uint64 proejctId, uint96 amount) external onlyTrustedModule {
        Project storage project = _getProject(proejctId);
        project.amountRaised += amount;
        emit ProjectUpdateStatus(proejctId, project.status);
    }

    function clearProjectAmoutRaised(uint64 projectId) external onlyTrustedModule {
        Project storage project = _getProject(projectId);
        project.amountRaised = ModuleNames.MIN_DONATION;
        project.status = ProjectStatus.Claimed;
        emit ProjectUpdateStatus(projectId, project.status);
    }

    function cancelProject(
        uint64 projectId
    ) external onlyProjectOwner(projectId, PermissionType.Cancel) {
        Project storage project = _getProject(projectId);
        ProjectStatus oldStatus = project.status;
        if (oldStatus != ProjectStatus.Created && oldStatus != ProjectStatus.Fundraising) {
            revert NotInStatus(ProjectStatus.Created, oldStatus);
        }
        if (project.amountRaised != ModuleNames.MIN_DONATION) revert AlreadyRaisedFunds();
        project.status = ProjectStatus.Cancelled;
        emit ProjectUpdateStatus(projectId, ProjectStatus.Cancelled);
    }

    function refund(uint64 projectId, uint96 amount) external onlyTrustedModule {
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

    function getProjectCreator(uint64 projectId) external view returns (address) {
        return _getProject(projectId).creator;
    }

    function getProjectDetail(uint64 projectId) external view returns (Project memory) {
        Project memory project = projects[projectId];
        if (project.status == ProjectStatus.Uninitialized) {
            revert ProjectNotFound();
        }
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
