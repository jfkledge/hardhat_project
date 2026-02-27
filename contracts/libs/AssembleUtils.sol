// contracts/Constants.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

library AssembleUtils {
    error InvalidAddress();
    error NotContractAddress();

    function checkAddressIsValid(address addr) internal view {
        if (addr == address(0)) revert InvalidAddress();
        // Check if the address is a contract by inspecting its code length
        if (addr.code.length <= 0) revert NotContractAddress();
    }

    function callAssembly(
        uint callType, //0.call 1.delegatecall 2.staticcall
        address targetAddress,
        bytes4 selector,
        bytes memory params,
        uint256 value
    ) external returns (bytes memory result) {
        checkAddressIsValid(targetAddress);
        assembly {
            // Get the current free memory pointer, which points to the next available memory location.
            let ptr := mload(0x40)
            // Store the function selector (4 bytes) at the free memory pointer.
            // This is the start of our calldata
            mstore(ptr, selector)
            // Get the length of the 'params' bytes array.
            let len := mload(params)
             // Get the data pointer of 'params' (skipping the first 0x20 bytes which store length).
            let dataPtr := add(params, 0x20)
            // Copy the 'params' data after the selector in memory.
            // Loop through the 'params' in 32-byte chunks.
            for {
                let i := 0
            } lt(i, len) {
                i := add(i, 0x20)
            } {
                // Store each 32-byte chunk of 'params' data into memory,
                // starting 4 bytes after 'ptr' (to account for the selector).
                mstore(add(ptr, add(0x04, i)), mload(add(dataPtr, i)))
            }

            // Calculate the total calldata length: 4 bytes for selector + length of params.
            let totalLen := add(0x04, len)
            // Flag to store the success of the call operation
            let success := 0
            // Execute the call based on the specified callType.
            switch callType
            case 0 {
                // call(gas, address, value, in_offset, in_size, out_offset, out_size)
                // Forwards all remaining gas, calls targetAddress with 'value',
                // using calldata from 'ptr' of 'totalLen', and stores returndata at 0 for now.
                success := call(gas(), targetAddress, value, ptr, totalLen, 0, 0)
            }
            case 1 {
                // delegatecall(gas, address, in_offset, in_size, out_offset, out_size)
                // Forwards all remaining gas, calls targetAddress (preserving context),
                // using calldata from 'ptr' of 'totalLen', and stores returndata at 0.
                success := delegatecall(gas(), targetAddress, ptr, totalLen, 0, 0)
            }
            case 2 {
                // staticcall(gas, address, in_offset, in_size, out_offset, out_size)
                // Forwards all remaining gas, calls targetAddress (read-only),
                // using calldata from 'ptr' of 'totalLen', and stores returndata at 0.
                success := staticcall(gas(), targetAddress, ptr, totalLen, 0, 0)
            }
            // After the call, retrieve the size of the returned data
            let size := returndatasize()
            // Set 'result' to the current free memory pointer.
            result := mload(0x40)
            // Update the free memory pointer to beyond the returned data, plus 0x20 for length.
            mstore(0x40, add(result, add(size, 0x20)))
            // Store the size of the returned data at the beginning of the 'result' memory block.
            mstore(result, size)
            // Copy the returned data from the returndata buffer (starting at 0)
            // into the memory location pointed to by (result + 0x20).
            returndatacopy(add(result, 0x20), 0, size)
            // If the call was not successful (i.e., it reverted), then revert with the returned data
            if iszero(success) {
                // Revert with the error message/data that was returned by the failed call.
                // The data starts at (result + 0x20) and has 'size'.
                revert(add(result, 0x20), size)
            }
        }
        return result;
    }
}
