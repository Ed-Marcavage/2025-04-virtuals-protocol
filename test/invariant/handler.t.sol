// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/virtualPersona/AgentToken.sol";
import "../mocks/ERC20Mock.sol";
import {MockUniswapRouter} from "./mocks/MockUniswapRouter.sol";

contract AgentTokenHandler is Test {
    AgentToken public token;
    ERC20Mock public pairToken;
    MockUniswapRouter public router;

    address public taxRecipient;
    address public vault;
    address[] public actors;

    // Ghost variables to track state
    uint256 public ghost_totalTaxCollected;
    uint256 public ghost_totalAutoSwaps;

    constructor(
        AgentToken _token,
        ERC20Mock _pairToken,
        MockUniswapRouter _router,
        address _taxRecipient,
        address _vault
    ) {
        token = _token;
        pairToken = _pairToken;
        router = _router;
        taxRecipient = _taxRecipient;
        vault = _vault;

        // Create some actors
        for (uint i = 0; i < 5; i++) {
            actors.push(makeAddr(string(abi.encodePacked("actor", i))));
        }
    }

    function buyTokens(uint256 actorSeed, uint256 amount) public {
        amount = bound(amount, 1e18, 10000e18); // Reasonable buy amounts
        address actor = actors[actorSeed % actors.length];
        address pairAddress = token.uniswapV2Pair();

        // Simulate LP providing tokens
        vm.startPrank(pairAddress);
        token.transfer(actor, amount);
        ghost_totalTaxCollected +=
            (amount * token.projectBuyTaxBasisPoints()) /
            10000;

        // try token.transfer(actor, amount) {
        //     ghost_totalTaxCollected +=
        //         (amount * token.projectBuyTaxBasisPoints()) /
        //         10000;
        // } catch {}
        vm.stopPrank();
    }

    function sellTokens(uint256 actorSeed, uint256 amount) public {
        address actor = actors[actorSeed % actors.length];
        uint256 balance = token.balanceOf(actor);
        amount = bound(amount, 0, balance);

        if (amount > 0) {
            vm.startPrank(actor);
            token.transfer(token.uniswapV2Pair(), amount);
            ghost_totalTaxCollected +=
                (amount * token.projectSellTaxBasisPoints()) /
                10000;

            // try token.transfer(token.uniswapV2Pair(), amount) {
            //     ghost_totalTaxCollected +=
            //         (amount * token.projectSellTaxBasisPoints()) /
            //         10000;
            // } catch {}
            vm.stopPrank();
        }
    }

    function adjustSwapThreshold(uint16 threshold) public {
        threshold = uint16(bound(threshold, 1, 1000)); // 0.01% to 10%

        vm.startPrank(token.owner());
        token.setSwapThresholdBasisPoints(threshold);
        vm.stopPrank();
    }

    function adjustTaxRates(uint16 buyRate, uint16 sellRate) public {
        buyRate = uint16(bound(buyRate, 0, 1000)); // Max 10%
        sellRate = uint16(bound(sellRate, 0, 1000)); // Max 10%

        vm.startPrank(token.owner());
        token.setProjectTaxRates(buyRate, sellRate);
        vm.stopPrank();
    }

    function distributeTaxTokens() public {
        token.distributeTaxTokens();
    }

    function transferTokens(
        uint256 fromSeed,
        uint256 toSeed,
        uint256 amount
    ) public {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];

        if (from != to) {
            uint256 balance = token.balanceOf(from);
            amount = bound(amount, 0, balance);

            if (amount > 0) {
                vm.startPrank(from);
                try token.transfer(to, amount) {} catch {}
                vm.stopPrank();
            }
        }
    }

    // function transferTokens(
    //     uint256 fromSeed,
    //     uint256 toSeed,
    //     uint256 amount
    // ) public {
    //     address from = actors[fromSeed % actors.length];
    //     address to = actors[toSeed % actors.length];

    //     if (from != to) {
    //         uint256 balance = token.balanceOf(from);
    //         amount = bound(amount, 0, balance);

    //         if (amount > 0) {
    //             vm.startPrank(from);
    //             try token.transfer(to, amount) {} catch {}
    //             vm.stopPrank();
    //         }
    //     }
    // }

    // function distributeTaxTokens() public {
    //     try token.distributeTaxTokens() {} catch {}
    // }

    // function adjustTaxRates(uint16 buyRate, uint16 sellRate) public {
    //     buyRate = uint16(bound(buyRate, 0, 1000)); // Max 10%
    //     sellRate = uint16(bound(sellRate, 0, 1000)); // Max 10%

    //     vm.startPrank(token.owner());
    //     try token.setProjectTaxRates(buyRate, sellRate) {} catch {}
    //     vm.stopPrank();
    // }

    // function adjustSwapThreshold(uint16 threshold) public {
    //     threshold = uint16(bound(threshold, 1, 1000)); // 0.01% to 10%

    //     vm.startPrank(token.owner());
    //     try token.setSwapThresholdBasisPoints(threshold) {} catch {}
    //     vm.stopPrank();
    // }

    // // Fund actors from vault occasionally
    // function fundActor(uint256 actorSeed, uint256 amount) public {
    //     address actor = actors[actorSeed % actors.length];
    //     amount = bound(amount, 1e18, 10000e18);

    //     uint256 vaultBalance = token.balanceOf(vault);
    //     if (vaultBalance >= amount) {
    //         vm.startPrank(vault);
    //         try token.transfer(actor, amount) {} catch {}
    //         vm.stopPrank();
    //     }
    // }
}
