// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgentToken.sol"; // <- path to the contract under test

/*  -------------------------------------------------------------
 *  ─────────────  Ultra-light mocks for external deps ──────────
 *  -----------------------------------------------------------*/

contract MockERC20 is IERC20 {
    string public override name;
    string public override symbol;
    uint8 public override decimals = 18;

    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor(string memory _n, string memory _s) {
        name = _n;
        symbol = _s;
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function _mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/* ---------- V2 factory / pair / router stubs (just what AgentToken touches) ---------- */

contract MockPair {
    address public token0;
    address public token1;

    constructor(address a, address b) {
        token0 = a;
        token1 = b;
    }
}

contract MockFactory is IUniswapV2Factory {
    address public lastCreatedPair;

    function getPair(
        address a,
        address b
    ) external view override returns (address) {
        // return 0 to force AgentToken to call createPair()
        return address(0);
    }

    function createPair(
        address a,
        address b
    ) external override returns (address pair) {
        pair = address(new MockPair(a, b));
        lastCreatedPair = pair;
    }
}

contract MockRouter is IUniswapV2Router02 {
    address public immutable override factory;
    MockERC20 public immutable pairToken;

    constructor(address _factory, MockERC20 _pairToken) {
        factory = _factory;
        pairToken = _pairToken;
    }

    /* Only the two methods AgentToken actually calls are stubbed.
       They just succeed and return deterministic dummy values. */

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint /*amountAMin*/,
        uint /*amountBMin*/,
        address to,
        uint /*deadline*/
    ) external override returns (uint amountA, uint amountB, uint liquidity) {
        // pretend we used everything that was sent in
        amountA = amountADesired;
        amountB = amountBDesired;
        liquidity = 1_000 ether;
        // mint the LP tokens straight to caller for simplicity
        MockERC20(tokenA)._mint(to, liquidity);
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint /*amountIn*/,
        uint /*amountOutMin*/,
        address[] calldata /*path*/,
        address /*to*/,
        uint /*deadline*/
    ) external override {
        /* do nothing - succeed */
    }
}

/*  -------------------------------------------------------------
 *  ─────────────────────────  The test  ────────────────────────
 *  -----------------------------------------------------------*/

contract AgentTokenTest is Test {
    /* ---------- state ---------- */
    AgentToken token;
    MockERC20 pair;
    MockFactory uniFactory;
    MockRouter uniRouter;

    address owner = makeAddr("owner");
    address vault = makeAddr("vault");
    address trader = makeAddr("trader");

    /* ---------- setUp ---------- */
    function setUp() public {
        vm.startPrank(owner); // all deployments from project owner

        pair = new MockERC20("PAIR", "PR");
        pair._mint(owner, 1_000_000 ether); // give owner a pile for LP

        uniFactory = new MockFactory();
        uniRouter = new MockRouter(address(uniFactory), pair);

        // ---------- craft AgentToken constructor params ----------
        bytes memory base = abi.encode("AgentToken", "AGT");

        AgentToken.ERC20SupplyParameters memory sp = AgentToken
            .ERC20SupplyParameters({
                maxSupply: 1_000_000,
                vaultSupply: 300_000,
                lpSupply: 700_000,
                vault: vault,
                botProtectionDurationInSeconds: 600
            });
        bytes memory supply = abi.encode(sp);

        AgentToken.ERC20TaxParameters memory tp = AgentToken
            .ERC20TaxParameters({
                projectBuyTaxBasisPoints: 0,
                projectSellTaxBasisPoints: 0,
                taxSwapThresholdBasisPoints: 100, // 1 %
                projectTaxRecipient: owner
            });
        bytes memory tax = abi.encode(tp);

        address[3] memory integrations = [
            owner, // projectOwner_
            address(uniRouter), // uniswap router
            address(pair) // pair token
        ];

        // ---------- deploy & initialize ----------
        token = new AgentToken();
        token.initialize(integrations, base, supply, tax);

        // move the LP slice of tokens + some pair tokens into the AgentToken
        // contract so `addInitialLiquidity()` will succeed inside tests
        pair.transfer(address(token), 500_000 ether);

        vm.stopPrank();
    }

    /* ---------- first smoke-test ---------- */
    function testInitialization() public {
        assertEq(token.name(), "AgentToken");
        assertEq(token.symbol(), "AGT");
        assertEq(token.owner(), owner);

        // entire supply minted?
        assertEq(token.totalSupply(), 1_000_000 * 1e18);

        // vault received its cut
        assertEq(token.balanceOf(vault), 300_000 * 1e18);

        // LP holdings are on the token contract itself until liquidity is added
        assertEq(token.balanceOf(address(token)), 700_000 * 1e18);

        // uni pair created lazily and cached
        assertTrue(token.uniswapV2Pair() != address(0));
    }
}
