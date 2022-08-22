// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

contract Whitelist {
	mapping(address => bool) public whitelist;

	function addToWL(address[] calldata _accounts) external {
		for (uint i; i < _accounts.length; i++) {
			whitelist[_accounts[i]] = true;
		}
	}

	function rmFromWL(address[] calldata _accounts) external {
		for (uint i; i < _accounts.length; i++) {
			whitelist[_accounts[i]] = false;
		}
	}
}
