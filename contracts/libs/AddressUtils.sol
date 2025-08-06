// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

library AddressUtils {
    error InvalidAddress();

    /**
      check addr is invalid
     */
    function checkAddressIsValid(address addr) internal view {
        if (addr == address(0)) revert InvalidAddress();
        if (addr.code.length <= 0) revert InvalidAddress();
    }
}
