// SPDX-License-Identifier: Unlicense

pragma solidity ^0.7.6;

import '../interfaces/IVault.sol';

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

import  { AppStorage, Modifiers } from '../libraries/LibAppStorage.sol';

import './ERC20Facet.sol';

import 'hardhat/console.sol';

contract AlphaVaultFacet is
  IVault,
  IUniswapV3MintCallback,
  IUniswapV3SwapCallback,
  Modifiers
{

  using SafeERC20 for IERC20;

  AppStorage internal s;

  event Deposit(
    address indexed sender,
    address indexed to,
    uint256 shares,
    uint256 amount0,
    uint256 amount1
  );

  event Withdraw(
    address indexed sender,
    address indexed to,
    uint256 shares,
    uint256 amount0,
    uint256 amount1
  );

  event CollectFees(
    uint256 feesToVault0,
    uint256 feesToVault1,
    uint256 feesToProtocol0,
    uint256 feesToProtocol1
  );

  event Snapshot(int24 tick, uint256 totalAmount0, uint256 totalAmount1, uint256 totalSupply);

  function deposit(
    uint256 amount0Desired,
    uint256 amount1Desired,
    uint256 amount0Min,
    uint256 amount1Min,
    address to
  )
  external
  override
  //nonReentrant
  returns (
    uint256 shares,
    uint256 amount0,
    uint256 amount1
  )
  {
    require(amount0Desired > 0 || amount1Desired > 0, "amount0Desired or amount1Desired");
    require(to != address(0) && to != address(this), "to");

    // Poke positions so vault's current holdings are up-to-date
    _poke(s.baseLower, s.baseUpper);
    _poke(s.limitLower, s.limitUpper);

    // Calculate amounts proportional to vault's holdings
    (shares, amount0, amount1) = _calcSharesAndAmounts(amount0Desired, amount1Desired);
    require(shares > 0, "shares");
    require(amount0 >= amount0Min, "amount0Min");
    require(amount1 >= amount1Min, "amount1Min");

    // Pull in tokens from sender
    if (amount0 > 0) s.token0.safeTransferFrom(msg.sender, address(this), amount0);
    if (amount1 > 0) s.token1.safeTransferFrom(msg.sender, address(this), amount1);

    // Mint shares to recipient
    ERC20Facet(address(this)).mint(to, shares);
    emit Deposit(msg.sender, to, shares, amount0, amount1);
    console.log(s.maxTotalSupply, 'max total supply');
    console.log(ERC20Facet(address(this)).totalSupply());
    require(ERC20Facet(address(this)).totalSupply() <= s.maxTotalSupply, "s.maxTotalSupply");
  }

  function _poke(int24 tickLower, int24 tickUpper) internal {
    (uint128 liquidity, , , , ) = _position(tickLower, tickUpper);
    if (liquidity > 0) {
      s.pool.burn(tickLower, tickUpper, 0);
    }
  }

  function _calcSharesAndAmounts(uint256 amount0Desired, uint256 amount1Desired)
  internal
  view
  returns (
    uint256 shares,
    uint256 amount0,
    uint256 amount1
  )
  {
    uint256 totalSupply = ERC20Facet(address(this)).totalSupply();
    (uint256 total0, uint256 total1) = getTotalAmounts();

    // If total supply > 0, vault can't be empty
    assert(totalSupply == 0 || total0 > 0 || total1 > 0);

    if (totalSupply == 0) {
      // For first deposit, just use the amounts desired
      amount0 = amount0Desired;
      amount1 = amount1Desired;
      shares = Math.max(amount0, amount1);
    } else if (total0 == 0) {
      amount1 = amount1Desired;
      shares = amount1 *(totalSupply) / (total1);
    } else if (total1 == 0) {
      amount0 = amount0Desired;
      shares = amount0 * (totalSupply) / (total0);
    } else {
      uint256 cross = Math.min(amount0Desired * total1, amount1Desired * (total0));
      require(cross > 0, "cross");

      // Round up amounts
      amount0 = cross - (1) / total1 + (1);
      amount1 = cross - (1) / (total0) + (1);
      shares = cross * (totalSupply) / (total0) / (total1);
    }
  }

  function withdraw(
    uint256 shares,
    uint256 amount0Min,
    uint256 amount1Min,
    address to
  ) external override /*nonReentrant*/ returns (uint256 amount0, uint256 amount1) {
    require(shares > 0, "shares");
    require(to != address(0) && to != address(this), "to");
    uint256 totalSupply = ERC20Facet(address(this)).totalSupply();

    // Burn shares
    ERC20Facet(address(this)).burn(msg.sender, shares);

    // Calculate token amounts proportional to unused balances
    uint256 unusedAmount0 = getBalance0() * (shares) / (totalSupply);
    uint256 unusedAmount1 = getBalance1() * (shares) / (totalSupply);

    // Withdraw proportion of liquidity from Uniswap s.pool
    (uint256 baseAmount0, uint256 baseAmount1) =
      _burnLiquidityShare(s.baseLower, s.baseUpper, shares, totalSupply);
    (uint256 limitAmount0, uint256 limitAmount1) =
      _burnLiquidityShare(s.limitLower, s.limitUpper, shares, totalSupply);

    // Sum up total amounts owed to recipient
    amount0 = unusedAmount0 + (baseAmount0) + (limitAmount0);
    amount1 = unusedAmount1 + (baseAmount1) + (limitAmount1);
    require(amount0 >= amount0Min, "amount0Min");
    require(amount1 >= amount1Min, "amount1Min");

    // Push tokens to recipient
    if (amount0 > 0) s.token0.safeTransfer(to, amount0);
    if (amount1 > 0) s.token1.safeTransfer(to, amount1);

    emit Withdraw(msg.sender, to, shares, amount0, amount1);
  }

  /// @dev Withdraws share of liquidity in a range from Uniswap s.pool.
  function _burnLiquidityShare(
    int24 tickLower,
    int24 tickUpper,
    uint256 shares,
    uint256 totalSupply
  ) internal returns (uint256 amount0, uint256 amount1) {
    (uint128 totalLiquidity, , , , ) = _position(tickLower, tickUpper);
    uint256 liquidity = uint256(totalLiquidity) * (shares) / (totalSupply);

    if (liquidity > 0) {
      (uint256 burned0, uint256 burned1, uint256 fees0, uint256 fees1) =
        _burnAndCollect(tickLower, tickUpper, _toUint128(liquidity));

      // Add share of fees
      amount0 = burned0 + (fees0 *(shares) / (totalSupply));
      amount1 = burned1 + (fees1 * (shares) / (totalSupply));
    }
  }

  function rebalance(
    int256 swapAmount,
    uint160 sqrtPriceLimitX96,
    int24 _baseLower,
    int24 _baseUpper,
    int24 _bidLower,
    int24 _bidUpper,
    int24 _askLower,
    int24 _askUpper
  ) external /*nonReentrant*/ {
    require(msg.sender == s.strategy, "s.s.strategy");
    _checkRange(_baseLower, _baseUpper);
    _checkRange(_bidLower, _bidUpper);
    _checkRange(_askLower, _askUpper);

    (, int24 tick, , , , , ) = s.pool.slot0();
    require(_bidUpper <= tick, "bidUpper");
    require(_askLower > tick, "askLower"); // inequality is strict as tick is rounded down

    // Withdraw all current liquidity from Uniswap s.pool
    {
      (uint128 baseLiquidity, , , , ) = _position(s.baseLower, s.baseUpper);
      (uint128 limitLiquidity, , , , ) = _position(s.limitLower, s.limitUpper);
      _burnAndCollect(s.baseLower, s.baseUpper, baseLiquidity);
      _burnAndCollect(s.limitLower, s.limitUpper, limitLiquidity);
    }

    // Emit snapshot to record balances and supply
    uint256 balance0 = getBalance0();
    uint256 balance1 = getBalance1();
    emit Snapshot(tick, balance0, balance1, ERC20Facet(address(this)).totalSupply());

    if (swapAmount != 0) {
      s.pool.swap(
        address(this),
        swapAmount > 0,
        swapAmount > 0 ? swapAmount : -swapAmount,
        sqrtPriceLimitX96,
        ""
      );
      balance0 = getBalance0();
      balance1 = getBalance1();
    }

    // Place base order on Uniswap
    uint128 liquidity = _liquidityForAmounts(_baseLower, _baseUpper, balance0, balance1);
    _mintLiquidity(_baseLower, _baseUpper, liquidity);
    (s.baseLower, s.baseUpper) = (_baseLower, _baseUpper);

    balance0 = getBalance0();
    balance1 = getBalance1();

    // Place bid or ask order on Uniswap depending on which token is left
    uint128 bidLiquidity = _liquidityForAmounts(_bidLower, _bidUpper, balance0, balance1);
    uint128 askLiquidity = _liquidityForAmounts(_askLower, _askUpper, balance0, balance1);
    if (bidLiquidity > askLiquidity) {
      _mintLiquidity(_bidLower, _bidUpper, bidLiquidity);
      (s.limitLower, s.limitUpper) = (_bidLower, _bidUpper);
    } else {
      _mintLiquidity(_askLower, _askUpper, askLiquidity);
      (s.limitLower, s.limitUpper) = (_askLower, _askUpper);
    }
  }

  function _checkRange(int24 tickLower, int24 tickUpper) internal view {
    int24 _tickSpacing = s.tickSpacing;
    require(tickLower < tickUpper, "tickLower < tickUpper");
    require(tickLower >= TickMath.MIN_TICK, "tickLower too low");
    require(tickUpper <= TickMath.MAX_TICK, "tickUpper too high");
    require(tickLower % _tickSpacing == 0, "tickLower % s.tickSpacing");
    require(tickUpper % _tickSpacing == 0, "tickUpper % s.tickSpacing");
  }

  /// @dev Withdraws liquidity from a range and collects all fees in the
  /// process.
  function _burnAndCollect(
    int24 tickLower,
    int24 tickUpper,
    uint128 liquidity
  )
  internal
  returns (
    uint256 burned0,
    uint256 burned1,
    uint256 feesToVault0,
    uint256 feesToVault1
  )
  {
    if (liquidity > 0) {
      (burned0, burned1) = s.pool.burn(tickLower, tickUpper, liquidity);
    }

    // Collect all owed tokens including earned fees
    (uint256 collect0, uint256 collect1) =
      s.pool.collect(
        address(this),
    tickLower,
    tickUpper,
    type(uint128).max,
    type(uint128).max
    );

    feesToVault0 = collect0 - (burned0);
    feesToVault1 = collect1 - (burned1);
    uint256 feesToProtocol0;
    uint256 feesToProtocol1;

    // Update accrued protocol fees
    uint256 _protocolFee = s.protocolFee;
    if (_protocolFee > 0) {
      feesToProtocol0 = feesToVault0 * (_protocolFee) / (1e6);
      feesToProtocol1 = feesToVault1 * (_protocolFee) / (1e6);
      feesToVault0 = feesToVault0 - (feesToProtocol0);
      feesToVault1 = feesToVault1 - (feesToProtocol1);
      s.accruedProtocolFees0 = s.accruedProtocolFees0 + (feesToProtocol0);
      s.accruedProtocolFees1 = s.accruedProtocolFees1 + (feesToProtocol1);
    }
    emit CollectFees(feesToVault0, feesToVault1, feesToProtocol0, feesToProtocol1);
  }

  /// @dev Deposits liquidity in a range on the Uniswap s.pool.
  function _mintLiquidity(
    int24 tickLower,
    int24 tickUpper,
    uint128 liquidity
  ) internal {
    if (liquidity > 0) {
      s.pool.mint(address(this), tickLower, tickUpper, liquidity, "");
    }
  }

  /**
  * @notice Calculates the vault's total holdings of s.token0 and s.token1 - in
  * other words, how much of each token the vault would hold if it withdrew
  * all its liquidity from Uniswap.
    */
  function getTotalAmounts() public view override returns (uint256 total0, uint256 total1) {
    (uint256 baseAmount0, uint256 baseAmount1) = getPositionAmounts(s.baseLower, s.baseUpper);
    (uint256 limitAmount0, uint256 limitAmount1) =
      getPositionAmounts(s.limitLower, s.limitUpper);
    total0 = getBalance0() + (baseAmount0) + (limitAmount0);
    total1 = getBalance1() + (baseAmount1) + (limitAmount1);
  }

  /**
  * @notice Amounts of s.token0 and s.token1 held in vault's position. Includes
  * owed fees but excludes the proportion of fees that will be paid to the
  * protocol. Doesn't include fees accrued since last poke.
  */
  function getPositionAmounts(int24 tickLower, int24 tickUpper)
  public
  view
  returns (uint256 amount0, uint256 amount1)
  {
    (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) =
      _position(tickLower, tickUpper);
    (amount0, amount1) = _amountsForLiquidity(tickLower, tickUpper, liquidity);

    // Subtract protocol fees
    uint256 oneMinusFee = uint256(1e6) - (s.protocolFee);
    amount0 = amount0 + (uint256(tokensOwed0) * (oneMinusFee) / (1e6));
    amount1 = amount1 + (uint256(tokensOwed1) * (oneMinusFee) / (1e6));
  }

  /**
  * @notice Balance of s.token0 in vault not used in any position.
  */
  function getBalance0() public view returns (uint256) {
    return s.token0.balanceOf(address(this)) - (s.accruedProtocolFees0);
  }

  /**
  * @notice Balance of s.token1 in vault not used in any position.
  */
  function getBalance1() public view returns (uint256) {
    return s.token1.balanceOf(address(this)) - (s.accruedProtocolFees1);
  }

  /// @dev Wrapper around `IUniswapV3Pool.positions()`.
  function _position(int24 tickLower, int24 tickUpper)
  internal
  view
  returns (
    uint128,
    uint256,
    uint256,
    uint128,
    uint128
  )
  {
    console.log('tickLower', uint256(tickLower));
    bytes32 positionKey = PositionKey.compute(address(this), tickLower, tickUpper);
    console.log('poolTest', s.poolTest);
    return IUniswapV3Pool(s.poolTest).positions(positionKey);
    //return s.pool.positions(positionKey);
  }

  /// @dev Wrapper around `LiquidityAmounts.getAmountsForLiquidity()`.
  function _amountsForLiquidity(
    int24 tickLower,
    int24 tickUpper,
    uint128 liquidity
  ) internal view returns (uint256, uint256) {
    (uint160 sqrtRatioX96, , , , , , ) = s.pool.slot0();
    return
    LiquidityAmounts.getAmountsForLiquidity(
      sqrtRatioX96,
      TickMath.getSqrtRatioAtTick(tickLower),
      TickMath.getSqrtRatioAtTick(tickUpper),
      liquidity
    );
  }

  /// @dev Wrapper around `LiquidityAmounts.getLiquidityForAmounts()`.
  function _liquidityForAmounts(
    int24 tickLower,
    int24 tickUpper,
    uint256 amount0,
    uint256 amount1
  ) internal view returns (uint128) {
    (uint160 sqrtRatioX96, , , , , , ) = s.pool.slot0();
    return
    LiquidityAmounts.getLiquidityForAmounts(
      sqrtRatioX96,
      TickMath.getSqrtRatioAtTick(tickLower),
      TickMath.getSqrtRatioAtTick(tickUpper),
      amount0,
      amount1
    );
  }

  /// @dev Casts uint256 to uint128 with overflow check.
  function _toUint128(uint256 x) internal pure returns (uint128) {
    assert(x <= type(uint128).max);
    return uint128(x);
  }

  /// @dev Callback for Uniswap V3 s.pool.
  function uniswapV3MintCallback(
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) external override {
    require(msg.sender == address(s.pool));
    if (amount0 > 0) s.token0.safeTransfer(msg.sender, amount0);
    if (amount1 > 0) s.token1.safeTransfer(msg.sender, amount1);
  }

  /// @dev Callback for Uniswap V3 s.pool.
  function uniswapV3SwapCallback(
    int256 amount0Delta,
    int256 amount1Delta,
    bytes calldata data
  ) external override {
    require(msg.sender == address(s.pool));
    if (amount0Delta > 0) s.token0.safeTransfer(msg.sender, uint256(amount0Delta));
    if (amount1Delta > 0) s.token1.safeTransfer(msg.sender, uint256(amount1Delta));
  }

  /**
  * @notice Used to collect accumulated protocol fees.
  */
  function collectProtocol(
    uint256 amount0,
    uint256 amount1,
    address to
  ) external onlyOwner {
    s.accruedProtocolFees0 = s.accruedProtocolFees0 - (amount0);
    s.accruedProtocolFees1 = s.accruedProtocolFees1 - (amount1);
    if (amount0 > 0) s.token0.safeTransfer(to, amount0);
    if (amount1 > 0) s.token1.safeTransfer(to, amount1);
  }

  /**
  * @notice Removes tokens accidentally sent to this vault.
  */
  function sweep(
    IERC20 token,
    uint256 amount,
    address to
  ) external onlyOwner {
    require(token != s.token0 && token != s.token1, "token");
    token.safeTransfer(to, amount);
  }
  
  /**
   * @notice Used to set the s.strategy contract that determines the position
   * ranges and calls rebalance(). Must be called after this vault is
   * deployed.
   */
  function setStrategy(address strategy) external onlyOwner {
    s.strategy = strategy;
  }

  /**
  * @notice Used to change the protocol fee charged on pool fees earned from
  * Uniswap, expressed as multiple of 1e-6.
    */
  function setProtocolFee(uint256 protocolFee) external onlyOwner {
    require(protocolFee < 1e6, "s.protocolFee");
    s.protocolFee = protocolFee;
  }

  /**
  * @notice Used to change deposit cap for a guarded launch or to ensure
  * vault doesn't grow too large relative to the pool. Cap is on total
  * supply rather than amounts of token0 and token1 as those amounts
  * fluctuate naturally over time.
    */
  function setMaxTotalSupply(uint256 maxTotalSupply) external onlyOwner {
    s.maxTotalSupply = maxTotalSupply;
  }

  /**
  * @notice Removes liquidity in case of emergency.
  */
  function emergencyBurn(
    int24 tickLower,
    int24 tickUpper,
    uint128 liquidity
  ) external onlyOwner {
    s.pool.burn(tickLower, tickUpper, liquidity);
    s.pool.collect(address(this), tickLower, tickUpper, type(uint128).max, type(uint128).max);
  }

  /**
  * @notice Governance address is not updated until the new s.governance
  * address has called `acceptGovernance()` to accept this responsibility.
    */
  function setGovernance(address governance) external onlyOwner {
    s.pendingGovernance = governance;
  }

  /**
  * @notice `setGovernance()` should be called by the existing s.governance
  * address prior to calling this function.
    */
  function acceptGovernance() external {
    require(msg.sender == s.pendingGovernance, "s.pendingGovernance");
    s.governance = msg.sender;
  }

}


