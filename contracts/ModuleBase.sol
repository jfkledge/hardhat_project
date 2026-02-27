// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import 'hardhat/console.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import './libs/AssembleUtils.sol';
import './interfaces/IModuleBase.sol';
import './libs/ModuleConfig.sol';

abstract contract ModuleBase is
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IModuleBase
{
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;
    //mapping from module address to ModuleInfo
    mapping(address => ModuleInfo) internal modules;
    //mapping from module name hash to module address
    mapping(bytes32 => address) private _moduleNameToAddress;
    ModuleInfo[] private moduleList;

    function initialize() public virtual initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyRole(ADMIN_ROLE) {}

    function registerModule(
        address moduleAddress
    ) external virtual onlyRole(ADMIN_ROLE) whenNotPaused {
        AssembleUtils.checkAddressIsValid(moduleAddress);
        string memory name = IModuleBase(moduleAddress).getName();
        bytes32 nameHash = keccak256(bytes(name));

        if (modules[moduleAddress].moduleAddress != address(0)) revert AlreadySet();
        if (_moduleNameToAddress[nameHash] != address(0)) revert AlreadySet(); // Also check name hash to prevent name collision

        ModuleInfo memory info = ModuleInfo({ name: name, moduleAddress: moduleAddress });
        modules[moduleAddress] = info;
        _moduleNameToAddress[nameHash] = moduleAddress;
        //add to moduleList
        moduleList.push(info);
        emit registerModuleEvent(moduleAddress);
    }

    function unRegisterModule(
        address moduleAddress
    ) external virtual onlyRole(ADMIN_ROLE) whenNotPaused {
        AssembleUtils.checkAddressIsValid(moduleAddress);
        if (modules[moduleAddress].moduleAddress == address(0)) revert ModuleNotFound(); // Use new error

        string memory name = modules[moduleAddress].name;
        bytes32 nameHash = keccak256(bytes(name));
        delete modules[moduleAddress];
        delete _moduleNameToAddress[nameHash];

        uint length = moduleList.length;
        uint256 indexToRemove = type(uint256).max; // Sentinel value
        for (uint256 i = 0; i < length; i++) {
            if (moduleList[i].moduleAddress == moduleAddress) {
                indexToRemove = i;
                break;
            }
        }
        if (indexToRemove == type(uint256).max) revert ModuleNotFound(); // Should not happen if modules[moduleAddress] was not address(0)
        // If the module is not the last one, swap it with the last element
        if (indexToRemove != length - 1) {
            moduleList[indexToRemove] = moduleList[length - 1];
            // If using _moduleListIndex:
            // _moduleListIndex[moduleList[indexToRemove].moduleAddress] = indexToRemove;
        }
        // Remove the last element (which is either the original element or the swapped element)
        moduleList.pop();
        // delete _moduleListIndex[moduleAddress]; // If using index mapping
        emit unRegisterModuleEvent(name, moduleAddress);
    }

    function getModuleAddress(string memory name) internal view returns (address moduleAddress) {
        bytes32 nameHash = keccak256(bytes(name));
        return _moduleNameToAddress[nameHash];
    }

    /**
        only trusted module can call
     */
    modifier onlyAuthorizedContract(string memory name) {
        address contractAddress = getModuleAddress(name);
        if (msg.sender != contractAddress) revert UnauthorizedCaller();
        _;
    }

    function getAllModules() external view returns (ModuleInfo[] memory) {
        return moduleList;
    }

    function _callAssembly(
        uint callType,
        address moduleAddress,
        string memory signature,
        bytes memory params,
        uint256 value
    ) private returns (bytes memory) {
        address target = modules[moduleAddress].moduleAddress;
        if (target == address(0)) revert NotSet(); // Ensure module is registered and active
        bytes4 selector = bytes4(keccak256(bytes(signature)));
        return AssembleUtils.callAssembly(callType, target, selector, params, value);
    }

    /**
      only read
     */
    function staticCall(
        address moduleAddress,
        string memory signature,
        bytes memory params
    ) internal returns (bytes memory) {
        return _callAssembly(2, moduleAddress, signature, params, 0);
    }

    function delegateCall(
        address moduleAddress,
        string memory signature,
        bytes memory params,
        uint256 value
    ) internal returns (bytes memory) {
        return _callAssembly(1, moduleAddress, signature, params, value);
    }

    function call(
        address moduleAddress,
        string memory signature,
        bytes memory params
    ) internal returns (bytes memory) {
        return _callAssembly(0, moduleAddress, signature, params, 0);
    }

    receive() external payable virtual {
        revert('not support receive ether');
    }

    fallback() external payable virtual {
        revert('not support fallback function');
    }
}
