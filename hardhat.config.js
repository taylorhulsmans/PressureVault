require('dotenv').config()
/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require('hardhat-dependency-compiler')

require('@nomiclabs/hardhat-truffle5')
module.exports = {
  solidity: "0.7.6",
  dependencyCompiler: {
    paths: [
      '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol',
      '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol'
    ]
  },

  networks: {
    hardhat: {
      forking: {
        url: process.env.ALCHEMY_ENDPOINT,
        blockNumber:  13722598
      },
      chainId: 1337,
      mining: {
        auto: true,
        //auto: false,
        //interval: 1618
      },
      accounts: {
        mnemonic: process.env.MNEMONIC
      },
    }
  }
};
