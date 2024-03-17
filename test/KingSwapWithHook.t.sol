// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {KingSwap} from "../src/KingSwap.sol";
import {SigUtils} from "./utils/SigUtils.sol";
import {ERC20PermitMock} from "./mocks/ERC20PermitMock.sol";
import {KingSwapHook} from "../src/KingSwapHook.sol";

import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLPoolManager} from "pancake-v4-core/src/pool-cl/CLPoolManager.sol";
import {CLPoolManagerRouter} from "pancake-v4-core/test/pool-cl/helpers/CLPoolManagerRouter.sol";
import {CLPool} from "pancake-v4-core/src/pool-cl/libraries/CLPool.sol";
import {CLPoolParametersHelper} from "pancake-v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {TickMath} from "pancake-v4-core/src/pool-cl/libraries/TickMath.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {Vault} from "pancake-v4-core/src/Vault.sol";
import {CLSwapRouter} from "pancake-v4-periphery/src/pool-cl/CLSwapRouter.sol";
import {ICLSwapRouter, ICLSwapRouterBase} from "pancake-v4-periphery/src/pool-cl/interfaces/ICLSwapRouter.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {FixedPoint96} from "pancake-v4-core/src/pool-cl/libraries/FixedPoint96.sol";
import {IHooks} from "pancake-v4-core/src/interfaces/IHooks.sol";

contract KingSwapTest is Test {
    KingSwap public kingSwap;

    using PoolIdLibrary for PoolKey;

    IVault public vault;
    ICLPoolManager public poolManager;
    CLPoolManagerRouter public positionManager;
    ICLSwapRouter public router;
    KingSwapHook public hook;

    PoolKey public poolKey0;

    address public relay;
    address public deployer;
    address public user;
    uint256 public userPK;

    function setUp() public {
        // WETH weth = new WETH();
        relay = address(0x619);
        deployer = address(0x1);
        userPK = uint256(keccak256(abi.encodePacked("user")));
        user = vm.addr(userPK);
        vm.startPrank(deployer);
        vault = new Vault();
        poolManager = new CLPoolManager(vault, 3000);
        vault.registerPoolManager(address(poolManager));
        positionManager = new CLPoolManagerRouter(vault, poolManager);
        ERC20PermitMock usdc = new ERC20PermitMock("USDC", "USDC");
        router = new CLSwapRouter(vault, poolManager, address(usdc));
        kingSwap = new KingSwap(CLSwapRouter(payable(address(router))));

        Currency currency1 = Currency.wrap(address(usdc));
        //Currency memory currency1 = Currency.wrap(address(weth));
        hook = new KingSwapHook(poolManager);
        poolKey0 = PoolKey({
            currency0: CurrencyLibrary.NATIVE,
            currency1: currency1,
            hooks: hook,
            fee: uint24(3000),
            poolManager: poolManager,
            // 0 ~ 15  hookRegistrationMap = nil
            // 16 ~ 24 tickSpacing = 1
            parameters: CLPoolParametersHelper.setTickSpacing(bytes32(uint256(hook.getHooksRegistrationBitmap())), 1)
        });
        uint160 sqrtPriceX96_100 = uint160(62 * FixedPoint96.Q96);
        poolManager.initialize(poolKey0, sqrtPriceX96_100, new bytes(0));

        usdc.mint(deployer, 1000e6);
        usdc.approve(address(positionManager), 1000e6);
        deal(deployer, 1000 ether);
        positionManager.modifyPosition{value: 25 ether}(
            poolKey0,
            ICLPoolManager.ModifyLiquidityParams({
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                liquidityDelta: 10e6
            }),
            new bytes(0)
        );
    }

    function testUserInteraction() public {
        ERC20PermitMock usdc = ERC20PermitMock(Currency.unwrap(poolKey0.currency1));
        vm.startPrank(deployer);
        usdc.mint(user, 1e6);
        vm.stopPrank();
        vm.startPrank(relay);
        SigUtils sigUtils = new SigUtils(usdc.DOMAIN_SEPARATOR());
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: user,
            spender: address(kingSwap),
            value: 1e6,
            nonce: usdc.nonces(user),
            deadline: block.timestamp + 1 days
        });
        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, digest);
        assertTrue(permit.deadline > block.timestamp);
        ICLSwapRouterBase.V4CLExactInputSingleParams memory params = ICLSwapRouterBase.V4CLExactInputSingleParams({
            poolKey: poolKey0,
            zeroForOne: false,
            recipient: user,
            amountIn: 1e6,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0,
            hookData: new bytes(0)
        });
        kingSwap.swapSingle(params, user, permit.value, permit.deadline, v, r, s);
        assertEq(usdc.nonces(permit.owner), 1);
        console.log(hook.gasTracker());
        vm.stopPrank();
    }
}
