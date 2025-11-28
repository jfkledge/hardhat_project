// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;
import { ProjectStatus } from '../ProjectEnum.sol';
interface IModuleBaseError {
    error AlreadySet();
    error NotSet();
    error CallFailed();
    error UnauthorizedCaller();
}

interface IProjectManagerError {
    error InvalidGoal();
    error InvalidDeadline();
    error NotProjectOwner();
    error NotInStatus(ProjectStatus expected, ProjectStatus actual);
    error ProjectNotFound();
    error ProjectDeadlinePassed();
    error DonationTooSmall();
}

interface IFundManagerError {
    error NoDonationToRefund();
    error ClaimFailed();
    error RefundFailed();
}
