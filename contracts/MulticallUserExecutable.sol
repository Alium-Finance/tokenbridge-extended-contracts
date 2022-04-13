// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MulticallExecutable.sol";
import "./libs/SignatureHelper.sol";

/**
 * @dev Provides a function to batch together multiple calls in a single external call.
 *
 * _Available since v4.1._
 */
contract MulticallUserExecutable is MulticallExecutable {
    struct Scenario {
        string name;
        bool status;
    }

    address alm;
    address amb;
    address eventLogger;

    mapping (address => bool) public routers;
    mapping (bytes32 => Scenario) public scenarios;

    function execute(InputData[] calldata _data)
        public
        payable
        override
        returns (bytes[] memory results)
    {
        bytes4[] memory signatures = new bytes4[](_data.length);
        for (uint i; i < _data.length; i++) {
            signatures[i] = SignatureHelper.getSignature(_data[i].data);
        }
        bytes32 hash = SignatureHelper.getHash(signatures);

        require(scenarios[hash].status, "Unverified signature request");

        bytes32 hashedKey = keccak256(abi.encodePacked(scenarios[hash].name));

        // ERC20 -> ERC20
        if (hashedKey == keccak256("ERC20_ERC20")) {
            require(routers[_data[2].dest], "Unverified dex");
            require(_data[3].dest == amb, "Unverified bridge");
        }
        // ERC20 -> ERC20 + approve erc20 to dex
        if (hashedKey == keccak256("aERC20_ERC20")) {
            require(routers[_data[1].dest], "Unverified dex");
            require(_data[2].dest == amb, "Unverified bridge");
        }
        // ALM -> ERC20
        if (hashedKey == keccak256("ALM_ERC20")) {
            require(_data[1].dest == amb, "Unverified bridge");
        }
        // ETH -> ERC20
        if (hashedKey == keccak256("ETH_ERC20")) {
            require(_data[0].dest == amb, "Unverified bridge");
        }

        require(_data[_data.length - 1].dest == eventLogger, "Unverified logger");

        results = _execute(_data);
    }

    function setResolvedRouters(address[] calldata _routers) external onlyOwner {
        for (uint i; i < _routers.length; i++) {
            routers[_routers[i]] = true;
        }
    }

    function setAMB(address _amb) external onlyOwner {
        amb = _amb;
    }

    function setALM(address _alm) external onlyOwner {
        alm = _alm;
    }

    function setEventLogger(address _eventLogger) external onlyOwner {
        eventLogger = _eventLogger;
    }

    function approveALMToAMB() external onlyOwner {
        IERC20(alm).approve(amb, type(uint256).max);
    }

    function setScenario(bytes32 _scenario, string memory _key) external onlyOwner {
        scenarios[_scenario].name = _key;
        scenarios[_scenario].status = true;
    }

    function countScenarioHash(bytes[] calldata _data)
        external
        pure
        returns (bytes32 hash)
    {
        bytes4[] memory signatures = new bytes4[](_data.length);
        for (uint i; i < _data.length; i++) {
            signatures[i] = SignatureHelper.getSignature(_data[i]);
        }
        hash = SignatureHelper.getHash(signatures);
    }
}
