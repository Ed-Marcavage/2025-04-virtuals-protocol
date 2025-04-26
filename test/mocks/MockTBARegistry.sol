// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Mock implementation for TBA Registry
contract MockTBARegistry {
    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address) {
        // Create a deterministic address based on inputs to simulate TBA creation
        address account = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            implementation,
                            salt,
                            chainId,
                            tokenContract,
                            tokenId
                        )
                    )
                )
            )
        );

        return account;
    }
}
