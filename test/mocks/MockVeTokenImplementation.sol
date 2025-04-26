// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Mock implementation for Agent VeToken
contract MockVeTokenImplementation {
    address public stakingAsset;
    address public founder;
    uint256 public unlockTime;
    address public nftAddress;
    bool public canStake;

    function initialize(
        string memory name,
        string memory symbol,
        address _founder,
        address _stakingAsset,
        uint256 _unlockTime,
        address _nftAddress,
        bool _canStake
    ) external {
        stakingAsset = _stakingAsset;
        founder = _founder;
        unlockTime = _unlockTime;
        nftAddress = _nftAddress;
        canStake = _canStake;
    }

    function stake(
        uint256 amount,
        address recipient,
        address delegatee
    ) external {
        // Mock implementation - doesn't actually do anything except satisfy the interface
        // In a real implementation, this would transfer tokens from msg.sender and mint veTokens
    }
}
