import hre from "hardhat";
const ethers = hre.ethers;

import TransparentUpgradeableProxyArtifact from "@openzeppelin/contracts/build/contracts/TransparentUpgradeableProxy.json"

async function main() {
    const [owner] = await ethers.getSigners();
    console.log(`Upgredeable admin: ${owner.address}`)

    // We get the contract to deploy
    const MulticallUserExecutable = await hre.ethers.getContractFactory("MulticallUserExecutable");
    const MulticallAMBExecutable = await hre.ethers.getContractFactory("MulticallAMBExecutable");

    const userMulticall = await MulticallUserExecutable.deploy();
    await userMulticall.deployed();
    console.log("MulticallUserExecutable implementation at:", userMulticall.address);

    const ambMulticall = await MulticallAMBExecutable.deploy();
    await ambMulticall.deployed();
    console.log("MulticallAMBExecutable implementation at:", ambMulticall.address);

    const TransparentUpgradeableProxy = await hre.ethers.getContractFactory(
        TransparentUpgradeableProxyArtifact.abi,
        TransparentUpgradeableProxyArtifact.bytecode
    )

    const userMulticallProxy = await TransparentUpgradeableProxy.deploy(
        userMulticall.address,
        owner.address,
        "0x"
    )
    console.log("MulticallUserExecutable deployed to:", userMulticallProxy.address);

    const ambMulticallProxy = await TransparentUpgradeableProxy.deploy(
        ambMulticall.address,
        owner.address,
        "0x"
    )
    console.log("MulticallAMBExecutable deployed to:", ambMulticallProxy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
