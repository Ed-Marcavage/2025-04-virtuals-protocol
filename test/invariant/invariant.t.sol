import "forge-std/console.sol";
import {Test, console2} from "forge-std/Test.sol";
import "../mocks/ERC20Mock.sol";
import {MockUniswapFactory} from "./mocks/MockUniswapFactory.sol";
import {AgentTokenHandler} from "./handler.t.sol";
import {MockUniswapRouter} from "./mocks/MockUniswapRouter.sol";
import "../../contracts/virtualPersona/AgentFactory.sol";
import "../../contracts/virtualPersona/AgentToken.sol";

//https://claude.ai/chat/6bc4ba55-9759-451c-a2a6-a288914e4adb
contract AgentTokenInvariantTest is Test {
    AgentTokenHandler public handler;
    AgentToken public agentTokenImplementation;
    AgentToken public agentTokenProxy;

    MockUniswapRouter public uniswapRouter;
    MockUniswapFactory public uniswapFactory;

    address public mockVault = makeAddr("mockVault");
    address public mockProjectTaxRecipient =
        makeAddr("mockProjectTaxRecipient");
    address public mockFactory = makeAddr("mockFactory");
    address public tokenAdmin = makeAddr("tokenAdmin");
    address public mockLpOwner = makeAddr("mockLpOwner");

    uint256 public constant MAX_SUPPLY = 2000000;
    uint256 public constant LP_SUPPLY = MAX_SUPPLY / 2;
    uint256 public constant VAULT_SUPPLY = MAX_SUPPLY / 2;
    uint256 public constant BOT_PROTECTION_DURATION = 300;
    uint256 public constant PROJECT_BUY_TAX_BASIS_POINTS = 200;
    uint256 public constant PROJECT_SELL_TAX_BASIS_POINTS = 300;
    uint256 public constant TAX_SWAP_THRESHOLD_BASIS_POINTS = 10;
    //10,0000
    uint256 public constant MAX_TOKENS_PER_WALLET = 0;
    uint256 public constant MAX_TOKENS_PER_TXN = 0;
    address public constant PROJECT_TAX_RECIPIENT = address(0x9);

    function setUp() public {
        uniswapRouter = new MockUniswapRouter();
        uniswapFactory = new MockUniswapFactory();
        ERC20Mock pairToken = new ERC20Mock(); // One side of the pair (e.g., USDC)

        // Create a separate token for LP shares (pool)
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
            uint256(PROJECT_BUY_TAX_BASIS_POINTS), // projectBuyTaxBasisPoints (2%)
            uint256(PROJECT_SELL_TAX_BASIS_POINTS), // projectSellTaxBasisPoints (3%)
            uint256(TAX_SWAP_THRESHOLD_BASIS_POINTS), // taxSwapThresholdBasisPoints (5%)
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

        handler = new AgentTokenHandler(
            agentTokenProxy,
            pairToken,
            uniswapRouter,
            mockProjectTaxRecipient,
            mockVault
        );

        targetContract(address(handler));
    }

    // swapThresholdInTokens_ 100,000.000000000000000000
    // taxBalance_ 77602639172382557124589

    //   ghost_totalTaxCollected 88,796.341286286042816144
    // 100,000
    //   ghost_totalAutoSwaps 0

    // swapThresholdInTokens_ 100,000.000000000000000000
    // taxBalance_ 73,117.827735972297057079

    // Your main invariant
    function invariant_PendingTaxAlwaysBacked() external view {
        // log ghost variables
        console2.log(
            "ghost_totalTaxCollected",
            handler.ghost_totalTaxCollected()
        );
        console2.log("ghost_totalAutoSwaps", handler.ghost_totalAutoSwaps());

        assertEq(
            agentTokenProxy.projectTaxPendingSwap(),
            agentTokenProxy.balanceOf(address(agentTokenProxy)),
            "Pending tax exceeds contract balance"
        );
        //104422656275585623022
        //104422656275585623022
        //ghost total - 75481220571219092001518
    }
}
