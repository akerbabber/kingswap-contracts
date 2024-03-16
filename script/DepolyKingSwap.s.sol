// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {KingSwap} from "../src/KingSwap.sol";

import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLPoolManager} from "pancake-v4-core/src/pool-cl/CLPoolManager.sol";
import {CLPoolManagerRouter} from "pancake-v4-core/test/pool-cl/helpers/CLPoolManagerRouter.sol";
import {CLPool} from "pancake-v4-core/src/pool-cl/libraries/CLPool.sol";
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

contract KingSwapTest is Script {
    KingSwap public kingSwap;

    using PoolIdLibrary for PoolKey;

    IVault public vault;
    ICLPoolManager public poolManager;
    CLPoolManagerRouter public positionManager;
    ICLSwapRouter public router;

    PoolKey public poolKey0;

    address public deployer;
    uint256 public deployerPK;

    function run() public {
        // WETH weth = new WETH();
        deployerPK = vm.envUint("DEPLOYER_PK");
        deployer = vm.addr(deployerPK);
        // deploy an ERC20Permit token
        ERC20Permit usdc = ERC20Permit(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
        vm.startBroadcast(deployerPK);
        vault = new Vault();
        poolManager = new CLPoolManager(vault, 3000);
        vault.registerPoolManager(address(poolManager));
        positionManager = new CLPoolManagerRouter(vault, poolManager);
        router = new CLSwapRouter(vault, poolManager, address(usdc));
        kingSwap = new KingSwap(CLSwapRouter(payable(address(router))));

        Currency currency1 = Currency.wrap(address(usdc));
        //Currency memory currency1 = Currency.wrap(address(weth));

        poolKey0 = PoolKey({
            currency0: CurrencyLibrary.NATIVE,
            currency1: currency1,
            hooks: IHooks(address(0)),
            fee: uint24(3000),
            poolManager: poolManager,
            // 0 ~ 15  hookRegistrationMap = nil
            // 16 ~ 24 tickSpacing = 1
            parameters: bytes32(uint256(0x10000))
        });
        uint160 sqrtPriceX96_100 = uint160(62 * FixedPoint96.Q96);
        poolManager.initialize(poolKey0, sqrtPriceX96_100, new bytes(0));

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
