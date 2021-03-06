function getSelectors(contract) {
  return  Object.keys(contract.methods).filter((key) => {
    return /^0x/.test(key)
  })
}

async function deploy(account, artifact, args) {
  const contract = new web3.eth.Contract(artifact.abi)
  let instance;
  await contract.deploy({
    data: artifact.bytecode,
    arguments: args ? args: []
  }).send({
    from: account,
    gas: 15000000,
    gasPrice: '182006987310'
  }).then((inst) => {
      instance = inst
  })
  return instance;
}

exports.getSelectors = getSelectors
exports.deploy = deploy

exports.ADDRESSZERO = '0x0000000000000000000000000000000000000000'
