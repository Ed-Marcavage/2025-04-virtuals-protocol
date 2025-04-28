// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../mocks/ERC20Mock.sol";

contract MockUniswapFactory {
    // Map token pairs to their LP token
    mapping(address => mapping(address => address)) private _pairs;

    function setPair(address tokenA, address tokenB, address lpToken) external {
        _pairs[tokenA][tokenB] = lpToken;
        _pairs[tokenB][tokenA] = lpToken; // Ensure order doesn't matter
    }

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address) {
        return _pairs[tokenA][tokenB];
    }

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address) {
        // In a real implementation, this would deploy a new pair contract
        // For mock purposes, we'd just set it in our mapping
        ERC20Mock newPair = new ERC20Mock();
        address pairAddress = address(newPair);

        _pairs[tokenA][tokenB] = pairAddress;
        _pairs[tokenB][tokenA] = pairAddress;

        return pairAddress;
    }
}
