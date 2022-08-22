// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract vUSDxVault {

	IERC20 public immutable underlying;

	constructor(IERC20 underlyingToken) {
		underlying = underlyingToken;
	}

	function charge(uint256 _amount) external {
		SafeERC20.safeTransferFrom(underlying, _msgSender(), address(this), amount);
	}

	function deposit(uint256 _amount) external {
		SafeERC20.safeTransferFrom(underlying, _msgSender(), address(this), amount);
	}
}
