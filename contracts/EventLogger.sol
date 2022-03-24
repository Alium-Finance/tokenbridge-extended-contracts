// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ISupportedChains.sol";
import "./interfaces/IEventLogger.sol";
import "./libs/EventLogHelper.sol";

contract EventLogger is AccessControl, IEventLogger {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    ISupportedChains public immutable override supportedChains;

    event SwapInfo(EventData data);

    constructor(ISupportedChains _chains, address _admin) {
        supportedChains = _chains;

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function log(EventData calldata _data) external override onlyRole(MANAGER_ROLE) {
        require(
            supportedChains.getChainStatus(_data.chains[0]) &&
            supportedChains.getChainStatus(_data.chains[1]),
            "EventLogger: incorrect chains"
        );
        require(
            _data.parties[0] != address(0) &&
            _data.parties[1] != address(0),
            "EventLogger: incorrect parties"
        );

        emit SwapInfo(_data);
    }

    function getAssetId(uint256 _chainId, address _tokenAddress)
        external
        pure
        override
        returns (bytes32)
    {
        return EventLogHelper.getAssetId(_chainId, _tokenAddress);
    }
}