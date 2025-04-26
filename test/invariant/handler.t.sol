// test/AgentTokenHandler.sol
pragma solidity ^0.8.20;

import "../../contracts/virtualPersona/AgentToken.sol";
import "../mocks/ERC20Mock.sol";
import "forge-std/Test.sol";

contract AgentTokenHandler is Test {
    AgentToken public immutable token;
    ERC20Mock public immutable pairToken;

    address[] internal actors;

    constructor(AgentToken _token, ERC20Mock _pair, address[] memory _actors) {
        token = _token;
        pairToken = _pair;
        actors = _actors;
    }

    /* --------------- actions that Foundry will fuzz --------------- */

    // random ERC-20 transfer between two funded holders
    function act_transfer(
        uint256 fromIdx,
        uint256 toIdx,
        uint256 amt
    ) external {
        address from = actors[fromIdx % actors.length];
        address to = actors[toIdx % actors.length];
        uint256 max = token.balanceOf(from);
        if (max == 0) return;
        uint256 send = bound(amt, 1, max);

        vm.prank(from);
        token.transfer(to, send);
    }

    // call the public “escape hatch” that pays tax in-kind
    function act_distributeTaxTokens() external {
        token.distributeTaxTokens();
    }
}
