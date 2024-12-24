FU is a shitpost of a token. It was designed and implemented purely for the
amusement of its authors and its participants. It is, in a sense, blockchain
art. By holding FU, you are participating in this art project. The authors hope
that it brings you joy, because it won't bring you wealth.

While FU is ownerless, decentralized, and great pains have been taken to ensure
that it is bug-free, its authors make no guarantees about its correctness. See
[LICENSE.txt](./LICENSE.txt) for full terms.

# Goals

FU is designed to be maximally vexing for developers to integrate, while still
being technically correct.

## Features

* Unreasonably high decimals (35)
* Reflection (both tax _and_ rebase)
* Tax rate changes depending on the phase of the moon
* Randomly reverts or returns `false` to signal failure
* Randomly returns nothing or returns `true` to signal success
* `symbol` depends on the identity of the caller
* The shares-to-tokens ratio depends on the address of the holder
  * Consequently, `totalSupply` is merely an upper bound on the sum of all
    `balanceOf(...)`
  * Balances are not comparable among addresses
* Anti-whale
  * The anti-whale doesn't prohibit transfers, it just turns transfers above the
    limit into a `deliver`
* Emits extraneous `Transfer` events on each call
  * This breaks some off-chain data pipelines
* Consumes a random, hard-to-predict amount of gas on each call
  * This makes `eth_estimateGas` unreliable

## Restrictions

