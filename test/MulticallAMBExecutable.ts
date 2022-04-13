import chai from "chai";

import { ethers } from "hardhat";
import { Signer } from "ethers";
import { solidity } from "ethereum-waffle";
import { Interface, parseEther } from "ethers/lib/utils";

chai.use(solidity);

describe.skip("Multicall AMB executable", function () {
    let accounts: Signer[];

    let OWNER_SIGNER: any;
    let OPERATOR_SIGNER: any;
    let ALICE_SIGNER: any;
    let BOB_SIGNER: any;

    let OWNER: any;
    let OPERATOR: any;
    let ALICE: any;
    let BOB: any;

    let multicall: any;

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

        const MulticallAMBExecutable = await ethers.getContractFactory("MulticallAMBExecutable");
        multicall = await MulticallAMBExecutable.deploy();
        await multicall.deployed()

        await multicall.setOperator(OPERATOR, true)
    });

    describe("success tests", () => {
        it("#execute", async () => {
            const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
            let erc20 = await ERC20Mock.deploy("XXX", "xxx");
            await erc20.deployed()

            await erc20.mint(multicall.address, parseEther("1.0"))

            let erc20Interface = new Interface([...erc20.interface.fragments])

            // @ts-ignore
            const data: string[] = [{
                dest: erc20.address,
                data: erc20Interface.encodeFunctionData('transfer', [
                    BOB,
                    parseEther("1.0")
                ]),
                value: 0
            }];
            await multicall.connect(OPERATOR_SIGNER).execute(data);
        });
    });
});
