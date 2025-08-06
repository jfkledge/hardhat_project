// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import './ModuleBase.sol';

contract ProjectManager is ModuleBase {
    uint64 public nextProjectId;
    uint96 private constant MIN_DONATION = 0;
    uint256 private constant BUFFER_TIME = 900;
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
        if (goal == MIN_DONATION) revert InvalidGoal();
        if (deadline <= block.timestamp + BUFFER_TIME) revert InvalidDeadline();
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
            amountRaised: MIN_DONATION,
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
            if (nowTimestamp + BUFFER_TIME > deadline && amountRaised < goal) {
                newStatus = ProjectStatus.Failed;
            } else if (amountRaised >= goal) {
                newStatus = ProjectStatus.Successful;
            }
        } else if (
            (oldStatus == ProjectStatus.Failed || oldStatus == ProjectStatus.Claimed) &&
            project.amountRaised == MIN_DONATION
        ) {
            newStatus = ProjectStatus.Ended;
        }
        if (newStatus != oldStatus) {
            project.status = newStatus;
            emit ProjectUpdateStatus(projectId, newStatus);
        }
    }

    function beforeDonateHook(
        uint64 projectId
    ) external payable onlyTrustedModule returns (uint96, uint64) {
        Project storage project = _getProject(projectId);
        ProjectStatus status = project.status;
        if (status != ProjectStatus.Fundraising) {
            revert NotInStatus(ProjectStatus.Fundraising, status);
        }
        uint64 nowTimestamp = uint64(block.timestamp);
        if (nowTimestamp + BUFFER_TIME > project.deadline) revert ProjectDeadlinePassed();
        if (msg.value > type(uint96).max) revert ValueTooLarge();
        uint96 msgValue = uint96(msg.value);
        if (msgValue == MIN_DONATION) revert DonationTooSmall();
        project.amountRaised += msgValue;
        emit ProjectUpdateStatus(projectId, project.status);
        return (msgValue, nowTimestamp);
    }

    function beforeClaimFundsHook(uint64 projectId) external onlyTrustedModule returns (uint96) {
        Project storage project = _getProject(projectId);
        if (project.status != ProjectStatus.Successful) {
            revert NotInStatus(ProjectStatus.Successful, project.status);
        }
        uint96 amount = project.amountRaised;
        if (amount == MIN_DONATION) revert NoFundsToClaim();
        project.amountRaised = MIN_DONATION;
        project.status = ProjectStatus.Claimed;
        return amount;
    }

    function beforeRefundHook(uint64 projectId) external view {
        ProjectStatus status = _getProject(projectId).status;
        if (status != ProjectStatus.Failed) {
            revert NotInStatus(ProjectStatus.Failed, status);
        }
    }

    function refund(uint64 projectId, uint96 amount) external onlyTrustedModule {
        Project storage project = _getProject(projectId);
        unchecked {
            project.amountRaised -= amount;
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
        if (project.amountRaised != MIN_DONATION) revert AlreadyRaisedFunds();
        project.status = ProjectStatus.Cancelled;
        emit ProjectUpdateStatus(projectId, ProjectStatus.Cancelled);
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
