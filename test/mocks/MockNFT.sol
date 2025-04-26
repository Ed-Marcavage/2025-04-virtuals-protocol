// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Mock implementation for Agent NFT
contract MockNFT {
    uint256 private _nextVirtualId = 1;
    mapping(uint256 => address) private _tbas;

    function nextVirtualId() external view returns (uint256) {
        return _nextVirtualId;
    }

    function mint(
        uint256 virtualId,
        address to,
        string memory tokenURI,
        address dao,
        address founder,
        uint8[] memory cores,
        address lp,
        address token
    ) external {
        _nextVirtualId = virtualId + 1;
        // Mock implementation - doesn't actually mint an NFT but satisfies the interface
    }

    function setTBA(uint256 virtualId, address tbaAddress) external {
        _tbas[virtualId] = tbaAddress;
    }
}
