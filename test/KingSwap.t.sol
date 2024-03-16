// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {KingSwap} from "../src/KingSwap.sol";

import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLPoolManager} from "pancake-v4-core/src/pool-cl/CLPoolManager.sol";
import {CLPoolManagerRouter} from "pancake-v4-core/test/pool-cl/helpers/CLPoolManagerRouter.sol";
import {CLPool} from "pancake-v4-core/src/pool-cl/libraries/CLPool.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {Vault} from "pancake-v4-core/src/Vault.sol";
import {CLSwapRouter} from "pancake-v4-periphery/src/pool-cl/CLSwapRouter.sol";
import {ICLSwapRouter} from "pancake-v4-periphery/src/pool-cl/interfaces/ICLSwapRouter.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {FixedPoint96} from "pancake-v4-core/src/pool-cl/libraries/FixedPoint96.sol";
import {ERC20PermitMock} from "./mocks/ERC20PermitMock.sol";
import {IHooks} from "pancake-v4-core/src/interfaces/IHooks.sol";

contract KingSwapTest is Test {
    KingSwap public kingSwap;

    using PoolIdLibrary for PoolKey;

    IVault public vault;
    ICLPoolManager public poolManager;
    CLPoolManagerRouter public positionManager;
    ICLSwapRouter public router;

    PoolKey public poolKey0;

    address public deployer;

    function setUp() public {
        // WETH weth = new WETH();

        deployer = address(0x1);
        vm.startPrank(deployer);
        vault = new Vault();
        poolManager = new CLPoolManager(vault, 3000);
        vault.registerPoolManager(address(poolManager));
        positionManager = new CLPoolManagerRouter(vault, poolManager);

        // deploy an ERC20Permit token
        ERC20PermitMock usdc = new ERC20PermitMock("USDC", "USDC");

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
        uint160 sqrtPriceX96_100 = uint160(10 * FixedPoint96.Q96);
        poolManager.initialize(poolKey0, sqrtPriceX96_100, new bytes(0));

        usdc.mint(deployer, 1000e6);
        usdc.approve(address(positionManager), 1000e6);
        deal(deployer, 1000 ether);
        positionManager.modifyPosition{value: 25 ether}(
            poolKey0,
            ICLPoolManager.ModifyLiquidityParams({tickLower: -5, tickUpper: 5, liquidityDelta: 1000e6}),
            new bytes(0)
        );
    }

    function testDeployment() public {
        assertTrue(address(poolManager) != address(0));
    }
}
