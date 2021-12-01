pragma solidity ^0.7.6;

pragma abicoder v2;
import { LibDiamond } from "../libraries/LibDiamond.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


struct AppStorage {
  
  // ERC20 Facet  
  mapping(address => uint256) wVBalances;
  mapping(address => mapping(address => uint256))  wVAllowances;
  uint256 wVTotalSupply;

  string wVName;
  string wVSymbol;
  uint8 wVDecimals;

  // Alpha Vault Facet
  IUniswapV3Pool   pool;
  IERC20   token0;
  IERC20   token1;
  int24   tickSpacing;

  uint256  protocolFee;
  uint256  maxTotalSupply;
  address  strategy;
  address  governance;
  address  pendingGovernance;

  int24  baseLower;
  int24  baseUpper;
  int24  limitLower;
  int24  limitUpper;
  uint256  accruedProtocolFees0;
  uint256  accruedProtocolFees1;

  //PassiveStrategy
  int24 baseThreshold;
  int24 limitThreshold;
  uint256 period;
  int24 minTickMove;
  int24 maxTwapDeviation;
  uint32 twapDuration;
  address keeper;

  uint256 lastTimestamp;
  int24 lastTick;

}


library LibAppStorage {
  function diamondStorage() internal pure returns (AppStorage storage ds) {
    assembly {
      ds.slot := 0
    }
  }
}

contract Modifiers {
  modifier onlyDiamond() {
    require(msg.sender == address(this), "LibAppStorage: Caller Must be Diamond");
    _;
  }
  modifier onlyOwner {
    LibDiamond.enforceIsContractOwner();
    _;
  }
}
