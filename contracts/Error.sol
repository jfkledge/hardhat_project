// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;
import './ProjectEnum.sol';

error NotInStatus(ProjectStatus expected, ProjectStatus actual);
error InvalidGoal();
error InvalidDeadline();
error AlreadyRaisedFunds();
error DonationTooSmall();
error ProjectNotFound();
error ProjectDeadlinePassed();
error NoFundsToClaim();
error RefundNotAvailable();
error NoDonationToRefund();
error ClaimFailed();
error RefundFailed();
error ValueTooLarge();
error AlreadySet();
error NotSet();
error NotProjectOwner();
error CallFailed();
error UnRegisteredModule();
