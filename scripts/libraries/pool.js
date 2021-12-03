const BN = require('bignumber.js')

module.exports.TICK_SPACING = {
  "3000": 60
}

module.exports.encodePriceSqrt = function(reserve1, reserve0) {
  let number = new BN(reserve1.toString())
    .div(reserve0.toString())
    .sqrt()
    .multipliedBy(new BN(2).pow(96))
    .integerValue(3)
    .toString()
  return new BN(number)
}

module.exports.getMinTick = (tickSpacing) => Math.ceil(-887272 / tickSpacing) * tickSpacing
module.exports.getMaxTick = (tickSpacing) => Math.floor(887272 / tickSpacing) * tickSpacing
