import chai, { assert } from "chai";

import { ethers } from "hardhat";
import { getCurrentTimestamp } from "hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp";
import { BigNumber, Contract, Signer } from "ethers";
import { solidity } from "ethereum-waffle";
import { Interface, parseEther } from "ethers/lib/utils";

chai.use(solidity);

import UniswapV2FactoryArtifacts from "@uniswap/v2-core/build/UniswapV2Factory.json"
import UniswapV2PairArtifacts from "@uniswap/v2-core/build/UniswapV2Pair.json"
import WETH9Artifacts from "@uniswap/v2-periphery/build/WETH9.json"
import UniswapV2RouterArtifacts from "@uniswap/v2-periphery/build/UniswapV2Router02.json"

describe("Multicall User executable", function () {
    let accounts: Signer[];

    let OWNER_SIGNER: any;
    let ALICE_SIGNER: any;
    let BOB_SIGNER: any;

    let OWNER: any;
    let ALICE: any;
    let BOB: any;

    let multicall: any;
    let erc20: any;
    let amb: any;
    let alm: any;
    let eventLogger: any;

    let factory: any
    let router: any

    let weth: any

    interface DataInput {
        dest: string,
        data: string,
        value: string|number|BigNumber
    }

    const getPairAddress: any = async function (tokenA: string, tokenB: string): Promise<Contract> {
        const UniswapV2Pair = await ethers.getContractFactory(
            UniswapV2PairArtifacts.abi,
            UniswapV2PairArtifacts.bytecode
        );

        return UniswapV2Pair.attach(
            String(await factory.getPair(tokenA, tokenB))
        )
    }

    before("config", async () => {
        accounts = await ethers.getSigners();

        OWNER_SIGNER = accounts[0];
        ALICE_SIGNER = accounts[2];
        BOB_SIGNER = accounts[3];

        OWNER = await OWNER_SIGNER.getAddress();
        ALICE = await ALICE_SIGNER.getAddress();
        BOB = await BOB_SIGNER.getAddress();

        const MulticallUserExecutable = await ethers.getContractFactory("MulticallUserExecutable");
        const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
        const AMBMock = await ethers.getContractFactory("AMBMock");
        const EventLogger = await ethers.getContractFactory("EventLogger");

        const UniswapV2Factory = await ethers.getContractFactory(
            UniswapV2FactoryArtifacts.abi,
            UniswapV2FactoryArtifacts.bytecode
        );
        const UniswapV2Router = await ethers.getContractFactory(
            UniswapV2RouterArtifacts.abi,
            UniswapV2RouterArtifacts.bytecode
        );
        const WETH9 = await ethers.getContractFactory(
            WETH9Artifacts.abi,
            WETH9Artifacts.bytecode
        );

        multicall = await MulticallUserExecutable.deploy();
        await multicall.deployed()

        erc20 = await ERC20Mock.deploy("XXX", "XXX");
        await erc20.deployed()

        alm = await ERC20Mock.deploy("ALM", "ALM");
        await alm.deployed()

        amb = await AMBMock.deploy(alm.address);
        await amb.deployed()

        eventLogger = await EventLogger.deploy(OWNER)
        await eventLogger.deployed()

        factory = await UniswapV2Factory.deploy(OWNER)
        await factory.deployed()

        weth = await WETH9.deploy()
        await weth.deployed()

        router = await UniswapV2Router.deploy(factory.address, weth.address)
        await router.deployed()

        await factory.createPair(weth.address, erc20.address);
        let WETH_USD: Contract = await getPairAddress(weth.address, erc20.address)

        await erc20.mint(WETH_USD.address, 50000000000)
        await weth.deposit({value: 10000000000})
        await weth.transfer(WETH_USD.address, 10000000000)

        await WETH_USD.mint(ALICE)

        await factory.createPair(weth.address, alm.address);
        let WETH_ALM: Contract = await getPairAddress(weth.address, alm.address)

        await alm.mint(WETH_ALM.address, 50000000000)
        await weth.deposit({value: 10000000000})
        await weth.transfer(WETH_ALM.address, 10000000000)

        await WETH_ALM.mint(ALICE)

        await multicall.connect(OWNER_SIGNER).setResolvedRouters([
            router.address
        ])
        await multicall.connect(OWNER_SIGNER).setAMB(amb.address)
        await multicall.connect(OWNER_SIGNER).setALM(alm.address)
        await multicall.connect(OWNER_SIGNER).approveALMToAMB()
        await multicall.connect(OWNER_SIGNER).setEventLogger(eventLogger.address)

        await eventLogger.connect(OWNER_SIGNER).grantRole(await eventLogger.MANAGER_ROLE(), multicall.address)
    });

    describe("success tests", () => {
        it.only("#execute", async () => {
            await erc20.mint(ALICE, parseEther("1.0"))
            await erc20.connect(ALICE_SIGNER).approve(multicall.address, parseEther("1.0"))

            const erc20Interface = new Interface([...erc20.interface.fragments])
            const routerInterface = new Interface([...router.interface.fragments])
            const bridgeInterface = new Interface([...amb.interface.fragments])
            const eventLoggerInterface = new Interface([...eventLogger.interface.fragments])

            const multicallForeignChain = multicall.address

            const expectedAmountsOut = await router.getAmountsOut(
                parseEther("1.0"),
                [erc20.address, weth.address, alm.address]
            )

            const data: DataInput[] = [
                {
                    dest: erc20.address,
                    data: erc20Interface.encodeFunctionData('transferFrom', [
                        ALICE,
                        multicall.address,
                        parseEther("1.0")
                    ]),
                    value: 0
                },
                {
                    dest: erc20.address,
                    data: erc20Interface.encodeFunctionData('approve', [
                        router.address,
                        ethers.constants.MaxUint256
                    ]),
                    value: 0
                },
                {
                    dest: router.address,
                    data: routerInterface.encodeFunctionData('swapExactTokensForTokens', [
                        parseEther("1.0"),
                        0,
                        [erc20.address, weth.address, alm.address],
                        multicall.address,
                        getCurrentTimestamp() + (20 * 60)
                    ]),
                    value: 0
                },
                {
                    dest: amb.address,
                    data: bridgeInterface.encodeFunctionData('relayTokens', [
                        multicallForeignChain,
                        expectedAmountsOut[expectedAmountsOut.length-1]
                    ]),
                    value: 0
                },
                {
                    dest: eventLogger.address,
                    data: eventLoggerInterface.encodeFunctionData('log',
                        // [
                        //     "tuple(uint256[] chains, address[] tokens, address[] parties) EventData"
                        // ],
                        [
                            [[1, 2], [erc20.address, weth.address], [ALICE, BOB]]
                        ]
                    ),
                    value: 0
                },
            ];

            // console.log(data.map(value => value.data))
            let scenarioHash = await multicall.countScenarioHash(data.map(value => value.data));

            console.log(`Scenario hash ERC20_ERC20: ${scenarioHash}`)

            await multicall.connect(OWNER_SIGNER).setScenario(scenarioHash, "ERC20_ERC20")

            await multicall.connect(ALICE_SIGNER).execute(data);

            assert.equal(String(expectedAmountsOut[expectedAmountsOut.length-1]), String(await alm.balanceOf(amb.address)), "AMB balance")
        });
    });
});
