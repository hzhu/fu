// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Shares} from "./Shares.sol";
import {Balance} from "./Balance.sol";

import {uint512, tmp as baseTmp, alloc as baseAlloc} from "../../lib/512Math.sol";

type BalanceXShares is bytes32;

function cast(BalanceXShares x) pure returns (uint512) {
    return uint512.wrap(BalanceXShares.unwrap(x));
}

function cast(uint512 x) pure returns (BalanceXShares) {
    return BalanceXShares.wrap(uint512.unwrap(x));
}

function alloc() pure returns (BalanceXShares) {
    return cast(baseAlloc());
}

function tmp() pure returns (BalanceXShares) {
    return cast(baseTmp());
}

library BalanceXSharesArithmetic {
    function oadd(BalanceXShares r, BalanceXShares x, BalanceXShares y) internal pure returns (BalanceXShares) {
        return cast(cast(r).oadd(cast(x), cast(y)));
    }

    function osub(BalanceXShares r, BalanceXShares x, BalanceXShares y) internal pure returns (BalanceXShares) {
        return cast(cast(r).osub(cast(x), cast(y)));
    }

    function omul(BalanceXShares r, Balance b, Shares s) internal pure returns (BalanceXShares) {
        return cast(cast(r).omul(Balance.unwrap(b), Shares.unwrap(s)));
    }

    function omul(BalanceXShares r, Shares s, Balance b) internal pure returns (BalanceXShares) {
        return cast(cast(r).omul(Shares.unwrap(s), Balance.unwrap(b)));
    }

    function div(BalanceXShares n, Balance d) internal pure returns (Shares) {
        return Shares.wrap(cast(n).div(Balance.unwrap(d)));
    }

    function div(BalanceXShares n, Shares d) internal pure returns (Balance) {
        return Balance.wrap(cast(n).div(Shares.unwrap(d)));
    }
}

using BalanceXSharesArithmetic for BalanceXShares global;

function __eq(BalanceXShares a, BalanceXShares b) pure returns (bool) {
    return cast(a) == cast(b);
}

function __lt(BalanceXShares a, BalanceXShares b) pure returns (bool) {
    return cast(a) < cast(b);
}

function __gt(BalanceXShares a, BalanceXShares b) pure returns (bool) {
    return cast(a) > cast(b);
}

function __ne(BalanceXShares a, BalanceXShares b) pure returns (bool) {
    return cast(a) != cast(b);
}

function __le(BalanceXShares a, BalanceXShares b) pure returns (bool) {
    return cast(a) <= cast(b);
}

function __ge(BalanceXShares a, BalanceXShares b) pure returns (bool) {
    return cast(a) >= cast(b);
}

using {__eq as ==, __lt as <, __gt as >, __ne as !=, __le as <=, __ge as >=} for BalanceXShares global;

library SharesToBalance {
    function toBalance(Shares shares, Balance totalSupply, Shares totalShares) internal pure returns (Balance) {
        return tmp().omul(shares, totalSupply).div(totalShares);
    }
}