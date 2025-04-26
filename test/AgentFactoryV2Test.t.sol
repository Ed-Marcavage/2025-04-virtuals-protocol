import {Test, console2} from "forge-std/Test.sol";
import "../contracts/virtualPersona/AgentFactory.sol";
import "forge-std/console.sol";
import "./mocks/ERC20Mock.sol";
import "../contracts/virtualPersona/AgentToken.sol";

contract AgentFactoryV3Test is Test {
    // with in old did we not need two explicit proxy/implementation?
    AgentToken public agentTokenImplementation;
    AgentToken public agentTokenProxy;

    MockUniswapRouter public uniswapRouter;
    MockUniswapFactory public uniswapFactory;

    address public mockVault = address(0x6);
    address public mockProjectTaxRecipient = address(0x7);
    address public mockFactory = address(0x5);
    address public tokenAdmin = address(0x1);
    address public mockLpOwner = address(0x8);

    uint256 public constant MAX_SUPPLY = 1000000;
    uint256 public constant LP_SUPPLY = 500000;
    uint256 public constant VAULT_SUPPLY = 500000;
    uint256 public constant BOT_PROTECTION_DURATION = 300;
    uint256 public constant PROJECT_BUY_TAX_BASIS_POINTS = 200;
    uint256 public constant PROJECT_SELL_TAX_BASIS_POINTS = 300;
    uint256 public constant TAX_SWAP_THRESHOLD_BASIS_POINTS = 500;
    uint256 public constant MAX_TOKENS_PER_WALLET = 0;
    uint256 public constant MAX_TOKENS_PER_TXN = 0;
    address public constant PROJECT_TAX_RECIPIENT = address(0x9);

    function setUp() public {
        uniswapRouter = new MockUniswapRouter();
        uniswapFactory = new MockUniswapFactory();
        // Create the two tokens in the pair
        ERC20Mock pairToken = new ERC20Mock(); // One side of the pair (e.g., USDC)

        // Create a separate token for LP shares
        ERC20Mock lpToken = new ERC20Mock();

        uniswapRouter.setFactory(address(uniswapFactory));

        bytes memory agentTokenBaseParams = abi.encode("Test Token", "TEST");

        bytes memory agentTokenSupplyParams = abi.encode(
            MAX_SUPPLY, // maxSupply
            LP_SUPPLY, // lpSupply - supply of the AgentToken contract itself
            VAULT_SUPPLY, // vaultSupply
            MAX_TOKENS_PER_WALLET, // maxTokensPerWallet (0 means no limit)
            MAX_TOKENS_PER_TXN, // maxTokensPerTxn (0 means no limit)
            BOT_PROTECTION_DURATION, // botProtectionDurationInSeconds (5 minutes)
            mockVault // vault address
        );

        bytes memory agentTokenTaxParams = abi.encode(
            uint256(200), // projectBuyTaxBasisPoints (2%)
            uint256(300), // projectSellTaxBasisPoints (3%)
            uint256(500), // taxSwapThresholdBasisPoints (5%)
            mockProjectTaxRecipient // projectTaxRecipient
        );

        pairToken.mint(address(mockFactory), 1000 ether);

        agentTokenImplementation = new AgentToken();
        address proxyAddress = Clones.clone(address(agentTokenImplementation));
        agentTokenProxy = AgentToken(payable(proxyAddress));

        uniswapFactory.setPair(
            address(agentTokenProxy),
            address(pairToken),
            address(lpToken)
        );

        vm.startPrank(mockFactory);
        agentTokenProxy.initialize(
            [tokenAdmin, address(uniswapRouter), address(pairToken)],
            agentTokenBaseParams,
            agentTokenSupplyParams,
            agentTokenTaxParams
        );

        // This checks _mintBalances for lpsupply
        assertEq(
            agentTokenProxy.balanceOf(address(agentTokenProxy)),
            LP_SUPPLY * (10 ** agentTokenProxy.decimals())
        );

        // This checks _mintBalances for vaultsupply
        assertEq(
            agentTokenProxy.balanceOf(address(mockVault)),
            VAULT_SUPPLY * (10 ** agentTokenProxy.decimals())
        );

        // This checks _createPair
        assertEq(
            agentTokenProxy.liquidityPools()[0],
            uniswapFactory.getPair(address(agentTokenProxy), address(pairToken))
        );

        // here agentFactory would typically do this transfer
        pairToken.transfer(address(agentTokenProxy), 100 ether);
        agentTokenProxy.addInitialLiquidity(mockLpOwner);

        // after addLiquidity, agentTokens are transfered from agentTokenProxy to LP-pool
        assertEq(agentTokenProxy.balanceOf(address(agentTokenProxy)), 0);

        // assert that LP-pool has the correct balance of agentTokens
        assertEq(
            agentTokenProxy.balanceOf(
                uniswapFactory.getPair(
                    address(agentTokenProxy),
                    address(pairToken)
                )
            ),
            LP_SUPPLY * (10 ** agentTokenProxy.decimals())
        );

        vm.stopPrank();
    }

    function test_initialize() public {
        // assert token name
        assertEq(agentTokenProxy.name(), "Test Token");
        // assert token symbol
        assertEq(agentTokenProxy.symbol(), "TEST");
        // Verify initialization
    }
}

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
        // Mock implementation
        uint[] memory result = new uint[](path.length);
        result[0] = amountIn;
        result[1] = amountIn;
        return result;
    }
}

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