FU is designed to still be strictly compliant with
[ERC20](https://eips.ethereum.org/EIPS/eip-20) as written. However, to make
things a little more interesting, there are some additional restrictions beyond
what ERC20 literally requires.

* Calls to `transfer` or `transferFrom` reduce the balance of the caller/`from`
  by exactly the specified amount
* Calls to `transfer` or `transferFrom` increase the balance of `to` by a value
  that lies in the range of reasonable interpretations of how it should be
  calculated
  * Lower bound: compute the tax amount exactly, round it up, then deduct it
    from the specified amount
  * Upper bound: exactly compute the specified amount minus the tax, round it up

"Normal" reflection tokens do not have these properties, and the authors adopted
these restrictions primarily to demonstrate mastery of the required numerical
programming techniques. This creates some interesting game-theoretic interplay
where it sometimes becomes advantageous to store tokens in multiple addresses,
so that the holder benefits from the tax applied to their own incoming and
outgoing transfers.

# Implementation

## Extension standards

FU is a full-featured token, supporting the following extensions to the ERC20 standard (with metadata)

 * [ERC2612](https://eips.ethereum.org/EIPS/eip-2612) -- EIP-20 approvals via EIP-712 secp256k1 signatures
 * [ERC5267](https://eips.ethereum.org/EIPS/eip-5267) -- Retrieval of EIP-712 domain
 * [ERC5805](https://eips.ethereum.org/EIPS/eip-5805) -- Voting with delegation
 * [ERC6093](https://eips.ethereum.org/EIPS/eip-6093) -- Custom errors for commonly-used tokens
 * [ERC6372](https://eips.ethereum.org/EIPS/eip-6372) -- Contract clock
 * [ERC7674](https://eips.ethereum.org/EIPS/eip-7674) -- Temporary Approval Extension for ERC-20

## Non-standard extensions

The allowance from each account to Permit2
(0x000000000022D473030F116dDEE9F6B43aC78BA3) is always infinity
(`type(uint256).max`).

 * `tax()(uint256)` (view)
 * `image()(string)` (view)
 * `whaleLimit(address)(uint256)` (view)
 * `burn(uint256)(bool)`
 * `burnFrom(address,uint256)(bool)`
 * `deliver(uint256)(bool)`
 * `deliverFrom(address,uint256)(bool)`

### `GovernorVotesQuorumFraction`

Note that the following non-standard extensions to ERC20 are intended to be used
to interface with an instance of OpenZeppelin's `GovernorVotesQuorumFraction`
contract _**BUT**_ the selectors that implement reading the past "`totalSupply`"
are deliberately incompatible with that contract (without a simple
modification). This is because the current total voting supply is (necessarily)
not `totalSupply`, therefore the signature `getPastTotalSupply` is
misleading. Additionally, FU implements these functions in a way that returns
the _actively delegated_ voting power, not the hypothetical voting power if all
tokens were delegated.

 * `getTotalVotes()(uint256)` (view)
 * `getPastTotalVotes(uint256)(uint256)` (view)

FU is otherwise compatible with the OpenZeppelin Governor suite. The authors
recommend a Governor that inherits from the following OpenZeppelin contracts
(version 5.1.0):

* `Governor`
* `GovernorSettings`
* `GovernorCountingSimple`
* `GovernorVotes`
* `GovernorVotesQuorumFraction` (with the aforementioned modifications)
* `GovernorTimelockControl`
* `GovernorPreventLateQuorum`

Remember that FU uses `block.timestamp` for durations, with a quantum of 1
day. The authors recommend setting the voting delay to 2 days, the voting period
to 1 week, the vote extension period to 4 days, the quorum fraction to 33%, and
the timelock min delay to 2 weeks.

## wFU

A wrapped version of the FU token is not provided. It *could* be easily
implemented as an ERC4626 vault. One should be careful, however, not to trip
over the anti-whale provision of FU. The relative increase of the
`balanceOf(...)` of the vault is a reliable indicator of the value received
during minting (and consequently the amount of shares that should be
minted). However, because the underlying token is a transfer tax token, the
`amount` passed to `transfer` or `transferFrom` is not a reliable indicator of
the balance increase of the `to`. Additionally, wFU must be a tax token to
reflect the transfer tax of the underlying token. For that reason, `transfer`
and `transferFrom` should implement a pattern like:

```Solidity
address internal constant _DEAD = 0xdeaDDeADDEaDdeaDdEAddEADDEAdDeadDEADDEaD;

constructor() {
    assert(uint256(uint160(address(this))) / Settings.ADDRESS_DIVISOR == Settings.CRAZY_BALANCE_BASIS);
    uint256 balance = asset.balanceOf(address(this));
    require(balance >= 1 ether);
    balanceOf[_DEAD] = balance;
    totalSupply = balance;
    emit Transfer(address(0), _DEAD, balance);
}

function _transfer(address from, address to, uint256 amount) internal {
    uint256 balance = asset.balanceOf(address(this));
    uint512 n = alloc().omul(balance, amount * asset.tax());
    uint256 d = totalSupply * BasisPoints.unwrap(BasisPoints.BASIS);
    uint256 taxAmountFu = n.div(d);
    taxAmountFu = taxAmountFu.unsafeInc(tmp().omul(taxAmountFu, d) < n);

    n.omul(taxAmountFu, totalSupply);
    d = balance;
    uint256 taxAmount = n.div(d);
    taxAmount = taxAmount.unsafeInc(tmp().omul(taxAmount, d) < n);

    balanceOf[from] -= amount; // underflow indicates insufficient balance
    unchecked {
        totalSupply -= taxAmount;
        amount -= taxAmount;
        balanceOf[to] += amount;
    }
    emit Transfer(from, to, amount);
    emit Transfer(from, address(0), taxAmount);

    asset.deliver(taxAmountFu);
}
```

Exactly how to fully generalize these concepts to an ERC4626 compatible
tokenized vault while correctly handing rounding error and avoiding inflation
attacks is left as an exercise for the implementer.

# Testing

FU was developed using the [Foundry](https://github.com/foundry-rs/foundry)
framework with [Slither](https://github.com/crytic/slither) for static analysis
and [medusa](https://github.com/crytic/medusa) as a coverage-guided complement
to Foundry's fuzzer.

The differential fuzz tests and invariant/property tests in this repository take
quite a long time to run.

## Install some tools

[Install Foundry](https://book.getfoundry.sh/getting-started/installation)

Install analysis tools from Crytic (Trail of Bits)
```shell
python3 -m pip install --user crytic-compile
python3 -m pip install --user slither-analyzer
```

## Run some tests

```shell
forge test -vvv --fuzz-seed "$(python3 -c 'import secrets; print(secrets.randbelow(2**53))')"
./medusa fuzz # or use your system `medusa`
slither .
```

# Legal

If you're looking for a hot new coin to ape that's gonna give you a good pump,
then this is not the coin for you. The authors are not pumpooors (they're
borderline incompetent with HTML/JS/CSS), and neither are they going to put any
effort into promoting this token to increase it's price. If you want to tell
your friends about it, we can't stop you, but you're probably going to lose them
money by suggesting this to them. This is strictly an art project. Owning this
token is like owning a participation trophy. The trophy is for being determined
enough to actually make a swap happen in spite of all the roadblocks set in the
way.

For developers, if your dApp works with FU, then it will probably work with
every other token on earth. Perhaps there is some utility in having a
maximally-badly-behaved ERC20 token for testing purposes.
