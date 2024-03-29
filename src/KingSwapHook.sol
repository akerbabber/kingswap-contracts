// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@pancakeswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLBaseHook} from "./baseHook/CLBaseHook.sol";

import {console, console2} from "forge-std/Test.sol";

/// @notice CLCounterHook is a contract that counts the number of times a hook is called
/// @dev note the code is not production ready, it is only to share how a hook looks like
contract KingSwapHook is CLBaseHook {
    using PoolIdLibrary for PoolKey;

    uint256 public gasTracker;

    constructor(ICLPoolManager _poolManager) CLBaseHook(_poolManager) {}

    fallback() external payable {}

    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return _hooksRegistrationBitmapFrom(
            Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                noOp: false
            })
        );
    }

    function beforeSwap(address, PoolKey calldata key, ICLPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        poolManagerOnly
        returns (bytes4)
    {
        gasTracker = gasleft();
        return this.beforeSwap.selector;
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        ICLPoolManager.SwapParams calldata swapParams,
        BalanceDelta balanceDelta,
        bytes calldata hookParams
    ) external override poolManagerOnly returns (bytes4) {
        gasTracker = gasTracker - gasleft();
        uint256 gasPrice = tx.gasprice;
        uint256 gasCost = gasTracker * gasPrice;
        address payable receiver = abi.decode(hookParams, (address));
        payable(tx.origin).transfer(gasCost);
        payable(receiver).transfer(address(this).balance);
        gasTracker = 0; //commented because i need to check the gas used
        return this.afterSwap.selector;
    }
}
