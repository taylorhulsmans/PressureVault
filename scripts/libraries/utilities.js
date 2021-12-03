function warpTime(seconds) {
	return new Promise((resolve, reject) => {
		web3.eth.currentProvider.send({
			method: 'evm_increaseTime',
			jsonrpc: "2.0",
			params: [Number(seconds)],
			id: 0
		}, function (error, result) {
			if (error) {
				reject(error)
			} else {
				resolve(result)
			}
		})
	})
}

async function advanceTime(seconds) {
	return await warpTime(seconds)
}


module.exports = {
  advanceTime
}
