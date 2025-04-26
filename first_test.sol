// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
pragma abicoder v2;

// Enable viaIR and optimizer settings
/// @solidity compiler-version 0.8.20
/// @solidity via-ir true
/// @solidity optimizer true
/// @solidity optimizer-runs 200

// TODO: revist PC tutrial to see how he fuzzes upgradeable contracts

import "forge-std/Test.sol";
import "../contracts/virtualPersona/AgentFactoryV3.sol";
import "../contracts/virtualPersona/AgentToken.sol";
import "../contracts/virtualPersona/AgentDAO.sol";
import "../contracts/virtualPersona/AgentVeToken.sol";
import "../contracts/virtualPersona/AgentNftV2.sol";
// import "../contracts/governance/veVirtualToken.sol";
import "../contracts/virtualPersona/AgentFactory.sol";
import "../contracts/virtualPersona/IAgentToken.sol";
import "../contracts/virtualPersona/IAgentDAO.sol";
import "../contracts/virtualPersona/IAgentNft.sol";
import "../contracts/contribution/ContributionNft.sol";
import "../contracts/contribution/ServiceNft.sol";
import "../contracts/fun/Bonding.sol";
import "../contracts/fun/FFactory.sol";
import "../contracts/fun/FRouter.sol";
import "../contracts/fun/FPair.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./mocks/MockERC20.sol";
import "./mocks/MockAgentToken.sol";
import "./mocks/MockAgentVeToken.sol";
import "./mocks/MockAgentDAO.sol";
import "./mocks/MockAgentNft.sol";
import "./mocks/MockERC6551Registry.sol";

