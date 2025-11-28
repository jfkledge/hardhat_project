// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import 'hardhat/console.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import { IModuleBaseError } from './interfaces/IError.sol';
import './libs/AddressUtils.sol';
import './interfaces/IModuleBase.sol';
import { ModuleNames } from './libs/ModuleNames.sol';

abstract contract ModuleBase is
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IModuleBase,
    IModuleBaseError
{
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;
    using AddressUtils for address;
    mapping(address => ModuleInfo) internal modules;
    ModuleInfo[] private moduleList;

    struct ModuleInfo {
        string name;
        address moduleAddress;
    }

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
        moduleAddress.checkAddressIsValid();
        string memory name = IModuleBase(moduleAddress).getName();
        if (modules[moduleAddress].moduleAddress != address(0)) revert AlreadySet();
        ModuleInfo memory info = ModuleInfo({ name: name, moduleAddress: moduleAddress });
        modules[moduleAddress] = info;
        moduleList.push(info);
        emit registerModuleEvent(moduleAddress);
    }

    function unRegisterModule(
        address moduleAddress
    ) external virtual onlyRole(ADMIN_ROLE) whenNotPaused {
        moduleAddress.checkAddressIsValid();
        uint length = moduleList.length;
        for (uint i = 0; i < length; i++) {
            if (moduleList[i].moduleAddress == moduleAddress) {
                modules[moduleAddress].moduleAddress = address(0);
                moduleList[i].moduleAddress = address(0);
                emit unRegisterModuleEvent(moduleList[i].name, moduleAddress);
                break;
            }
        }
    }

    function getModuleAddress(string memory name) internal view returns (address moduleAddress) {
        uint length = moduleList.length;
        for (uint i = 0; i < length; i++) {
            if (keccak256(bytes(moduleList[i].name)) == keccak256(bytes(name))) {
                return moduleList[i].moduleAddress;
            }
        }
        return address(0);
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

    function callAssembly(
        uint callType, //1.call 2.delegatecall 3.staticcall
        address targetAddress,
        bytes4 selector,
        bytes memory params,
        uint256 value
    ) public returns (bytes memory result) {
        targetAddress.checkAddressIsValid();
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, selector)

            let len := mload(params)
            let dataPtr := add(params, 0x20)

            for {
                let i := 0
            } lt(i, len) {
                i := add(i, 0x20)
            } {
                mstore(add(ptr, add(0x04, i)), mload(add(dataPtr, i)))
            }

            // total calldata length = 4 + len
            let totalLen := add(0x04, len)

            let success := 0
            switch callType
            case 0 {
                success := call(gas(), targetAddress, value, ptr, totalLen, 0, 0)
            }
            case 1 {
                success := delegatecall(gas(), targetAddress, ptr, totalLen, 0, 0)
            }
            case 2 {
                success := staticcall(gas(), targetAddress, ptr, totalLen, 0, 0)
            }
            let size := returndatasize()
            result := mload(0x40)
            mstore(0x40, add(result, add(size, 0x20)))
            mstore(result, size)
            returndatacopy(add(result, 0x20), 0, size)

            if iszero(success) {
                revert(add(result, 0x20), size)
            }
        }
        return result;
    }

    function _callAssembly(
        uint callType,
        address moduleAddress,
        string memory signature,
        bytes memory params,
        uint256 value
    ) private returns (bytes memory) {
        address target = modules[moduleAddress].moduleAddress;
        bytes4 selector = bytes4(keccak256(bytes(signature)));
        return callAssembly(callType, target, selector, params, value);
    }

    /**
      only read
     */
    function callModuleView(
        address moduleAddress,
        string memory signature,
        bytes memory params
    ) internal returns (bytes memory) {
        return _callAssembly(3, moduleAddress, signature, params, 0);
    }

    function callModule(
        address moduleAddress,
        string memory signature,
        bytes memory params,
        uint256 value
    ) internal returns (bytes memory) {
        return _callAssembly(1, moduleAddress, signature, params, value);
    }

    function callModuleDele(
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
