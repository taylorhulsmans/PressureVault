pragma solidity ^0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';


import { AppStorage, LibAppStorage, Modifiers } from '../libraries/LibAppStorage.sol';
contract ERC20Facet is Context, Modifiers {
  using SafeMath for uint256;
  AppStorage internal s;
	/**
	 * @dev Emitted when `value` tokens are moved from one account (`from`) to
	 * another (`to`).
	 *
	 * Note that `value` may be zero.
	 */
	event Transfer(address indexed from, address indexed to, uint256 value);

	/**
	 * @dev Emitted when the allowance of a `spender` for an `owner` is set by
	 * a call to {approve}. `value` is the new allowance.
	 */
	event Approval(address indexed owner, address indexed spender, uint256 value);
	/**
		* @title wVFacet
		* @dev The wVFacet is the ERC20 compliant token native to the Warp Vault platform. wV!. used in onchain governance as the protocol decentralizes
	*/
  /**
    * Mints wV, only callable by diamond
    * @param to address for receiving the tokens
    * @param amount amount to receive 
    * @return bool if successful
  */
  function mint(address to, uint256 amount) external onlyDiamond returns (bool) {
    require(to != address(0), 'ERC20: mint to the zero address');
    //AppStorage storage s = LibAppStorage.diamondStorage();

    s.wVTotalSupply +=  amount;
    s.wVBalances[to] += amount;

    emit Transfer(address(0), to, amount);
  }
  /**
    * executiveMint, only callable by owner for initial token generation event, planned to be disabled after protocol bootstrap
    * @param to address the tokens get minted to
    * @param amount amount of tokens to be minted
    * @return bool success of the mint
  */
  function executiveMint(address to, uint256 amount) external onlyOwner returns (bool) {
    require(to != address(0), 'ERC20: mint to the zero address');
    //AppStorage storage s = LibAppStorage.diamondStorage();

    s.wVTotalSupply +=  amount;
    s.wVBalances[to] += amount;

    emit Transfer(address(0), to, amount);
  }

  /**
    * returns the name of the token
    * @return string name of token
  */ 
  function name() public  view returns (string memory) {
    //AppStorage storage s = LibAppStorage.diamondStorage();
    return s.wVName;

  }
  /**
    * returns the amount of decimals for the token
    * @return uint8 amount of decimals
  */ 
  function decimals() public  view  returns (uint8) {
    //AppStorage storage s = LibAppStorage.diamondStorage();
    return s.wVDecimals;
  }
  /**
    * returns the symbol of the token
    * @return string name of symbol
  */ 
  function symbol() public  view  returns (string memory) {
    //AppStorage storage s = LibAppStorage.diamondStorage();
    return s.wVSymbol;
  }

  /**
     * Returns the amount of tokens in existence.
     * @return uint256 amount of tokens
   */
  function totalSupply() external view  returns (uint256) {
    //AppStorage storage s = LibAppStorage.diamondStorage();
    return s.wVTotalSupply;
  }

  /**
     * Returns the amount of tokens owned by `account`
     * @param account address of the account in question
     * @return uint256  amount of wV tokens
   */
  function balanceOf(address account) external view  returns (uint256) {
    //AppStorage storage s = LibAppStorage.diamondStorage();
    return s.wVBalances[account];
  }

  /**
    * Moves `amount` tokens from the caller's account to `recipient`.
    * @param recipient the address of who is getting the tokens
    * @param amount the amount of tokens recieved
    * @return bool transfer success
    * Emits a {Transfer} event.
    */
  function transfer(address recipient, uint256 amount) external  returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  /**
  * @dev Returns the remaining number of tokens that `spender` will be
  * allowed to spend on behalf of `owner` through {transferFrom}. This is
  * zero by default.
    *
    * This value changes when {approve} or {transferFrom} are called.
    */
  function allowance(address owner, address spender) external  view returns (uint256) {
    //AppStorage storage s = LibAppStorage.diamondStorage();
    return s.wVAllowances[owner][spender];
  }

  /**
  * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
  *
    * Returns a boolean value indicating whether the operation succeeded.
    *
    * IMPORTANT: Beware that changing an allowance with this method brings the risk
  * that someone may use both the old and the new allowance by unfortunate
  * transaction ordering. One possible solution to mitigate this race
  * condition is to first reduce the spender's allowance to 0 and set the
  * desired value afterwards:
  * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    *
    * @param spender who you are allowing to spend your coins
    * @param amount the amount your willing to let them spend
    * @return bool approval success
    * Emits an {Approval} event.
    */
  function approve(address spender, uint256 amount) external  returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  /**
  * Moves `amount` tokens from `sender` to `recipient` using the
  * allowance mechanism. `amount` is then deducted from the caller's
  * allowance.
  *
    * Returns a boolean value indicating whether the operation succeeded.
    * @param sender address of who your taking coins from
    * @param recipient address of who your sending these coins to
    * @param amount that amount of tokens that you are moving
    * @return bool success of transferFrom
    * Emits a {Transfer} event.
    */
  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external  returns (bool) {
    //AppStorage storage s = LibAppStorage.diamondStorage();

    _transfer(sender, recipient, amount);

    uint256 currentAllowance = s.wVAllowances[sender][_msgSender()];
    require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
    _approve(sender, _msgSender(), currentAllowance - amount);
    return true;
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");

    //AppStorage storage s = LibAppStorage.diamondStorage();

    uint256 senderBalance = s.wVBalances[sender];
    require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
    
    s.wVBalances[sender] = senderBalance - amount;
    s.wVBalances[recipient] += amount;

    emit Transfer(sender, recipient, amount);
  }
  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) internal {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    //AppStorage storage s = LibAppStorage.diamondStorage();

    s.wVAllowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

	function burn(address account, uint256 amount) public onlyDiamond {
    _burn(account, amount);
  }

	function _burn(address account, uint256 amount) internal virtual {
		require(account != address(0), "ERC20: burn from the zero address");

		uint256 accountBalance = s.wVBalances[account];
		require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
    s.wVBalances[account] = accountBalance - amount;
		s.wVTotalSupply -= amount;

		emit Transfer(account, address(0), amount);

	} 
}