contract AgentFactoryV2Test is Test {
    // Test variables
    AgentFactoryV2 public factory;
    MockERC20 public assetToken;
    MockAgentToken public tokenImpl;
    MockAgentVeToken public veTokenImpl;
    MockAgentDAO public daoImpl;
    MockAgentNft public nftImpl;
    MockERC6551Registry public registryImpl;
    MockERC20 public lpToken;

    address public admin = address(0x1);
    address public user = address(0x2);
    address public vault = address(0x3);
    address public tokenAdmin = address(0x4);
    address public uniswapRouter = address(0x5);

    uint256 public applicationThreshold = 100 ether;

    // Test setup
    function setUp() public {
        // Deploy mock contracts
        assetToken = new MockERC20("Asset Token", "ASSET");
        lpToken = new MockERC20("LP Token", "LP");
        tokenImpl = new MockAgentToken(address(lpToken));
        veTokenImpl = new MockAgentVeToken();
        daoImpl = new MockAgentDAO();
        nftImpl = new MockAgentNft();
        registryImpl = new MockERC6551Registry();

        // Deploy the factory contract
        factory = new AgentFactoryV2();

        // Initialize the factory with proper parameters
        factory.initialize(
            address(tokenImpl), // tokenImplementation_
            address(veTokenImpl), // veTokenImplementation_
            address(daoImpl), // daoImplementation_
            address(registryImpl), // tbaRegistry_
            address(assetToken), // assetToken_
            address(nftImpl), // nft_
            applicationThreshold, // applicationThreshold_
            vault // vault_
        );

        // Setup additional configuration
        vm.startPrank(admin);
        factory.grantRole(factory.DEFAULT_ADMIN_ROLE(), admin);
        factory.setTokenAdmin(tokenAdmin);
        factory.setUniswapRouter(uniswapRouter);
        factory.setMaturityDuration(86400 * 365 * 10); // 10 years

        // Set token supply parameters
        factory.setTokenSupplyParams(
            1_000_000 ether, // maxSupply
            500_000 ether, // lpSupply
            200_000 ether, // vaultSupply
            10_000 ether, // maxTokensPerWallet
            1_000 ether, // maxTokensPerTxn
            3600, // botProtectionDurationInSeconds
            vault // vault address
        );

        // Set token tax parameters
        factory.setTokenTaxParams(
            300, // projectBuyTaxBasisPoints (3%)
            500, // projectSellTaxBasisPoints (5%)
            100, // taxSwapThresholdBasisPoints (1%)
            vault // projectTaxRecipient
        );
        vm.stopPrank();

        // Prepare test data
        assetToken.mint(user, 1000 ether);
        vm.prank(user);
        assetToken.approve(address(factory), 1000 ether);
    }

    // Test propose agent functionality
    function testProposeAgent() public {
        vm.startPrank(user);

        uint8[] memory cores = new uint8[](3);
        cores[0] = 1;
        cores[1] = 2;
        cores[2] = 3;

        uint256 balanceBefore = assetToken.balanceOf(user);

        uint256 proposalId = factory.proposeAgent(
            "Test Agent",
            "TEST",
            "ipfs://test-uri",
            cores,
            bytes32(uint256(1)),
            address(0x123),
            600, // voting period
            1000 ether // threshold
        );

        vm.stopPrank();

        // Verify proposal was created
        assertEq(proposalId, 1, "Proposal ID should be 1");

        // Verify tokens were transferred
        assertEq(
            assetToken.balanceOf(user),
            balanceBefore - applicationThreshold,
            "Asset tokens should be transferred from user"
        );

        // Verify application data
        AgentFactoryV2.Application memory app = factory.getApplication(
            proposalId
        );
        assertEq(app.name, "Test Agent", "Application name should match");
        assertEq(app.symbol, "TEST", "Application symbol should match");
        assertEq(
            uint(app.status),
            uint(AgentFactoryV2.ApplicationStatus.Active),
            "Status should be Active"
        );
        assertEq(app.proposer, user, "Proposer should be the user");
    }

    // Test withdraw functionality
    // function testWithdraw() public {
    //     // First create a proposal
    //     vm.startPrank(user);

    //     uint8[] memory cores = new uint8[](1);
    //     cores[0] = 1;

    //     uint256 proposalId = factory.proposeAgent(
    //         "Test Agent",
    //         "TEST",
    //         "ipfs://test-uri",
    //         cores,
    //         bytes32(uint256(1)),
    //         address(0x123),
    //         600,
    //         1000 ether
    //     );

    //     // Mine blocks to ensure the proposal is matured
    //     vm.roll(block.number + 10);

    //     uint256 balanceBefore = assetToken.balanceOf(user);

    //     // Withdraw the application
    //     factory.withdraw(proposalId);

    //     vm.stopPrank();

    //     // Verify application status
    //     AgentFactoryV2.Application memory app = factory.getApplication(
    //         proposalId
    //     );
    //     assertEq(
    //         uint8(app.status),
    //         uint8(AgentFactoryV2.ApplicationStatus.Withdrawn),
    //         "Application should be withdrawn"
    //     );

    //     // Verify tokens were returned
    //     assertEq(
    //         assetToken.balanceOf(user),
    //         balanceBefore + applicationThreshold,
    //         "Asset tokens should be returned to user"
    //     );
    // }

    // // Test execute application functionality
    // function testExecuteApplication() public {
    //     // First create a proposal
    //     vm.startPrank(user);

    //     uint8[] memory cores = new uint8[](2);
    //     cores[0] = 1;
    //     cores[1] = 2;

    //     uint256 proposalId = factory.proposeAgent(
    //         "Test Agent",
    //         "TEST",
    //         "ipfs://test-uri",
    //         cores,
    //         bytes32(uint256(1)),
    //         address(0x123),
    //         600,
    //         1000 ether
    //     );

    //     // Setup mocks for execution
    //     // We need to give the factory some LP tokens to stake
    //     lpToken.mint(address(factory), 100 ether);

    //     // Execute the application
    //     factory.executeApplication(proposalId, true);

    //     vm.stopPrank();

    //     // Verify application status
    //     AgentFactoryV2.Application memory app = factory.getApplication(
    //         proposalId
    //     );
    //     assertEq(
    //         uint8(app.status),
    //         uint8(AgentFactoryV2.ApplicationStatus.Executed),
    //         "Application should be executed"
    //     );

    //     // Verify the virtualId was set
    //     assertEq(app.virtualId, 1, "Virtual ID should be set");

    //     // Verify arrays were updated
    //     assertEq(
    //         factory.allTradingTokens(0) != address(0),
    //         true,
    //         "Trading token should be added"
    //     );
    //     assertEq(
    //         factory.allTokens(0) != address(0),
    //         true,
    //         "Token should be added"
    //     );
    //     assertEq(factory.allDAOs(0) != address(0), true, "DAO should be added");
    // }

    // // Test access control for admin functions
    // function testAccessControl() public {
    //     // Non-admin trying to set threshold
    //     vm.startPrank(user);
    //     vm.expectRevert();
    //     factory.setApplicationThreshold(200 ether);
    //     vm.stopPrank();

    //     // Admin setting threshold
    //     vm.startPrank(admin);
    //     factory.setApplicationThreshold(200 ether);
    //     vm.stopPrank();

    //     // Verify threshold was updated
    //     assertEq(
    //         factory.applicationThreshold(),
    //         200 ether,
    //         "Threshold should be updated"
    //     );
    // }

    // // Test pause functionality
    // function testPause() public {
    //     // Admin pausing contract
    //     vm.startPrank(admin);
    //     factory.pause();
    //     vm.stopPrank();

    //     // Try to propose an agent while paused
    //     vm.startPrank(user);

    //     uint8[] memory cores = new uint8[](1);
    //     cores[0] = 1;

    //     vm.expectRevert();
    //     factory.proposeAgent(
    //         "Test Agent",
    //         "TEST",
    //         "ipfs://test-uri",
    //         cores,
    //         bytes32(uint256(1)),
    //         address(0x123),
    //         600,
    //         1000 ether
    //     );

    //     vm.stopPrank();

    //     // Admin unpausing contract
    //     vm.startPrank(admin);
    //     factory.unpause();
    //     vm.stopPrank();

    //     // Should be able to propose now
    //     vm.startPrank(user);
    //     uint256 proposalId = factory.proposeAgent(
    //         "Test Agent",
    //         "TEST",
    //         "ipfs://test-uri",
    //         cores,
    //         bytes32(uint256(1)),
    //         address(0x123),
    //         600,
    //         1000 ether
    //     );
    //     vm.stopPrank();

    //     assertEq(proposalId, 1, "Proposal should be created after unpause");
    // }

    // // Test the application requirements
    // function testApplicationRequirements() public {
    //     vm.startPrank(user);

    //     // Test with empty cores array
    //     uint8[] memory emptyCores = new uint8[](0);
    //     vm.expectRevert("Cores must be provided");
    //     factory.proposeAgent(
    //         "Test Agent",
    //         "TEST",
    //         "ipfs://test-uri",
    //         emptyCores,
    //         bytes32(uint256(1)),
    //         address(0x123),
    //         600,
    //         1000 ether
    //     );

    //     // Test with insufficient tokens
    //     address poorUser = address(0x999);
    //     assetToken.mint(poorUser, 50 ether); // Less than threshold

    //     vm.stopPrank();
    //     vm.startPrank(poorUser);
    //     assetToken.approve(address(factory), 50 ether);

    //     uint8[] memory cores = new uint8[](1);
    //     cores[0] = 1;

    //     vm.expectRevert("Insufficient asset token");
    //     factory.proposeAgent(
    //         "Test Agent",
    //         "TEST",
    //         "ipfs://test-uri",
    //         cores,
    //         bytes32(uint256(1)),
    //         address(0x123),
    //         600,
    //         1000 ether
    //     );

    //     vm.stopPrank();
    // }

    // // Test the full lifecycle
    // function testFullLifecycle() public {
    //     // Step 1: Propose agent
    //     vm.startPrank(user);

    //     uint8[] memory cores = new uint8[](2);
    //     cores[0] = 1;
    //     cores[1] = 2;

    //     uint256 proposalId = factory.proposeAgent(
    //         "Test Agent",
    //         "TEST",
    //         "ipfs://test-uri",
    //         cores,
    //         bytes32(uint256(1)),
    //         address(0x123),
    //         600,
    //         1000 ether
    //     );

    //     // Setup for execution
    //     lpToken.mint(address(factory), 100 ether);

    //     // Step 2: Execute application and verify event emission
    //     vm.expectEmit(true, true, true, true);
    //     emit AgentFactoryV2.NewPersona(
    //         1,
    //         address(0),
    //         address(0),
    //         address(0),
    //         address(0),
    //         address(0)
    //     );
    //     factory.executeApplication(proposalId, true);

    //     vm.stopPrank();

    //     // Step 3: Verify final state
    //     AgentFactoryV2.Application memory app = factory.getApplication(
    //         proposalId
    //     );
    //     assertEq(
    //         uint8(app.status),
    //         uint8(AgentFactoryV2.ApplicationStatus.Executed),
    //         "Application should be executed"
    //     );

    //     assertEq(app.virtualId, 1, "Virtual ID should be set");
    //     assertEq(
    //         app.withdrawableAmount,
    //         0,
    //         "Withdrawable amount should be zero"
    //     );

    //     // Verify contract state
    //     assertEq(factory.totalAgents(), 1, "Should have 1 agent");
    // }

    // // Test prevent double execution
    // function testPreventDoubleExecution() public {
    //     // Propose agent
    //     vm.startPrank(user);

    //     uint8[] memory cores = new uint8[](1);
    //     cores[0] = 1;

    //     uint256 proposalId = factory.proposeAgent(
    //         "Test Agent",
    //         "TEST",
    //         "ipfs://test-uri",
    //         cores,
    //         bytes32(uint256(1)),
    //         address(0x123),
    //         600,
    //         1000 ether
    //     );

    //     // Execute once
    //     lpToken.mint(address(factory), 100 ether);
    //     factory.executeApplication(proposalId, true);

    //     // Try to execute again
    //     vm.expectRevert("Application is not active");
    //     factory.executeApplication(proposalId, true);

    //     vm.stopPrank();
    // }

    // // Test reentrancy protection
    // function testReentrancyProtection() public {
    //     // We'd need to create a malicious contract to test this properly,
    //     // but we can at least verify the modifier is in place
    //     assertTrue(
    //         factory.executeApplication.selector ==
    //             bytes4(keccak256("executeApplication(uint256,bool)"))
    //     );
    //     assertTrue(
    //         factory.withdraw.selector == bytes4(keccak256("withdraw(uint256)"))
    //     );
    // }
}
