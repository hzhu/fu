// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BasisPoints, BASIS} from "./BasisPoints.sol";
import {Tokens} from "./Tokens.sol";

import {UnsafeMath} from "../lib/UnsafeMath.sol";

/// This type is given as `uint256` for efficiency, but it is actually only 158 bits.
type TokensXBasisPoints is uint256;

function scale(Tokens s, BasisPoints bp) pure returns (TokensXBasisPoints) {
    unchecked {
        return TokensXBasisPoints.wrap(Tokens.unwrap(s) * BasisPoints.unwrap(bp));
    }
}

function castUp(TokensXBasisPoints sbp) pure returns (Tokens) {
    return Tokens.wrap(UnsafeMath.unsafeDivUp(TokensXBasisPoints.unwrap(sbp), BasisPoints.unwrap(BASIS)));
}
