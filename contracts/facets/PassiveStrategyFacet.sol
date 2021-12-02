// SPDX-License-Identifier: Unlicense

pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import "./AlphaVaultFacet.sol";
import "../interfaces/IStrategy.sol";

import {AppStorage, Modifiers} from '../libraries/LibAppStorage.sol';
/**
 * @title   Passive Strategy
 * @notice  Rebalancing strategy for Alpha Vault that maintains the two
 *          following range orders:
 *
 *          1. Base order is placed between X - B and X + B + TS.
 *          2. Limit order is placed between X - L and X, or between X + TS
 *             and X + L + TS, depending on which token it holds more of.
 *
 *          where:
 *
 *              X = current tick rounded down to multiple of tick spacing
 *              TS = tick spacing
 *              B = base threshold
 *              L = limit threshold
 *
 *          Note that after these two orders, the vault should have deposited
 *          all its tokens and should only have a few wei left.
 *
 *          Because the limit order tries to sell whichever token the vault
 *          holds more of, the vault's holdings will have a tendency to get
 *          closer to a 1:1 balance. This enables it to continue providing
 *          liquidity without running out of inventory of either token, and
 *          achieves this without the need to swap directly on Uniswap and pay
 *          fees.
 */
contract PassiveStrategyFacet is IStrategy, Modifiers {
  AppStorage internal s;
  /**
  * @notice Calculates new ranges for orders and calls `vault.rebalance()`
  * so that vault can update its positions. Can only be called by s.keeper.
   */
  function rebalance() external override  {
    require(shouldRebalance(), "cannot rebalance");

    (, int24 tick, , , , , ) = s.pool.slot0();
    int24 tickFloor = _floor(tick);
    int24 tickCeil = tickFloor + s.tickSpacing;

    AlphaVaultFacet(address(this)).rebalance(
      0,
      0,
      tickFloor - s.baseThreshold,
      tickCeil + s.baseThreshold,
      tickFloor - s.limitThreshold,
      tickFloor,
      tickCeil,
      tickCeil + s.limitThreshold
    );

    s.lastTimestamp = block.timestamp;
    s.lastTick = tick;
  }

  function shouldRebalance() public view override returns (bool) {
    // check called by s.keeper
    if (msg.sender != s.keeper) {
      return false;
    }

    // check enough time has passed
    if (block.timestamp < s.lastTimestamp + (s.period)) {
      return false;
    }

    // check price has moved enough
    (, int24 tick, , , , , ) = s.pool.slot0();
    int24 tickMove = tick > s.lastTick ? tick - s.lastTick : s.lastTick - tick;
    if (tickMove < s.minTickMove) {
      return false;
    }

    // check price near twap
    int24 twap = getTwap();
    int24 twapDeviation = tick > twap ? tick - twap : twap - tick;
    if (twapDeviation > s.maxTwapDeviation) {
      return false;
    }

    // check price not too close to boundary
    int24 maxThreshold = s.baseThreshold > s.limitThreshold ? s.baseThreshold : s.limitThreshold;
    if (
      tick < TickMath.MIN_TICK + maxThreshold + s.tickSpacing ||
        tick > TickMath.MAX_TICK - maxThreshold - s.tickSpacing
    ) {
      return false;
    }

    return true;
  }

  /// @dev Fetches time-weighted average price in ticks from Uniswap pool.
  function getTwap() public view returns (int24) {
    uint56 twapDuration = uint56(s.twapDuration);
    uint32[] memory secondsAgo = new uint32[](2);
    secondsAgo[0] = s.twapDuration;
    secondsAgo[1] = 0;

    (int56[] memory tickCumulatives, ) = s.pool.observe(secondsAgo);

    return int24((tickCumulatives[1] - tickCumulatives[0]) / int56(twapDuration));
  }

  /// @dev Rounds tick down towards negative infinity so that it's a multiple
  /// of `s.tickSpacing`.
  function _floor(int24 tick) internal view returns (int24) {
    int24 compressed = tick / s.tickSpacing;
    if (tick < 0 && tick % s.tickSpacing != 0) compressed--;
    return compressed * s.tickSpacing;
  }

  function _checkThreshold(int24 threshold, int24 _tickSpacing) internal pure {
    require(threshold > 0, "threshold must be > 0");
    require(threshold <= TickMath.MAX_TICK, "threshold too high");
    require(threshold % _tickSpacing == 0, "threshold must be multiple of s.tickSpacing");
  }

  function setKeeper(address keeper) external onlyOwner {
    s.keeper = keeper;
  }

  function setBaseThreshold(int24 baseThreshold) external onlyOwner {
    _checkThreshold(baseThreshold, s.tickSpacing);
    s.baseThreshold = baseThreshold;
  }

  function setLimitThreshold(int24 limitThreshold) external onlyOwner {
    _checkThreshold(limitThreshold, s.tickSpacing);
    s.limitThreshold = limitThreshold;
  }

  function setPeriod(uint256 period) external onlyOwner {
    s.period = period;
  }

  function setMinTickMove(int24 minTickMove) external onlyOwner {
    require(minTickMove >= 0, "s.minTickMove must be >= 0");
    s.minTickMove = minTickMove;
  }

  function setMaxTwapDeviation(int24 maxTwapDeviation) external onlyOwner {
    require(maxTwapDeviation >= 0, "s.maxTwapDeviation must be >= 0");
    s.maxTwapDeviation = maxTwapDeviation;
  }

  function setTwapDuration(uint32 twapDuration) external onlyOwner {
    require(twapDuration > 0, "s.twapDuration must be > 0");
    s.twapDuration = twapDuration;
  }

  /// @dev Uses same governance as underlying vault.
}
