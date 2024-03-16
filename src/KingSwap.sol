// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {CLSwapRouter} from "pancake-v4-periphery/src/pool-cl/CLSwapRouter.sol";
import {ICLSwapRouterBase} from "pancake-v4-periphery/src/pool-cl/interfaces/ICLSwapRouterBase.sol";
import {Currency} from "pancake-v4-core/src/types/Currency.sol";

/// @title KingSwap
/// @notice This contract is used to swap tokens that are compatible with the ERC20Permit standard.
/// @notice It interfaces with PancakeSwap v4 to provide gasless swaps.
/// @notice It also provides a way to swap tokens with a single transaction.
/// @author KingSwap team

contract KingSwap {
    /// @notice The address of the PancakeSwap router.
    CLSwapRouter public immutable router;

    constructor(CLSwapRouter _router) {
        router = _router;
    }

    function swap(
        ICLSwapRouterBase.V4CLExactInputParams calldata params,
        uint256 amount,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit fromToken = IERC20Permit(Currency.unwrap(params.currencyIn));
        fromToken.permit(msg.sender, address(this), type(uint256).max, type(uint256).max, v, r, s);
        IERC20(address(fromToken)).transferFrom(msg.sender, address(this), amount);
        router.exactInput(params, block.timestamp);
    }

    function swapSingle(
        ICLSwapRouterBase.V4CLExactInputSingleParams calldata params,
        address from,
        uint256 amount,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit fromToken;
        if (params.zeroForOne) {
            fromToken = IERC20Permit(Currency.unwrap(params.poolKey.currency0));
        } else {
            fromToken = IERC20Permit(Currency.unwrap(params.poolKey.currency1));
        }
        fromToken.permit(from, address(this), amount, permitDeadline, v, r, s);
        IERC20(address(fromToken)).transferFrom(from, address(this), amount);
        IERC20(address(fromToken)).approve(address(router), type(uint256).max);
        router.exactInputSingle(params, type(uint256).max);
    }
}
