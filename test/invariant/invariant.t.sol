// // test/AgentTokenInvariant.t.sol
// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "../../contracts/virtualPersona/AgentToken.sol";
// import "./handler.t.sol";
// import "../mocks/ERC20Mock.sol";

// contract AgentTokenInvariant is Test {
//     AgentToken token;
//     AgentTokenHandler handler;
//     MockERC20 pairToken;
//     address owner = makeAddr("owner");
//     address factory = makeAddr("factory");
//     address lpOwner = makeAddr("lpOwner");

//     function setUp() external {
//         /** ---------- deploy mocks ---------- */
//         // fake LP token (also doubles as the “pair” address)
//         pairToken = new MockERC20("PAIR", "PR");
//         pairToken.mint(address(this), 1_000_000 ether);

//         // the pair address itself just re-uses the ERC-20 contract
//         MockUniswapRouter router = new MockUniswapRouter(address(pairToken));

//         /** ---------- deploy & initialise AgentToken ---------- */
//         token = new AgentToken();

//         // encode the parameters the contract expects
//         AgentToken.ERC20SupplyParameters memory supplyParams = AgentToken
//             .ERC20SupplyParameters({
//                 maxSupply: 1_000_000,
//                 lpSupply: 10_000,
//                 vaultSupply: 990_000,
//                 botProtectionDurationInSeconds: 0,
//                 vault: owner
//             });

//         AgentToken.ERC20TaxParameters memory taxParams = AgentToken
//             .ERC20TaxParameters({
//                 projectBuyTaxBasisPoints: 300, // 3 %
//                 projectSellTaxBasisPoints: 300,
//                 taxSwapThresholdBasisPoints: 50, // 0.5 %
//                 projectTaxRecipient: owner
//             });

//         bytes memory base = abi.encode("AgentToken", "AGT");
//         bytes memory supply = abi.encode(supplyParams);
//         bytes memory tax = abi.encode(taxParams);

//         address[3] memory integration = [
//             owner,
//             address(router),
//             address(pairToken)
//         ];
//         vm.prank(factory);
//         token.initialize(integration, base, supply, tax);

//         /** ---------- seed initial liquidity ---------- */
//         // move the LP supply’s worth of tokens + some pair tokens into the AT contract
//         uint256 lpAmt = 10_000 * 1e18;
//         vm.prank(owner);
//         pairToken.transfer(address(token), lpAmt); // fake equal value
//         vm.prank(owner);
//         token.addInitialLiquidity(lpOwner);

//         /** ---------- seed some holders ---------- */
//         address;
//         for (uint256 i; i < actors.length; ++i) {
//             actors[i] = makeAddr(
//                 string(abi.encodePacked("actor", vm.toString(i)))
//             );
//             // give everybody 1 000 AGT to play with
//             token.transfer(actors[i], 1_000 * 1e18);
//         }

//         /** ---------- hook the handler ---------- */
//         handler = new AgentTokenHandler(token, pairToken, actors);
//         targetContract(address(handler));
//     }

//     /*//////////////////////////////////////////////////////////////
//                             THE  INVARIANT
//     //////////////////////////////////////////////////////////////*/

//     function invariant_PendingTaxAlwaysBacked() external view {
//         assertLe(
//             token.projectTaxPendingSwap(),
//             token.balanceOf(address(token))
//         );
//     }
// }

// contract MockUniswapRouter {
//     address private _factory;

//     function setFactory(address factory_) external {
//         _factory = factory_;
//     }

//     function factory() external view returns (address) {
//         return _factory;
//     }

//     function addLiquidity(
//         address tokenA,
//         address tokenB,
//         uint amountADesired,
//         uint amountBDesired,
//         uint amountAMin,
//         uint amountBMin,
//         address to,
//         uint deadline
//     ) external returns (uint amountA, uint amountB, uint liquidity) {
//         // Get the LP token from the factory
//         address lpToken = IUniswapV2Factory(_factory).getPair(tokenA, tokenB);

//         // Actually transfer the tokens from their sources
//         IERC20(tokenA).transferFrom(msg.sender, lpToken, amountADesired);
//         IERC20(tokenB).transferFrom(msg.sender, lpToken, amountBDesired);

//         // Mint LP tokens to the recipient
//         ERC20Mock(lpToken).mint(to, amountADesired);

//         return (amountADesired, amountBDesired, amountADesired);
//     }

//     function swapExactTokensForTokensSupportingFeeOnTransferTokens(
//         uint amountIn,
//         uint amountOutMin,
//         address[] calldata path,
//         address to,
//         uint deadline
//     ) external returns (uint[] memory amounts) {
//         // Mock implementation
//         uint[] memory result = new uint[](path.length);
//         result[0] = amountIn;
//         result[1] = amountIn;
//         return result;
//     }
// }

// contract MockUniswapFactory {
//     // Map token pairs to their LP token
//     mapping(address => mapping(address => address)) private _pairs;

//     function setPair(address tokenA, address tokenB, address lpToken) external {
//         _pairs[tokenA][tokenB] = lpToken;
//         _pairs[tokenB][tokenA] = lpToken; // Ensure order doesn't matter
//     }

//     function getPair(
//         address tokenA,
//         address tokenB
//     ) external view returns (address) {
//         return _pairs[tokenA][tokenB];
//     }

//     function createPair(
//         address tokenA,
//         address tokenB
//     ) external returns (address) {
//         // In a real implementation, this would deploy a new pair contract
//         // For mock purposes, we'd just set it in our mapping
//         ERC20Mock newPair = new ERC20Mock();
//         address pairAddress = address(newPair);

//         _pairs[tokenA][tokenB] = pairAddress;
//         _pairs[tokenB][tokenA] = pairAddress;

//         return pairAddress;
//     }
// }
