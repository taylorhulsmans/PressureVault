const { deployDiamond } = require('../scripts/deploy.js')
const { ADDRESSZERO, getSelectors, deploy  } = require('../scripts/libraries/diamond.js')

const DiamondCutFacet = artifacts.require('DiamondCutFacet')
const DiamondLoupeFacet = artifacts.require('DiamondLoupeFacet')
const OwnershipFacet = artifacts.require('OwnershipFacet')

const ERC20Facet = artifacts.require('ERC20Facet')
const AlphaVaultFacet = artifacts.require('AlphaVaultFacet')
const PassiveStrategyFacet = artifacts.require('PassiveStrategyFacet')

contract("Diamond", (accounts) => {
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

  it("is 6 facets", async () => {
    const addrs = await diamondLoupeFacet.methods.facetAddresses().call()
    for (const address of await diamondLoupeFacet.methods.facetAddresses().call()) {
      addresses.push(address)
    }
    assert.equal(addresses.length, 6)
  })

  it("has correct selectors", async () => {
    let selectors = getSelectors(diamondCutFacet)
    result = await diamondLoupeFacet.methods.facetFunctionSelectors(addresses[0]).call()
    assert.sameMembers(result, selectors)
    selectors = getSelectors(diamondLoupeFacet)
    result = await diamondLoupeFacet.methods.facetFunctionSelectors(addresses[1]).call()
    assert.sameMembers(result, selectors)
    selectors = getSelectors(ownershipFacet)
    result = await diamondLoupeFacet.methods.facetFunctionSelectors(addresses[2]).call()
    assert.sameMembers(result, selectors)
    selectors = getSelectors(alphaVaultFacet)
    result = await diamondLoupeFacet.methods.facetFunctionSelectors(addresses[3]).call()
    assert.sameMembers(result, selectors)
    selectors = getSelectors(erc20Facet)
    result = await diamondLoupeFacet.methods.facetFunctionSelectors(addresses[4]).call()
    assert.sameMembers(result, selectors)
    selectors = getSelectors(passiveStrategyFacet)
    result = await diamondLoupeFacet.methods.facetFunctionSelectors(addresses[5]).call()
    assert.sameMembers(result, selectors)
  })

})











