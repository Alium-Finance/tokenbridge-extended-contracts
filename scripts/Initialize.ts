import hre from "hardhat";
const ethers = hre.ethers;

import TransparentUpgradeableProxyArtifact from "@openzeppelin/contracts/build/contracts/TransparentUpgradeableProxy.json"

async function main() {
    const [owner] = await ethers.getSigners();
    console.log(`Upgredeable admin: ${owner.address}`)

    // We get the contract to deploy
    const MulticallUserExecutable = await hre.ethers.getContractFactory("MulticallUserExecutable");
    const MulticallAMBExecutable = await hre.ethers.getContractFactory("MulticallAMBExecutable");
    const EventLogger = await ethers.getContractFactory("EventLogger");

    let ambAddress: string = "",
        almAddress: string = "",
        userMulticallAddress: string = "",
        ambMulticallAddress: string = "",
        eventLoggerAddress: string = "",
        ambOperatorAddress: string = "",
        resolvedRoutersAddresses: string[] = []

    if (hre.network.name === 'bscTestnet') {
        ambAddress = "0x9Bcd96627B76d6A976C4567Bb6C834aB0F217C95";
        almAddress = "0x6f58aCfaEB1BfDC9c4959c43aDdE7a3b63BF019f";
        userMulticallAddress = "0x4a96dA9a59cAfAe2260833c07C3737490D5bdfba";
        ambMulticallAddress = "0xec6982843Cb5f9625Fe81483fAA4dB022D900a45";
        eventLoggerAddress = "0xccB18C1030072E3A401feC079a247a69EBFC1eE8";
        ambOperatorAddress = "0x94E2b88Db76F4E3AB6CAf0fd6dF1b79d858fDa6A";
        resolvedRoutersAddresses = [
            "0x723792a3e412FC4ffB9a0ACA0a152bC2D210b957"
        ];
    }

    if (hre.network.name === 'phantomTestnet') {
        ambAddress = "0x0E9953EE0dAa2EfBCE776fEed2ef97239E4fa030";
        almAddress = "0x91dc5712460550849a7664a6177b407eeb833d9d";
        userMulticallAddress = "0x4a96dA9a59cAfAe2260833c07C3737490D5bdfba" //"0x1b1CD5E15C1d0E84cbffF8F7Df514e4f90031FdC";
        ambMulticallAddress = "0xec6982843Cb5f9625Fe81483fAA4dB022D900a45";
        eventLoggerAddress = "0xEC914956a4ab3feC6EdA3334002c3A975D62e142";
        ambOperatorAddress = "0x94E2b88Db76F4E3AB6CAf0fd6dF1b79d858fDa6A";
        resolvedRoutersAddresses = [
            "0x54a472C96b01f8639326D49Ef3eD4B9a78C3ba63"
        ];
    }

    const userMulticall = await MulticallUserExecutable.attach(userMulticallAddress);
    const ambMulticall = await MulticallAMBExecutable.attach(ambMulticallAddress);
    const eventLogger = await EventLogger.attach(eventLoggerAddress);

    await userMulticall.setResolvedRouters(resolvedRoutersAddresses)
    console.log("Routers set successfully!")
    await userMulticall.setAMB(ambAddress)
    console.log("AMB set successfully!")
    await userMulticall.setALM(almAddress)
    console.log("ALM set successfully!")
    await userMulticall.approveALMToAMB()
    console.log("Approved ALM to AMB set successfully!")
    await userMulticall.setEventLogger(eventLogger.address)
    console.log("Event logger set successfully!")

    await ambMulticall.setOperator(ambOperatorAddress, true)
    console.log("Operator AMB set successfully!")

    await eventLogger.grantRole(String(await eventLogger.MANAGER_ROLE()), userMulticallAddress)
    console.log("Event logger manager role granted set successfully!")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
