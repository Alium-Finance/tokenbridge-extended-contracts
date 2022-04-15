import hre from "hardhat";

import TransparentUpgradeableProxyArtifact from "@openzeppelin/contracts/build/contracts/TransparentUpgradeableProxy.json"

async function main() {
    const [owner] = await hre.ethers.getSigners();
    console.log(`Upgredeable admin: ${owner.address}`)

    // We get the contract to deploy
    const MulticallUserExecutable = await hre.ethers.getContractFactory("MulticallUserExecutable");
    const MulticallAMBExecutable = await hre.ethers.getContractFactory("MulticallAMBExecutable");
    const EventLogger = await hre.ethers.getContractFactory("EventLogger");

    const TransparentUpgradeableProxy = await hre.ethers.getContractFactory(
        TransparentUpgradeableProxyArtifact.abi,
        TransparentUpgradeableProxyArtifact.bytecode
    )

    const userMulticall = await MulticallUserExecutable.deploy();
    await userMulticall.deployed();
    console.log("MulticallUserExecutable implementation at:", userMulticall.address);

    const ambMulticall = await MulticallAMBExecutable.deploy();
    await ambMulticall.deployed();
    console.log("MulticallAMBExecutable implementation at:", ambMulticall.address);

    const eventLogger = await EventLogger.deploy(owner.address);
    await eventLogger.deployed();
    console.log("EventLogger implementation at:", eventLogger.address);

    const userMulticallProxy = await TransparentUpgradeableProxy.deploy(
        userMulticall.address,
        owner.address,
        "0x"
    )
    console.log("MulticallUserExecutable proxy deployed to:", userMulticallProxy.address);

    const ambMulticallProxy = await TransparentUpgradeableProxy.deploy(
        ambMulticall.address,
        owner.address,
        "0x"
    )
    console.log("MulticallAMBExecutable proxy deployed to:", ambMulticallProxy.address);

    const eventLoggerProxy = await TransparentUpgradeableProxy.deploy(
        eventLogger.address,
        owner.address,
        "0x"
    )
    console.log("EventLogger proxy deployed to:", eventLoggerProxy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
