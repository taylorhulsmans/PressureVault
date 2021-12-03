const { deployDiamond } = require('../scripts/deploy_test.js')
const { ADDRESSZERO, getSelectors, deploy  } = require('../scripts/libraries/diamond.js')

const MockERC20 = artifacts.require('MockToken')
const TestRouter = artifacts.require('TestRouter')
const IUniswapV3Pool = artifacts.require('IUniswapV3Pool')

const ERC20Facet = artifacts.require('ERC20Facet')
const AlphaVaultFacet = artifacts.require('AlphaVaultFacet')
const PassiveStrategyFacet = artifacts.require('PassiveStrategyFacet')

contract("Passive Strategy", (accounts) => {
  const owner = accounts[0]
  const keeper = accounts[1]
  const alice = accounts[2]
  const bob = accounts[3]
  const carol = accounts[4]
  const dan = accounts[5]
  const users = [owner, keeper, alice, bob, carol, dan]

  let diamondAddr;
  let erc20A;
  let erc20B;
  let testRouter;
  let pool;

  let erc20Facet;
  let alphaVaultFacet;
  let passiveStrategyFacet;

  const addresses = []

  before(async () => {
    const {
      diamond:diamondAddress,
      pool:poolAddress,
      erc20A:erc20AAddress,
      erc20B:erc20BAddress,
      testRouter: testRouterAddress
    } = await deployDiamond()
    diamondAddr = diamondAddress
    console.log('poolAddr', poolAddress)

    erc20A = new web3.eth.Contract(MockERC20.abi, erc20AAddress)
    erc20B = new web3.eth.Contract(MockERC20.abi, erc20BAddress)
    testRouter = new web3.eth.Contract(TestRouter.abi, testRouterAddress)
    pool = new web3.eth.Contract(IUniswapV3Pool.abi, poolAddress)

    erc20Facet = new web3.eth.Contract(ERC20Facet.abi, diamondAddress)
    alphaVaultFacet = new web3.eth.Contract(AlphaVaultFacet.abi, diamondAddress)
    passiveStrategyFacet = new web3.eth.Contract(PassiveStrategyFacet.abi, diamondAddress)


  })

  it("rebalances", async () => {

    await alphaVaultFacet.methods.setStrategy(diamondAddr).send({from: owner})
    await erc20A.methods.approve(diamondAddr, web3.utils.toWei('1', 'ether')).send({from:alice})
    await erc20B.methods.approve(diamondAddr, web3.utils.toWei('1', 'ether')).send({from:alice})
    await alphaVaultFacet.methods.deposit(
      web3.utils.toWei('1', 'ether'),
      web3.utils.toWei('1', 'ether'),
      0,
      0,
      alice
    ).send({from:alice})

  })
})
