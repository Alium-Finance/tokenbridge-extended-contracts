// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISupportedChains.sol";

contract SupportedChains is ISupportedChains, Ownable {
    mapping(uint256 => bool) private _status;

    uint256[] internal _chains;

    function getChainStatus(uint256 _chainId) external view override returns (bool enabled) {
        enabled = _status[_chainId];
    }

    function addChain(uint256 _chainId) external override onlyOwner {
        require(!_status[_chainId], "SupportedChains: chain already added");

        _status[_chainId] = true;
        _chains.push(_chainId);
    }

    function removeChain(uint256 _chainId) external override onlyOwner {
        require(_status[_chainId], "SupportedChains: chain already removed");

        _status[_chainId] = false;
        for (uint i; i < _chains.length; i++) {
            if (_chains[i] == _chainId) {
                _chains[i] = _chains[_chains.length - 1];
                _chains.pop();
            }
        }
    }

    function getSupportedChains() external view override returns (uint256[] memory chains) {
        chains = _chains;
    }

    function chainLength() external view override returns (uint256 length) {
        length = _chains.length;
    }
}