// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import './ModuleBase.sol';
import './interfaces/IFundManager.sol';
import { DonationRecord, PermissionType, Project, ProjectStatus } from './ProjectEnum.sol';
import { IProjectManagerError, IFundManagerError } from './interfaces/IError.sol';

contract FundManager is ModuleBase, IFundManager, IProjectManagerError, IFundManagerError {
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
            'getProjectDetail(uint64)',
            abi.encode(projectId)
        );
        Project memory project = abi.decode(data, (Project));
        address currentMsgSender = msg.sender;
        if (currentMsgSender == project.creator) {
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
        uint64 currentTime = uint64(block.timestamp);
        uint96 msgValue = uint96(msg.value);
        // update project amountRaised
        callModuleView(
            getModuleAddress(ModuleNames.PROJECT_MANAGER),
            'donate(uint64,uint96,uint64)',
            abi.encode(projectId, msgValue, currentTime)
        );
        address currentMsgSender = msg.sender;
        unchecked {
            contributions[projectId][currentMsgSender] += msgValue;
        }
        //add every user donate record
        userDonations[currentMsgSender].push(
            DonationRecord({ projectId: projectId, amount: msgValue, timestamp: currentTime })
        );
        if (!hasDonatedToProject[projectId][currentMsgSender]) {
            projectDonors[projectId].push(currentMsgSender);
            hasDonatedToProject[projectId][currentMsgSender] = true;
        }
        emit ProjectDonate(projectId, currentMsgSender, msgValue);
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
        if (project.status != ProjectStatus.Successful) {
            revert NotInStatus(ProjectStatus.Successful, project.status);
        }
        uint96 amount = project.amountRaised;
        //clean project amountRaised
        callModuleView(
            getModuleAddress(ModuleNames.PROJECT_MANAGER),
            'claimFunds(uint64)',
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
        if (project.status != ProjectStatus.Failed && project.status != ProjectStatus.Cancelled) {
            revert NotInStatus(ProjectStatus.Failed, project.status);
        }
        uint96 amount = contributions[projectId][msg.sender];
        if (amount == ModuleNames.MIN_DONATION) revert NoDonationToRefund();
        contributions[projectId][msg.sender] = ModuleNames.MIN_DONATION;
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
