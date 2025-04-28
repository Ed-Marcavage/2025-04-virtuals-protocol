// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../mocks/ERC20Mock.sol";
import "../../../contracts/pool/IUniswapV2Factory.sol";

contract MockUniswapRouter {
    address private _factory;

    function setFactory(address factory_) external {
        _factory = factory_;
    }

    function factory() external view returns (address) {
        return _factory;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        // Get the LP token from the factory
        address lpToken = IUniswapV2Factory(_factory).getPair(tokenA, tokenB);

        // Actually transfer the tokens from their sources
        IERC20(tokenA).transferFrom(msg.sender, lpToken, amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, lpToken, amountBDesired);

        // Mint LP tokens to the recipient
        ERC20Mock(lpToken).mint(to, amountADesired);

        return (amountADesired, amountBDesired, amountADesired);
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        // Actually transfer tokens from the caller to this router
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

        // Then transfer pair tokens to the recipient
        // In a real scenario, this would be calculated based on the pool state
        // For testing, we'll just send the same amount of pair tokens
        ERC20Mock(path[1]).mint(to, amountIn);

        uint[] memory result = new uint[](path.length);
        result[0] = amountIn;
        result[1] = amountIn;
        return result;
    }
}
