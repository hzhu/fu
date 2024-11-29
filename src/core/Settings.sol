// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ReflectMath} from "./ReflectMath.sol";

import {BasisPoints, BASIS} from "../types/BasisPoints.sol";
import {Shares} from "../types/Shares.sol";
import {Balance} from "../types/Balance.sol";
import {BalanceXShares, alloc, tmp} from "../types/BalanceXShares.sol";

import {UnsafeMath} from "../lib/UnsafeMath.sol";

library Settings {
    using UnsafeMath for uint256;

    uint256 internal constant INITIAL_LIQUIDITY_DIVISOR = 10;
    // This constant can be set as low as 4 without breaking anything. Setting it near to
    // INITIAL_LIQUIDITY_DIVISOR will cause unexpected reverts.
    // TODO: verify that it's still possible to `deliver` without serious issue even when the
    // balance is well above the limit
    uint256 internal constant ANTI_WHALE_DIVISOR = 4;

    BasisPoints internal constant MIN_TAX = BasisPoints.wrap(1);
    // A tax above `BASIS / 2` makes ReflectMath break down
    BasisPoints internal constant MAX_TAX = BasisPoints.wrap(BasisPoints.unwrap(BASIS) / 2);

    uint256 private constant _UNISWAPV2_MAX_BALANCE = type(uint112).max;

    uint8 internal constant DECIMALS = 36;
    Balance internal constant INITIAL_SUPPLY = Balance.wrap(_UNISWAPV2_MAX_BALANCE * type(uint32).max);
    Shares internal constant INITIAL_SHARES = Shares.wrap(Balance.unwrap(INITIAL_SUPPLY) << 32);

    uint256 internal constant INITIAL_SHARES_RATIO = Shares.unwrap(INITIAL_SHARES) / Balance.unwrap(INITIAL_SUPPLY);
    uint256 internal constant MIN_SHARES_RATIO = 2; // below this, ReflectMath breaks down

    uint256 internal constant CRAZY_BALANCE_BASIS = Balance.unwrap(INITIAL_SUPPLY) / _UNISWAPV2_MAX_BALANCE;
    uint256 internal constant ADDRESS_DIVISOR = 2 ** 160 / (CRAZY_BALANCE_BASIS + 1);

    // This constant is intertwined with a bunch of constants in `Checkpoints.sol` because Solidity
    // has poor support for introspecting the range of user-defined types and for defining constants
    // dependant on values in other translation units. If you change this, make appropriate changes
    // over there, and be sure to run the invariant/property tests.
    uint256 internal constant SHARES_TO_VOTES_DIVISOR = 2 ** 32;

    function oneTokenInShares() internal pure returns (Shares) {
        BalanceXShares initialSharesTimesOneToken = alloc().omul(INITIAL_SHARES, Balance.wrap(10 ** DECIMALS));
        Shares result = initialSharesTimesOneToken.div(INITIAL_SUPPLY);
        result = result.inc(tmp().omul(result, INITIAL_SUPPLY) < initialSharesTimesOneToken);
        return result;
    }
}
