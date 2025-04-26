import {Test, console2} from "forge-std/Test.sol";
import "../contracts/virtualPersona/AgentFactory.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./mocks/ERC20Mock.sol";
import "../contracts/virtualPersona/AgentToken.sol";
import "../contracts/virtualPersona/AgentVeToken.sol";
import "../contracts/virtualPersona/AgentDAO.sol";
import "../contracts/virtualPersona/AgentNftV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AgentFactoryV2Test is Test {
    AgentFactoryV2 public factory;

    // start here tomo
    // https://claude.ai/chat/44a2e87a-3508-43b4-b601-95fbc836385a
    // First logiclly break down steps to init AgentToken() ^ and document, then convert to agent
    // AgentFactory
    // ToDo: figure out why certain logic needed in uni, and research factory/router for uniswap v2
    // todo: understand/walk thru 100% of the Foundry output
    AgentToken public agentTokenImplementation;
    AgentToken public agentTokenProxy;
    AgentVeToken public veTokenImplementation;
    AgentDAO public daoImplementation;
    AgentNftV2 public nft;
    IERC6551Registry public tbaRegistry;
    uint256 public applicationThreshold;

    // AgentToken
    AgentToken public agentToken;
    address public tokenAdmin = address(0x1);
    // address public mockUniswapRouter = address(0x2);
    // address public mockAssetToken = address(0x3);
    address public mockFactory = address(0x5);
    address public mockVault = address(0x6);
    address public mockProjectTaxRecipient = address(0x7);
    address public mockLpOwner = address(0x8);
    // Mock contracts
    MockUniswapRouter public uniswapRouter;
    MockUniswapFactory public uniswapFactory;

    // IERC20 public assetToken;^

    function setUp() public {
        uniswapRouter = new MockUniswapRouter();
        uniswapFactory = new MockUniswapFactory();
        ERC20Mock lpToken = new ERC20Mock();

        uniswapRouter.setFactory(address(uniswapFactory));
        uniswapFactory.setPair(lpToken);

        lpToken.mint(address(this), 1000 ether);
        agentTokenImplementation = new AgentToken();

        // Create a clone (proxy) of the implementation
        address proxyAddress = Clones.clone(address(agentTokenImplementation));
        agentTokenProxy = AgentToken(payable(proxyAddress));

        // Encode parameters for initialization
        bytes memory baseParams = abi.encode("Test Token", "TEST");

        // Encode supply parameters
        // ERC20SupplyParameters struct would typically include:
        // maxSupply, lpSupply, vaultSupply, maxTokensPerWallet, maxTokensPerTxn, botProtectionDurationInSeconds, vault
        bytes memory supplyParams = abi.encode(
            uint256(1000000), // maxSupply
            uint256(500000), // lpSupply
            uint256(500000), // vaultSupply
            uint256(0), // maxTokensPerWallet (0 means no limit)
            uint256(0), // maxTokensPerTxn (0 means no limit)
            uint256(300), // botProtectionDurationInSeconds (5 minutes)
            mockVault // vault address
        );

        // Encode tax parameters
        // ERC20TaxParameters struct would typically include:
        // projectBuyTaxBasisPoints, projectSellTaxBasisPoints, taxSwapThresholdBasisPoints, projectTaxRecipient
        bytes memory taxParams = abi.encode(
            uint256(200), // projectBuyTaxBasisPoints (2%)
            uint256(300), // projectSellTaxBasisPoints (3%)
            uint256(500), // taxSwapThresholdBasisPoints (5%)
            mockProjectTaxRecipient // projectTaxRecipient
        );

        // Initialize the token
        // We're using this test contract as the factory
        vm.startPrank(mockFactory);
        agentTokenProxy.initialize(
            [tokenAdmin, address(uniswapRouter), address(lpToken)],
            baseParams,
            supplyParams,
            taxParams
        );
        vm.stopPrank();

        // Setup for adding initial liquidity
        // Fund the contract with asset tokens for liquidity
        lpToken.transfer(address(agentTokenProxy), 100 ether);

        // Add initial liquidity
        vm.prank(mockFactory);
        agentTokenProxy.addInitialLiquidity(mockLpOwner);

        // tokenImplementation = new AgentToken();
        // veTokenImplementation = new AgentVeToken();
        // daoImplementation = new AgentDAO();
        // nft = new AgentNftV2();
    }

    //test_initialize
    function initialize() public {
        // Verify initialization
        assertEq(agentTokenProxy.name(), "Test Token");
        assertEq(agentTokenProxy.symbol(), "TEST");
    }
}

// Mock contracts needed for testing
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

        // Mint LP tokens to the recipient
        ERC20Mock(lpToken).mint(to, amountADesired);
        // Simplified mock implementation
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
    ERC20Mock private mockPair;

    function setPair(ERC20Mock _pair) external {
        console2.log("setPair called:", address(mockPair));
        mockPair = _pair;
    }

    function getPair(address, address) external view returns (ERC20Mock) {
        return mockPair;
    }

    function createPair(address, address) external view returns (ERC20Mock) {
        console2.log("createPair called:", address(mockPair));
        return mockPair;
    }
}
