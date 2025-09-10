// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import './ModuleBase.sol';

contract FundManager is ModuleBase {
    event ProjectClaimFunds(uint64 indexed projectId, address indexed creator, uint96 amountRaised);
    event ProjectDonate(uint64 indexed projectId, address indexed user, uint96 amount);
    event ProjectRefund(uint64 indexed projectId, address indexed user, uint96 amount);

    uint96 private constant MIN_DONATION = 0;
    //ervery projectId mapping (user mapping donate count)
    mapping(uint64 => mapping(address => uint96)) public contributions;
    //erery user mapping DonationRecord array
    mapping(address => DonationRecord[]) public userDonations;
    //erery projectId mapping users array
    mapping(uint64 => address[]) private projectDonors;
    //every proejctId mapping (user mapping isDonated)
    mapping(uint64 => mapping(address => bool)) private hasDonatedToProject;

    function getName() external pure returns (string memory) {
        return ModuleNames.FUND_MANAGER;
    }

    modifier onlyProjectOwner(uint64 projectId, PermissionType permission) {
        bytes memory data = callModuleView(
            getModuleAddress(ModuleNames.PROJECT_MANAGER),
            'getProjectCreator(uint64)',
            abi.encode(projectId)
        );
        address projectCreator = abi.decode(data, (address));
        address currentMsgSender = msg.sender;
        if (currentMsgSender == projectCreator) {
            _;
        } else {
            bytes memory permissionData = callModuleView(
                getModuleAddress(ModuleNames.ROLE_ACCESS),
                'hasPermission(uint64,PermissionType,address)',
                abi.encode(projectId, permission, currentMsgSender)
            );
            bool result = abi.decode(permissionData, (bool));
            if (!result) revert NotProjectOwner();
            _;
        }
    }

    /**
     * donate project by projectId
     */
    function donate(uint64 projectId) external payable {
        bytes memory data = callModuleView(
            getModuleAddress(ModuleNames.PROJECT_MANAGER),
            'getProjectDetail(uint64)',
            abi.encode(projectId)
        );
        Project memory project = abi.decode(data, (Project));
        uint64 nowTimestamp = uint64(block.timestamp);
        if (nowTimestamp + ModuleNames.BUFFER_TIME > project.deadline)
            revert ProjectDeadlinePassed();
        if (msg.value > type(uint96).max) revert ValueTooLarge();
        uint96 msgValue = uint96(msg.value);
        if (msgValue == ModuleNames.MIN_DONATION) revert DonationTooSmall();
        // update project amountRaised
        callModuleView(
            getModuleAddress(ModuleNames.PROJECT_MANAGER),
            'setProjectAmountRaised(uint64,uint96)',
            abi.encode(projectId, msgValue)
        );

        contributions[projectId][msg.sender] += msgValue;
        //add every user donate record
        userDonations[msg.sender].push(
            DonationRecord({ projectId: projectId, amount: msgValue, timestamp: nowTimestamp })
        );
        if (!hasDonatedToProject[projectId][msg.sender]) {
            projectDonors[projectId].push(msg.sender);
            hasDonatedToProject[projectId][msg.sender] = true;
        }
        callModuleView(
            getModuleAddress(ModuleNames.PROJECT_MANAGER),
            'updateProjectStatus(uint64)',
            abi.encode(projectId)
        );
        emit ProjectDonate(projectId, msg.sender, msgValue);
    }

    /**
     * claimFund by projectId
     */
    function claimFunds(
        uint64 projectId
    ) external nonReentrant onlyProjectOwner(projectId, PermissionType.Withdraw) {
        bytes memory data = callModuleView(
            getModuleAddress(ModuleNames.PROJECT_MANAGER),
            'getProjectDetail(uint64)',
            abi.encode(projectId)
        );
        Project memory project = abi.decode(data, (Project));
        if (project.amountRaised == ModuleNames.MIN_DONATION) revert NoFundsToClaim();
        uint96 amount = project.amountRaised;
        //clean project amountRaised
        callModuleView(
            getModuleAddress(ModuleNames.PROJECT_MANAGER),
            'clearProjectAmoutRaised(uint64)',
            abi.encode(projectId)
        );
        (bool successful, ) = payable(msg.sender).call{ value: amount }('');
        if (!successful) revert ClaimFailed();
        emit ProjectClaimFunds(projectId, msg.sender, amount);
    }

    /**
     * refund by projectId
     */
    function refund(uint64 projectId) external nonReentrant {
        bytes memory data = callModuleView(
            getModuleAddress(ModuleNames.PROJECT_MANAGER),
            'getProjectDetail(uint64)',
            abi.encode(projectId)
        );
        Project memory project = abi.decode(data, (Project));
        if (project.status != ProjectStatus.Failed) {
            revert NotInStatus(ProjectStatus.Failed, project.status);
        }
        uint96 amount = contributions[projectId][msg.sender];
        if (amount == MIN_DONATION) revert NoDonationToRefund();
        contributions[projectId][msg.sender] = MIN_DONATION;
        callModuleView(
            getModuleAddress(ModuleNames.PROJECT_MANAGER),
            'refund(uint64,uint96)',
            abi.encode(projectId, amount)
        );
        (bool successful, ) = payable(msg.sender).call{ value: amount }('');
        if (!successful) revert RefundFailed();
        emit ProjectRefund(projectId, msg.sender, amount);
    }

    function getContribution(uint64 projectId, address user) external view returns (uint96) {
        return contributions[projectId][user];
    }

    function getDonationHistory(address user) external view returns (DonationRecord[] memory) {
        return userDonations[user];
    }

    function getProjectDonors(uint64 projectId) external view returns (address[] memory) {
        return projectDonors[projectId];
    }

    function getProjectDonorCount(uint64 projectId) external view returns (uint256) {
        return projectDonors[projectId].length;
    }
}
