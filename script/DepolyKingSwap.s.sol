// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {KingSwap} from "../src/KingSwap.sol";
import {KingSwapHook} from "../src/KingSwapHook.sol";

import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLPoolManager} from "pancake-v4-core/src/pool-cl/CLPoolManager.sol";
import {CLPoolManagerRouter} from "pancake-v4-core/test/pool-cl/helpers/CLPoolManagerRouter.sol";
import {CLPool} from "pancake-v4-core/src/pool-cl/libraries/CLPool.sol";
import {CLPoolParametersHelper} from "pancake-v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {TickMath} from "pancake-v4-core/src/pool-cl/libraries/TickMath.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {Vault} from "pancake-v4-core/src/Vault.sol";
import {CLSwapRouter} from "pancake-v4-periphery/src/pool-cl/CLSwapRouter.sol";
import {ICLSwapRouter, ICLSwapRouterBase} from "pancake-v4-periphery/src/pool-cl/interfaces/ICLSwapRouter.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {FixedPoint96} from "pancake-v4-core/src/pool-cl/libraries/FixedPoint96.sol";
import {IHooks} from "pancake-v4-core/src/interfaces/IHooks.sol";

contract DeployKingSwap is Script {
    KingSwap public kingSwap;
    KingSwapHook public hook;

    using PoolIdLibrary for PoolKey;

    IVault public vault;
    ICLPoolManager public poolManager;
    CLPoolManagerRouter public positionManager;
    ICLSwapRouter public router;

    PoolKey public poolKey0;

    address public deployer;
    uint256 public deployerPK;

    address constant baseSepoliaUSDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant arbitrumSepoliaUSDC = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;

    function run() public {
        // WETH weth = new WETH();
        deployerPK = vm.envUint("DEPLOYER_PK");
        deployer = vm.addr(deployerPK);
        // deploy an ERC20Permit token
        ERC20Permit usdc = ERC20Permit(arbitrumSepoliaUSDC);
        vm.startBroadcast(deployerPK);
        vault = new Vault();
        poolManager = new CLPoolManager(vault, 3000);
        vault.registerPoolManager(address(poolManager));
        positionManager = new CLPoolManagerRouter(vault, poolManager);
        router = new CLSwapRouter(vault, poolManager, address(usdc));
        kingSwap = new KingSwap(CLSwapRouter(payable(address(router))));
        hook = new KingSwapHook(poolManager);
        Currency currency1 = Currency.wrap(address(usdc));
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
        uint160 sqrtPriceX96_100 = 4713851406721118453442099;
        poolManager.initialize(poolKey0, sqrtPriceX96_100, new bytes(0));

        //Currency memory currency1 = Currency.wrap(address(weth));

        usdc.approve(address(positionManager), 10e6);
        positionManager.modifyPosition{value: 0.001 ether}(
            poolKey0,
            ICLPoolManager.ModifyLiquidityParams({
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                liquidityDelta: 1e5
            }),
            new bytes(0)
        );
    }
}
