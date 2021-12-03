const fromExponential = require('from-exponential')

const { deploy, getSelectors, ADDRESSZERO } = require('./libraries/diamond.js')
const { encodePriceSqrt, TICK_SPACING, getMinTick, getMaxTick } = require('./libraries/pool.js')
const { advanceTime } = require('./libraries/utilities.js')

const DiamondCutFacet = artifacts.require('DiamondCutFacet')
const Diamond = artifacts.require('Diamond')
const DiamondInit = artifacts.require('DiamondInit')
const DiamondLoupeFacet = artifacts.require('DiamondLoupeFacet')
const OwnershipFacet = artifacts.require('OwnershipFacet')
const IDiamondCut = artifacts.require('IDiamondCut')

const AlphaVaultFacet = artifacts.require('AlphaVaultFacet')
const ERC20Facet = artifacts.require('ERC20Facet')
const PassiveStrategyFacet = artifacts.require('PassiveStrategyFacet')

const MockERC20 = artifacts.require('MockToken')
const TestRouter = artifacts.require('TestRouter')

const IUniswapV3Factory = artifacts.require('IUniswapV3Factory')
const IUniswapV3Pool = artifacts.require('IUniswapV3Pool')


async function deployDiamond() {
  const accounts = await web3.eth.getAccounts()
  const owner = accounts[0]
  const keeper = accounts[1]
  const alice = accounts[2]
  const bob = accounts[3]
  const carol = accounts[4]
  const dan = accounts[5]
  const users = [owner, keeper, alice, bob, carol, dan]
  const fee = 3000

  // Mock Pool
  const erc20A = await deploy(owner, MockERC20, ['name A', 'A', 18])
  console.log('erc20A deployed:', erc20A._address)
  const erc20B = await deploy(owner, MockERC20, ['name B', 'B', 18])
  console.log('erc20B deployed:', erc20B._address)
  
  for (const i in users) {
    await erc20A.methods.mint(users[i], web3.utils.toWei('10000', 'ether')).send({from: owner})
    await erc20B.methods.mint(users[i], web3.utils.toWei('10000', 'ether')).send({from: owner})
  }

  const uniTestRouter = await deploy(owner, TestRouter)
  const uniFactory = new web3.eth.Contract(IUniswapV3Factory.abi,'0x1F98431c8aD98523631AE4a59f267346ea31F984')
  const create = await uniFactory.methods.createPool(erc20A._address, erc20B._address, fee).send({from:owner})

  const token0Addr = create.events.PoolCreated.returnValues.token0
  const token1Addr  = create.events.PoolCreated.returnValues.token1
  const poolAddr = create.events.PoolCreated.returnValues.pool
  console.log('pool created', poolAddr)
  
  const token0 = new web3.eth.Contract(MockERC20.abi, token0Addr)
  const token1 = new web3.eth.Contract(MockERC20.abi, token1Addr)

  const uniPool = new web3.eth.Contract(IUniswapV3Pool.abi, poolAddr)
  console.log(uniPool._address, 'uniPool Addr')
  const price = encodePriceSqrt(1,1)
  
  const init = await uniPool.methods.initialize(price).send({from:owner})

  for (const i in users) {
    await token0.methods.approve(uniTestRouter._address, web3.utils.toWei('100', 'ether')).send({from:users[i]})
    await token1.methods.approve(uniTestRouter._address, web3.utils.toWei('100', 'ether')).send({from:users[i]})
  }

  const mint = await uniTestRouter.methods.mint(
    uniPool._address,
    getMinTick(TICK_SPACING[fee]),
    getMaxTick(TICK_SPACING[fee]),
    web3.utils.toWei('1', 'ether')
  ).send({from:owner})

  await uniPool.methods.increaseObservationCardinalityNext(100).send({from:owner})
  await advanceTime(3600)


  


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
    uniPool._address, // address pool, (DAI-ETH 0.3%)
    5000, // uint256 protocolFee,
    fromExponential(100e18), // uint256 maxTotalSupply,
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

  return {
    'diamond': diamond._address,
    'pool': uniPool._address,
    'erc20A': erc20A._address,
    'erc20B': erc20B._address,
    'testRouter': uniTestRouter._address
  }
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
