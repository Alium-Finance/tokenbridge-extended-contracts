import chai from "chai";

import { ethers } from "hardhat";
import { BigNumber, Contract, Signer } from "ethers";
import { solidity } from "ethereum-waffle";
import { Interface, parseEther } from "ethers/lib/utils";

chai.use(solidity);

import UniswapV2FactoryArtifacts from "@uniswap/v2-core/build/UniswapV2Factory.json"
import UniswapV2PairArtifacts from "@uniswap/v2-core/build/UniswapV2Pair.json"
import ERC20Artifacts from "@uniswap/v2-core/build/ERC20.json"
import WETH9Artifacts from "@uniswap/v2-periphery/build/WETH9.json"
import UniswapV2Router02Artifacts from "@uniswap/v2-periphery/build/UniswapV2Router02.json"
import { getCurrentTimestamp } from "hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp";

describe("Price Straighten Optimizer", function () {
    let accounts: Signer[];

    let OWNER_SIGNER: any;
    let OPERATOR_SIGNER: any;
    let ALICE_SIGNER: any;
    let BOB_SIGNER: any;

    let OWNER: any;
    let OPERATOR: any;
    let ALICE: any;
    let BOB: any;

    let factory: any;
    let weth: any;
    let router: any;
    let optimizer: any;



    before("config", async () => {
        accounts = await ethers.getSigners();

        OWNER_SIGNER = accounts[0];
        OPERATOR_SIGNER = accounts[1];
        ALICE_SIGNER = accounts[2];
        BOB_SIGNER = accounts[3];

        OWNER = await OWNER_SIGNER.getAddress();
        OPERATOR = await OPERATOR_SIGNER.getAddress();
        ALICE = await ALICE_SIGNER.getAddress();
        BOB = await BOB_SIGNER.getAddress();

        const PriceStraightenOptimizer = await ethers.getContractFactory("PriceStraightenOptimizer");
        const UniswapV2Factory = await ethers.getContractFactory(
          UniswapV2FactoryArtifacts.abi,
          UniswapV2FactoryArtifacts.bytecode
        );
        const WETH9 = await ethers.getContractFactory(
          WETH9Artifacts.abi,
          WETH9Artifacts.bytecode
        );
        const UniswapV2Router = await ethers.getContractFactory(
          UniswapV2Router02Artifacts.abi,
          UniswapV2Router02Artifacts.bytecode
        );

        factory = await UniswapV2Factory.deploy(OWNER)
        await factory.deployed()

        weth =  await WETH9.deploy()
        await weth.deployed()

        router = await UniswapV2Router.deploy(factory.address, weth.address)
        await router.deployed()

        optimizer = await PriceStraightenOptimizer.deploy(factory.address, router.address);
        await optimizer.deployed()
    });

    interface Rebalance {
         tokenA: string,
         tokenB: string,
         truePriceTokenA: number,
         truePriceTokenB: number,
         liquidity: BigNumber,
         deadline: number
    }

    describe("general", () => {
        it("#rebalance", async () => {
            const ERC20Mock = await ethers.getContractFactory(
              'ERC20Mock'
            );

            const UniswapV2Pair = await ethers.getContractFactory(
              UniswapV2PairArtifacts.abi,
              UniswapV2PairArtifacts.bytecode
            );

            let tokenA = await ERC20Mock.deploy('Token A', 'AAA')
            await tokenA.deployed()
            let tokenB = await ERC20Mock.deploy('Token B', 'BBB')
            await tokenB.deployed()

            await tokenA.mint(ALICE, parseEther('110000000.0'))
            await tokenB.mint(ALICE, parseEther('110000000.0'))

            await tokenA.connect(ALICE_SIGNER).approve(router.address, ethers.constants.MaxUint256)
            await tokenB.connect(ALICE_SIGNER).approve(router.address, ethers.constants.MaxUint256)

            await router.connect(ALICE_SIGNER).addLiquidity(
                tokenA.address,
                tokenB.address,
                parseEther('100000000.0'),
                parseEther('100000000.0'),
                0,
                0,
                optimizer.address,
                getCurrentTimestamp() + 1000
            )

            let pair: Contract = await UniswapV2Pair.attach(String(await factory.getPair(tokenA.address, tokenB.address)))

            console.log('Reserves before: ')
            console.log(await pair.getReserves())

            console.log('Trade balance before: ')
            console.log(await tokenA.balanceOf(optimizer.address))
            console.log(await tokenB.balanceOf(optimizer.address))

            let liquidity: BigNumber = await pair.balanceOf(optimizer.address)
            console.log(`Liquidity: ${liquidity}`)

            let data: Rebalance = {
                tokenA: tokenA.address,
                tokenB: tokenB.address,
                truePriceTokenA: 100,
                truePriceTokenB: 99,
                liquidity: liquidity,
                deadline: getCurrentTimestamp() + 1000
            }
            await optimizer.rebalance(data)

            console.log('Reserves after: ')
            console.log(await pair.getReserves())

            console.log('Trade balance after: ')
            console.log(await tokenA.balanceOf(optimizer.address))
            console.log(await tokenB.balanceOf(optimizer.address))

            liquidity = await pair.balanceOf(optimizer.address)
            console.log(`Liquidity: ${liquidity}`)
        });

        it.only("#rebalance with small liquidity", async () => {
            const ERC20Mock = await ethers.getContractFactory(
              'ERC20Mock'
            );

            const UniswapV2Pair = await ethers.getContractFactory(
              UniswapV2PairArtifacts.abi,
              UniswapV2PairArtifacts.bytecode
            );

            let tokenA = await ERC20Mock.deploy('Token A', 'AAA')
            await tokenA.deployed()
            let tokenB = await ERC20Mock.deploy('Token B', 'BBB')
            await tokenB.deployed()

            await tokenA.mint(ALICE, parseEther('110000000.0'))
            await tokenB.mint(ALICE, parseEther('110000000.0'))

            await tokenA.connect(ALICE_SIGNER).approve(router.address, ethers.constants.MaxUint256)
            await tokenB.connect(ALICE_SIGNER).approve(router.address, ethers.constants.MaxUint256)

            await router.connect(ALICE_SIGNER).addLiquidity(
              tokenA.address,
              tokenB.address,
              parseEther('100000000.0'),
              parseEther('100000000.0'),
              0,
              0,
              ALICE,
              getCurrentTimestamp() + 1000
            )

            let pair: Contract = await UniswapV2Pair.attach(String(await factory.getPair(tokenA.address, tokenB.address)))

            let aliceLiquidity: BigNumber = await pair.balanceOf(ALICE)
            await pair.connect(ALICE_SIGNER).transfer(optimizer.address, aliceLiquidity.mul(BigNumber.from(5)).div(BigNumber.from(100)))

            console.log('Reserves before: ')
            console.log(await pair.getReserves())

            console.log('Trade balance before: ')
            console.log(await tokenA.balanceOf(optimizer.address))
            console.log(await tokenB.balanceOf(optimizer.address))

            let liquidity: BigNumber = await pair.balanceOf(optimizer.address)
            console.log(`Liquidity: ${liquidity}`)

            // Rebalance 1%
            let data: Rebalance = {
                tokenA: tokenA.address,
                tokenB: tokenB.address,
                truePriceTokenA: 100,
                truePriceTokenB: 99,
                liquidity: liquidity,
                deadline: getCurrentTimestamp() + 1000
            }
            await optimizer.rebalance(data)

            console.log('Reserves after: ')
            console.log(await pair.getReserves())

            console.log('Trade balance after: ')
            console.log(await tokenA.balanceOf(optimizer.address))
            console.log(await tokenB.balanceOf(optimizer.address))

            liquidity = await pair.balanceOf(optimizer.address)
            console.log(`Liquidity: ${liquidity}`)

            // Rebalance -8%
            data = {
                tokenA: tokenA.address,
                tokenB: tokenB.address,
                truePriceTokenA: 100,
                truePriceTokenB: 92,
                liquidity: liquidity,
                deadline: getCurrentTimestamp() + 1000
            }
            await optimizer.rebalance(data)

            console.log('Reserves after: ')
            console.log(await pair.getReserves())

            console.log('Trade balance after: ')
            console.log(await tokenA.balanceOf(optimizer.address))
            console.log(await tokenB.balanceOf(optimizer.address))

            liquidity = await pair.balanceOf(optimizer.address)
            console.log(`Liquidity: ${liquidity}`)

            // Rebalance +10%
            data = {
                tokenA: tokenA.address,
                tokenB: tokenB.address,
                truePriceTokenA: 92,
                truePriceTokenB: 100,
                liquidity: liquidity,
                deadline: getCurrentTimestamp() + 1000
            }
            await optimizer.rebalance(data)

            console.log('Reserves after: ')
            console.log(await pair.getReserves())

            console.log('Trade balance after: ')
            console.log(await tokenA.balanceOf(optimizer.address))
            console.log(await tokenB.balanceOf(optimizer.address))

            liquidity = await pair.balanceOf(optimizer.address)
            console.log(`Liquidity: ${liquidity}`)
        });
    });
});
