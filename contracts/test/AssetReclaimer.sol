// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";

/**
 *  @title ETH forwarder.
 */
contract AssetReclaimer {
	function claim(address payable _to) external payable {
		Address.sendValue(_to, msg.value);
	}
}

