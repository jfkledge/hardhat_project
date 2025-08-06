// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import 'hardhat/console.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import './Error.sol';
import './libs/AddressUtils.sol';
import './IModule.sol';
import { ModuleNames } from './libs/ModuleNames.sol';

abstract contract ModuleBase is
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    IModule
{
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;
    using AddressUtils for address;
    mapping(bytes32 => ModuleInfo) internal modules;
    ModuleInfo[] private moduleList;
    mapping(address => bool) public trustedModules;

    event registerModuleEvent(address indexed _contractAddress);
    event unRegisterModuleEvent(string indexed name, address indexed _oldAddress);
    event updateModuleEvent(
        string indexed name,
        address indexed newAddress,
        address indexed oldAddress
    );

    struct ModuleInfo {
        string name;
        address moduleAddress;
    }

    function initialize() public virtual initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyRole(ADMIN_ROLE) {}

    modifier onlyTrustedModule() {
        if (!trustedModules[msg.sender]) revert('Unauthorized caller');
        _;
    }

    function registerModule(address module) external virtual onlyRole(ADMIN_ROLE) {
        string memory name = IModule(module).getName();
        bytes32 flag = keccak256(bytes(name));
        if (modules[flag].moduleAddress != address(0)) revert AlreadySet();
        module.checkAddressIsValid();
        ModuleInfo memory info = ModuleInfo({ name: name, moduleAddress: module });
        modules[flag] = info;
        moduleList.push(info);
        trustedModules[module] = true;
        emit registerModuleEvent(module);
    }

    function unRegisterModule(string memory name) external virtual onlyRole(ADMIN_ROLE) {
        bytes32 flag = keccak256(bytes(name));
        ModuleInfo storage moduleInfo = modules[flag];
        address oldAddress = moduleInfo.moduleAddress;
        if (oldAddress == address(0)) revert UnRegisteredModule();
        moduleInfo.moduleAddress = address(0);
        uint length = moduleList.length;
        for (uint i = 0; i < length; i++) {
            if (keccak256(bytes(moduleList[i].name)) == flag) {
                moduleList[i].moduleAddress = address(0);
                break;
            }
        }
        emit unRegisterModuleEvent(name, oldAddress);
    }

    function updateModule(
        string memory name,
        address newAddress
    ) external virtual onlyRole(ADMIN_ROLE) {
        bytes32 flag = keccak256(bytes(name));
        ModuleInfo storage moduleInfo = modules[flag];
        address oldAddress = moduleInfo.moduleAddress;
        newAddress.checkAddressIsValid();
        moduleInfo.moduleAddress = newAddress;
        uint length = moduleList.length;
        for (uint i = 0; i < length; i++) {
            if (keccak256(bytes(moduleList[i].name)) == flag) {
                moduleList[i].moduleAddress = newAddress;
                break;
            }
        }
        emit updateModuleEvent(name, newAddress, oldAddress);
    }

    function getModule(bytes32 flag) internal view virtual returns (address) {
        address module = modules[flag].moduleAddress;
        if (module == address(0)) revert NotSet();
        return module;
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
        bytes32 moduleFlag,
        string memory signature,
        bytes memory params,
        uint256 value
    ) private returns (bytes memory) {
        address target = getModule(moduleFlag);
        bytes4 selector = bytes4(keccak256(bytes(signature)));
        return callAssembly(callType, target, selector, params, value);
    }

    /**
      only read
     */
    function callModuleView(
        bytes32 moduleFlag,
        string memory signature,
        bytes memory params
    ) internal returns (bytes memory) {
        return _callAssembly(3, moduleFlag, signature, params, 0);
    }

    function callModule(
        bytes32 moduleFlag,
        string memory signature,
        bytes memory params,
        uint256 value
    ) internal returns (bytes memory) {
        return _callAssembly(1, moduleFlag, signature, params, value);
    }

    receive() external payable virtual {
        revert('not support receive ether');
    }

    fallback() external payable virtual {
        revert('not support fallback function');
    }
}
