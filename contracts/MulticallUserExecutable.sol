// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

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

    string private constant _UNVERIFIED_DEX = "UNVERIFIED_DEX";
    string private constant _UNVERIFIED_ALM = "UNVERIFIED_ALM";
    string private constant _UNVERIFIED_BRIDGE = "UNVERIFIED_BRIDGE";
    string private constant _UNVERIFIED_LOGGER = "UNVERIFIED_LOGGER";

    address public alm;
    address public amb;
    address public eventLogger;
    address public priceOracle;
    address public WETH;
    uint256 public fee;
    address payable public feeTo;

    mapping(address => bool) public routers;
    mapping(bytes32 => Scenario) public scenarios;

    event PriceOracleSet(address oracle);
    event WethSet(address weth);
    event AMBSet(address amb);
    event ALMSet(address alm);
    event EventLoggerSet(address eventLogger);
    event ScenarioSet(bytes32 hash, string key);
    event ScenarioUnset(bytes32 hash);
    event FeeSet(uint256 fee);
    event FeeToSet(address feeTo);
    event RouterSet(address router);
    event RouterUnset(address router);

    function execute(InputData[] calldata _data)
        external
        payable
        override
        returns (bytes[] memory results)
    {
        uint256 ethFee;
        if (priceOracle != address(0)) {
            ethFee = calcFee();

            if (ethFee != 0) {
                require(msg.value >= ethFee, "Not enough for fee");

                Address.sendValue(feeTo, ethFee);
            }

            _updatePrice();
        }

        bytes4[] memory signatures = new bytes4[](_data.length);
        for (uint256 i; i < _data.length; i++) {
            signatures[i] = SignatureHelper.getSignature(_data[i].data);
        }
        bytes32 hash = SignatureHelper.getHash(signatures);

        require(scenarios[hash].status, "Unverified signature request");

        bytes32 sHash = keccak256(abi.encodePacked(scenarios[hash].name));

        // CORE -> CORE/ERC20/ALM
        if (sHash == keccak256("CORE_ANY")) {
            require(routers[_data[0].dest], _UNVERIFIED_DEX);
            require(_data[1].dest == amb, _UNVERIFIED_BRIDGE);
        }
        // ERC20 -> CORE/ERC20/ALM
        if (sHash == keccak256("ERC20_ANY")) {
            require(routers[_data[2].dest], _UNVERIFIED_DEX);
            require(_data[3].dest == amb, _UNVERIFIED_BRIDGE);
        }
        // ALM -> ALM/CORE/ERC20
        if (sHash == keccak256("ALM_ANY")) {
            require(_data[1].dest == amb, _UNVERIFIED_BRIDGE);
        }
        // another side CORE -> ALM/CORE/ERC20
        if (sHash == keccak256("aCORE_ANY")) {
            require(routers[_data[0].dest], _UNVERIFIED_DEX);
        }
        // another side ERC20 -> ALM/CORE/ERC20
        if (sHash == keccak256("aERC20_ANY")) {
            require(routers[_data[2].dest], _UNVERIFIED_DEX);
        }
        // another side ALM -> ALM/CORE/ERC20
        if (sHash == keccak256("aALM_ALM")) {
            require(_data[1].dest == alm, _UNVERIFIED_ALM);
        }

        require(
            _data[_data.length - 1].dest == eventLogger,
            _UNVERIFIED_LOGGER
        );

        results = _execute(_data, msg.value - ethFee);
    }

    function setResolvedRouters(address[] calldata _routers)
        external
        onlyOwner
    {
        for (uint256 i; i < _routers.length; i++) {
            routers[_routers[i]] = true;
            emit RouterSet(_routers[i]);
        }
    }

    function unsetResolvedRouters(address[] calldata _routers)
        external
        onlyOwner
    {
        for (uint256 i; i < _routers.length; i++) {
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

    function approveAnyToAMB(IERC20 _token) external {
        require(amb != address(0), "AMB is unset");

        _token.approve(amb, type(uint256).max);
    }

    function approveAnyToDex(IERC20 _token, address _dex) external {
        require(routers[_dex], _UNVERIFIED_DEX);

        _token.approve(_dex, type(uint256).max);
    }

    function setScenario(bytes32 _scenario, string memory _key)
        external
        onlyOwner
    {
        require(!scenarios[_scenario].status, "Scenario already set");

        scenarios[_scenario].name = _key;
        scenarios[_scenario].status = true;
        emit ScenarioSet(_scenario, _key);
    }

    function unsetScenario(bytes32 _scenario) external onlyOwner {
        require(scenarios[_scenario].status, "Scenario already unset");

        delete scenarios[_scenario];
        emit ScenarioUnset(_scenario);
    }

    function setPriceOracle(address _oracle, address _weth) external onlyOwner {
        if (_oracle != address(0)) {
            require(_weth != address(0), "WETH zero?");
        }

        priceOracle = _oracle;
        WETH = _weth;
        emit PriceOracleSet(_oracle);
        emit WethSet(_weth);
    }

    function setFee(uint256 _busdEquAmount, address payable _feeTo)
        external
        onlyOwner
    {
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
        for (uint256 i; i < _data.length; i++) {
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
        if (
            block.timestamp - _priceOracle.blockTimestampLast() >
            _priceOracle.PERIOD()
        ) {
            _priceOracle.update();
        }
    }
}
