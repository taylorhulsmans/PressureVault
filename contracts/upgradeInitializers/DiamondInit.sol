// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

/******************************************************************************\
 * Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 *
 * Implementation of a diamond.
/******************************************************************************/

import {LibDiamond} from "../libraries/LibDiamond.sol";
import { IDiamondLoupe } from "../interfaces/IDiamondLoupe.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";
import { IERC173 } from "../interfaces/IERC173.sol";
import { IERC165 } from "../interfaces/IERC165.sol";

import { AppStorage } from '../libraries/LibAppStorage.sol';

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// It is exapected that this contract is customized if you want to deploy your diamond
// with data from a deployment script. Use the init function to initialize state variables
// of your diamond. Add parameters to the init funciton if you need to.

contract DiamondInit {    
  AppStorage internal s;

  // You can add parameters to this function in order to pass in 
  // data to set your own state variables

  /**
   * @param baseThreshold Used to determine base order range
   * @param limitThreshold Used to determine limit order range
   * @param period Can only rebalance if this length of time has passed
   * @param minTickMove Can only rebalance if price has moved at least this much
   * @param maxTwapDeviation Max deviation from TWAP during rebalance
   * @param twapDuration TWAP duration in seconds for deviation check
   * @param keeper Account that can call `rebalance()`
   */
  function init(
    address pool,
    uint256 protocolFee,
    uint256 maxTotalSupply,
    int24 baseThreshold,
    int24 limitThreshold,
    uint256 period,
    int24 minTickMove,
    int24  maxTwapDeviation,
    uint32 twapDuration,
    address keeper
  ) external {
    require(protocolFee < 1e6, "protocolFee");
    // adding ERC165 data
    LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
    ds.supportedInterfaces[type(IERC165).interfaceId] = true;
    ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
    ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
    ds.supportedInterfaces[type(IERC173).interfaceId] = true;

    // add your own state variables 
    // EIP-2535 specifies that the `diamondCut` function takes two optional 
    // arguments: address _init and bytes calldata _calldata
    // These arguments are used to execute an arbitrary function using delegatecall
    // in order to set state variables in the diamond during deployment or an upgrade
    // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface'
    
    // VaultToken
    s.wVTotalSupply = 0;
    s.wVName = 'Warp Vault';
    s.wVSymbol = 'WV';
    s.wVDecimals = 18;

    // AlphaVaultFacet
    s.pool  = IUniswapV3Pool(pool);
    s.token0 = IERC20(IUniswapV3Pool(pool).token0());
    s.token1 = IERC20(IUniswapV3Pool(pool).token1());
    s.tickSpacing = IUniswapV3Pool(pool).tickSpacing();

    s.protocolFee = protocolFee;
    s.maxTotalSupply = maxTotalSupply;

    //PassiveStrategyFacet

    s.baseThreshold = baseThreshold;
    s.limitThreshold = limitThreshold;
    s.period = period;
    s.minTickMove = minTickMove;
    s.maxTwapDeviation = maxTwapDeviation;
    s.twapDuration = twapDuration;
    s.keeper = keeper;

    



    
  }


}
