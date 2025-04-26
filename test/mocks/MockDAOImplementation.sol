// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/IGovernor.sol";

// Mock implementation for Agent DAO
contract MockDAOImplementation {
    string public name;
    IVotes public token;
    address public nft;
    uint256 public proposalThreshold;
    uint32 public votingPeriod;

    function initialize(
        string memory _name,
        IVotes _token,
        address _nft,
        uint256 _proposalThreshold,
        uint32 _votingPeriod
    ) external {
        name = _name;
        token = _token;
        nft = _nft;
        proposalThreshold = _proposalThreshold;
        votingPeriod = _votingPeriod;
    }
}

// Mock interface for IVotes
interface IVotes {
    function getPastVotes(
        address account,
        uint256 blockNumber
    ) external view returns (uint256);

    function delegate(address delegatee) external;
}
