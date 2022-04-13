// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AMBMock {
	event ActionOnTransfer(address receiver);

	IERC20 public token;

	constructor() {
		token = new ERC20("Bridge token", "bERC20");
	}

	function relayTokens(address _receiver, uint256 _value) external {
		address to = address(this);
		token.transferFrom(msg.sender, to, _value);
		emit ActionOnTransfer(_receiver);
	}
}
