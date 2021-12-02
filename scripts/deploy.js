const { deploy, getSelectors, ADDRESSZERO } = require('./libraries/diamond.js')
const fromExponential = require('from-exponential')

const DiamondCutFacet = artifacts.require('DiamondCutFacet')
const Diamond = artifacts.require('Diamond')
const DiamondInit = artifacts.require('DiamondInit')
const DiamondLoupeFacet = artifacts.require('DiamondLoupeFacet')
const OwnershipFacet = artifacts.require('OwnershipFacet')
const IDiamondCut = artifacts.require('IDiamondCut')

const AlphaVaultFacet = artifacts.require('AlphaVaultFacet')
const ERC20Facet = artifacts.require('ERC20Facet')
const PassiveStrategyFacet = artifacts.require('PassiveStrategyFacet')

async function deployDiamond() {
  const accounts = await web3.eth.getAccounts()
  const owner = accounts[0]
  const keeper = accounts[1]


  // deploy DiamondCutFacet
  const diamondCutFacet = await deploy(owner, DiamondCutFacet)
  console.log('DiamondCutFacet deployed:', diamondCutFacet._address)
  // deploy Diamond
  const diamond = await deploy(owner, Diamond, [owner, diamondCutFacet._address])

  console.log('Diamond deployed:', diamond._address)
  // deploy DiamondInit
  const diamondInit = await deploy(owner, DiamondInit)
  console.log('DiamondInit deployed:', diamondInit._address)

  const FacetArtifacts = [
    DiamondLoupeFacet,
    OwnershipFacet,
    AlphaVaultFacet,
    ERC20Facet,
    PassiveStrategyFacet
  ]

  const cut = []
  for (const FacetName of FacetArtifacts) {
    const facet = await deploy(owner, FacetName)
    console.log(`deployed: ${facet._address}`)
    cut.push({
      facetAddress: facet._address,
      action: 0,
      functionSelectors: getSelectors(facet)
    })
  }
  console.log('Diamond Cut:', cut)

  const initArgs = [
    '0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8', // address pool, (DAI-ETH 0.3%)
    5000, // uint256 protocolFee,
    fromExponential(2e17), // uint256 maxTotalSupply,
    3600, // int24 baseThreshold,
    1200, // int24 limitThreshold,
    41400, // uint256 period,
    0, // int24 minTickMove,
    100, // int24  maxTwapDeviation,
    60, // uint32 twapDuration,
    keeper// address keeper
  ]

  const diamondCut = await new web3.eth.Contract(IDiamondCut.abi, diamond._address)
  const fnCall = web3.eth.abi.encodeFunctionCall(
    DiamondInit.abi.find((f) => f.name == 'init'),
    initArgs
  )

  const tx = await diamondCut.methods.diamondCut(
    cut,
    diamondInit._address,
    fnCall
  ).send({from:owner})

  return diamond._address
}

if (require.main === module) {
  deployDiamond()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
  })
}

exports.deployDiamond = deployDiamond
