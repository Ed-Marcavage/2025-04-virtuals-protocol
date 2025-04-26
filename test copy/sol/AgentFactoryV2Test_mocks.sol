import {Test, console2} from "forge-std/Test.sol";
import "../contracts/virtualPersona/AgentFactory.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./mocks/ERC20Mock.sol";

contract AgentFactoryV2Test is Test {
    AgentFactoryV2 public factory;

    // Mock implementations
    address public tokenImplementation;
    address public veTokenImplementation;
    address public daoImplementation;
    address public tbaRegistry;
    address public assetToken;
    address public nft;
    uint256 public applicationThreshold = 100 ether;
    address public vault = address(0x123);
    address public proposer;

    // function setUp() public {
    //     // Deploy mock implementations
    //     tokenImplementation = address(new MockAgentToken());
    //     veTokenImplementation = address(new MockAgentVeToken());
    //     daoImplementation = address(new MockAgentDAO());
    //     tbaRegistry = address(new MockERC6551Registry());
    //     assetToken = address(new ERC20Mock("Asset Token", "ASSET"));
    //     nft = address(new MockAgentNft());

    //     // Deploy and initialize factory
    //     factory = new AgentFactoryV2();
    //     factory.initialize(
    //         tokenImplementation,
    //         veTokenImplementation,
    //         daoImplementation,
    //         tbaRegistry,
    //         assetToken,
    //         nft,
    //         applicationThreshold,
    //         vault
    //     );
    // }

    function setUp() public {
        // This doesnt really make sense to me, why wrap mocks in addresses?
        tokenImplementation = address(new MockAgentToken());
        veTokenImplementation = address(new MockAgentVeToken());
        daoImplementation = address(new MockAgentDAO());
        tbaRegistry = address(new MockERC6551Registry());
        assetToken = address(new ERC20Mock());
        nft = address(new MockAgentNft());

        proposer = makeAddr("Proposer");

        // Deploy implementation contract
        AgentFactoryV2 implementation = new AgentFactoryV2();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            AgentFactoryV2.initialize.selector,
            tokenImplementation,
            veTokenImplementation,
            daoImplementation,
            tbaRegistry,
            assetToken,
            nft,
            applicationThreshold,
            vault
        );

        // Deploy proxy pointing to the implementation with initialization data
        // @audix try openzeppelin proxy foundry library
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        // Cast the proxy address to the implementation type for easier interaction
        factory = AgentFactoryV2(address(proxy));

        vm.startPrank(proposer);
        ERC20Mock(assetToken).mint(proposer, 100 ether);
        ERC20Mock(assetToken).approve(address(factory), 100 ether);
        vm.stopPrank();
    }

    function test_initialize() public {
        // Verify initialization
        assertEq(
            factory.tokenImplementation(),
            tokenImplementation,
            "Token implementation mismatch"
        );
        assertEq(
            factory.veTokenImplementation(),
            veTokenImplementation,
            "VeToken implementation mismatch"
        );
        assertEq(
            factory.daoImplementation(),
            daoImplementation,
            "DAO implementation mismatch"
        );
        assertEq(factory.tbaRegistry(), tbaRegistry, "TBA registry mismatch");
        assertEq(factory.assetToken(), assetToken, "Asset token mismatch");
        assertEq(factory.nft(), nft, "NFT mismatch");
        assertEq(
            factory.applicationThreshold(),
            applicationThreshold,
            "Application threshold mismatch"
        );
    }

    function test_proposeAgent() public {
        vm.startPrank(proposer);
        // Test proposal with valid parameters
        string memory name = "Test Agent";
        string memory symbol = "TEST";
        string memory tokenURI = "https://example.com/tokenURI";
        uint8[] memory cores = new uint8[](3);
        cores[0] = 1;
        cores[1] = 2;
        cores[2] = 3;

        uint256 proposalId = factory.proposeAgent(
            name,
            symbol,
            tokenURI,
            cores,
            bytes32(0), // tbaSalt
            address(0), // tbaImplementation
            100, // daoVotingPeriod
            100 // daoThreshold
        );

        // Verify proposal creation
        assertGt(proposalId, 0, "Proposal ID should be greater than 0");
        vm.stopPrank();

        // getApplication
        AgentFactoryV2.Application memory application = factory.getApplication(
            proposalId
        );
        assertEq(application.name, name, "Name mismatch");
        assertEq(application.symbol, symbol, "Symbol mismatch");
        assertEq(application.tokenURI, tokenURI, "Token URI mismatch");
        assertEq(
            application.cores.length,
            cores.length,
            "Cores length mismatch"
        );
        for (uint i = 0; i < cores.length; i++) {
            assertEq(application.cores[i], cores[i], "Core mismatch at index");
        }
    }

    // Test executeApplication next
}

// Mock contracts
contract MockAgentToken {
    function initialize(
        address[3] memory,
        bytes memory,
        bytes memory,
        bytes memory
    ) external {}
}

contract MockAgentVeToken {
    function initialize(
        string memory,
        string memory,
        address,
        address,
        uint256,
        address,
        bool
    ) external {}
}

contract MockAgentDAO {
    function initialize(
        string memory,
        address,
        address,
        uint256,
        uint32
    ) external {}
}

contract MockERC6551Registry {
    function createAccount(
        address,
        bytes32,
        uint256,
        address,
        uint256
    ) external returns (address) {
        return address(0);
    }
}

contract MockAgentNft {
    function nextVirtualId() external view returns (uint256) {
        return 1;
    }

    function mint(
        uint256,
        address,
        string memory,
        address,
        address,
        uint8[] memory,
        address,
        address
    ) external {}

    function setTBA(uint256, address) external {}
}
