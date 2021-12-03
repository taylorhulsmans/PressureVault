const { deployDiamond } = require('../scripts/deploy.js')
const { ADDRESSZERO, getSelectors, deploy  } = require('../scripts/libraries/diamond.js')

const ERC20Facet = artifacts.require('ERC20Facet')
const AlphaVaultFacet = artifacts.require('AlphaVaultFacet')
const PassiveStrategyFacet = artifacts.require('PassiveStrategyFacet')

contract("Passive Strategy", (accounts) => {
  const owner = accounts[0]

  let diamondCutFacet;
  let diamondLoupeFacet;
  let ownershipFacet;

  let erc20Facet;
  let alphaVaultFacet;
  let passiveStrategyFacet;

  const addresses = []

  before(async () => {
    const diamondAddress = await deployDiamond()

    diamondCutFacet = new web3.eth.Contract(DiamondCutFacet.abi, diamondAddress)
    diamondLoupeFacet = new web3.eth.Contract(DiamondLoupeFacet.abi, diamondAddress)
    ownershipFacet = new web3.eth.Contract(OwnershipFacet.abi, diamondAddress)

    erc20Facet = new web3.eth.Contract(ERC20Facet.abi, diamondAddress)
    alphaVaultFacet = new web3.eth.Contract(AlphaVaultFacet.abi, diamondAddress)
    passiveStrategyFacet = new web3.eth.Contract(PassiveStrategyFacet.abi, diamondAddress)
  })

  it("rebalances", async () => {

  })
})
