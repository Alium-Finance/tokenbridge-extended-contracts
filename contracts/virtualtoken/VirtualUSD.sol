// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "../OperatorAccess.sol";
import "./Whitelist.sol";

contract VirtualUSD is ERC20Wrapper, ERC20Permit, OperatorAccess, Whitelist {
	uint8 private immutable _decimals;
	string private immutable _tokenName = "Alium bridge wrapped USD";

	constructor(address _token)
		ERC20(_tokenName, "almUSDx")
		ERC20Permit(_tokenName)
		ERC20Wrapper(IERC20(_token))
	{
		_decimals = IERC20Metadata(_token).decimals();
	}

	function decimals() public view override(ERC20) returns (uint8) {
		return _decimals;
	}

	function recover() external onlyOwner {
		_recover(msg.sender);
	}

	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal virtual {
		super._beforeTokenTransfer(from, to, amount);
		if (from != address(0)) {
			require(whitelist[from], "sender not whitelisted");
		}
		if (to != address(0)) {
			require(whitelist[to], "recipient not whitelisted");
		}
	}
}
