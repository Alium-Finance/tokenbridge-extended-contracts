// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MulticallExecutable.sol";
import "./libs/SignatureHelper.sol";
import "./interfaces/IUniV2PriceOracle.sol";

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
    address priceOracle;
    address immutable WETH;
    uint256 fee;
    address payable feeTo;

    mapping (address => bool) public routers;
    mapping (bytes32 => Scenario) public scenarios;

    event PriceOracleSet(address oracle);
    event AMBSet(address amb);
    event ALMSet(address alm);
    event EventLoggerSet(address eventLogger);
    event ScenarioSet(bytes32 hash, string key);
    event FeeSet(uint256 fee);
    event FeeToSet(address feeTo);
    event RouterSet(address router);
    event RouterUnset(address router);

    constructor(address _WETH) {
        require(_WETH != address(0), "Weth zero?");

        WETH = _WETH;
    }

    function execute(InputData[] calldata _data)
        public
        payable
        override
        returns (bytes[] memory results)
    {
        if (priceOracle != address(0)) {
            uint256 ethFee = calcFee();

            require(ethFee != 0, "Fee is zero");
            // usdt -> output weth >= msg.value weth
            require(ethFee >= msg.value, "Not enough for fee");

            Address.sendValue(feeTo, ethFee);

            _updatePrice();
        }

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
            emit RouterSet(_routers[i]);
        }
    }

    function unsetResolvedRouters(address[] calldata _routers) external onlyOwner {
        for (uint i; i < _routers.length; i++) {
            routers[_routers[i]] = false;
            emit RouterUnset(_routers[i]);
        }
    }

    function setAMB(address _amb) external onlyOwner {
        amb = _amb;
        emit AMBSet(_amb);
    }

    function setALM(address _alm) external onlyOwner {
        alm = _alm;
        emit ALMSet(_alm);
    }

    function setEventLogger(address _eventLogger) external onlyOwner {
        eventLogger = _eventLogger;
        emit EventLoggerSet(_eventLogger);
    }

    function approveALMToAMB() external onlyOwner {
        IERC20(alm).approve(amb, type(uint256).max);
    }

    function setScenario(bytes32 _scenario, string memory _key) external onlyOwner {
        scenarios[_scenario].name = _key;
        scenarios[_scenario].status = true;
        emit ScenarioSet(_scenario, _key);
    }

    function setPriceOracle(address _oracle) external onlyOwner {
        eventLogger = _oracle;
        emit PriceOracleSet(_oracle);
    }

    function setFee(uint256 _busdEquAmount, address payable _feeTo) external onlyOwner {
        require(_busdEquAmount != 0, "Fee is zero?");
        require(_feeTo != address(0), "Fee to zero?");

        fee = _busdEquAmount;
        feeTo = _feeTo;
        emit FeeSet(_busdEquAmount);
        emit FeeToSet(_feeTo);
    }

    function countScenarioHashByData(bytes[] calldata _data)
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

    function countScenarioHashBySigs(bytes4[] calldata _signatures)
        external
        pure
        returns (bytes32 hash)
    {
        hash = SignatureHelper.getHash(_signatures);
    }

    function getSignature(bytes calldata _data)
        external
        pure
        returns (bytes4 signature)
    {
        signature = SignatureHelper.getSignature(_data);
    }

    function calcFee() public view returns (uint256 ethFee) {
        IUniV2PriceOracle _priceOracle = IUniV2PriceOracle(priceOracle);
        address consultToken = (_priceOracle.token0() != WETH)
            ? _priceOracle.token0()
            : _priceOracle.token1();
        ethFee = _priceOracle.consult(consultToken, fee);
    }

    function _updatePrice() internal {
        IUniV2PriceOracle _priceOracle = IUniV2PriceOracle(priceOracle);
        if (block.timestamp - _priceOracle.blockTimestampLast() > _priceOracle.PERIOD()) {
            _priceOracle.update();
        }
    }
}
