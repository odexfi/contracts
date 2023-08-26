const hre = require("hardhat");
async function main() {
    const OdexFactory = await ethers.getContractFactory("OdexFactory");
    const odexFactory = OdexFactory.attach('0x2d99952E332f79f3EdEa71f7Bd2252A11f655be1');
    const wbtcOdex = await odexFactory.odexs(0);
    console.log(`wbtcOdex: ${wbtcOdex[0]}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
