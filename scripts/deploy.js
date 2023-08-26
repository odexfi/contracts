const hre = require("hardhat");

const slowDown =  18000;

async function main() {
    [owner] = await ethers.getSigners();
    // Deploy Odex
    const Odex = await ethers.getContractFactory("Odex");
    const odex = await Odex.deploy();
    console.log(`odex: ${odex.address}`);

    // Deploy Factory
    const OdexFactory = await ethers.getContractFactory("OdexFactory");
    const odexFactory = await OdexFactory.deploy(odex.address);
    console.log(`odexFactory: ${odexFactory.address}`);

    // Deploy Mocks
    const Token = await ethers.getContractFactory("Token");
    const WETH = await ethers.getContractFactory("WETH");
    const USD = await ethers.getContractFactory("USD");
    const wbtc = await Token.deploy('Wrapped Bitcoin','wBTC');
    console.log(`wbtc: ${wbtc.address}`);
    const weth = await WETH.deploy();
    console.log(`weth: ${weth.address}`);
    const usd = await USD.deploy();
    console.log(`usd: ${usd.address}`);
    const odexTokenAddress = await odex.odexToken();
    console.log(`odexToken: ${odexTokenAddress}`);

    // Deploy Markets
    const minOrder = ethers.utils.parseUnits("1", 6);
    const roundTick = ethers.utils.parseUnits("1", 6);
    await odexFactory.deploy(wbtc.address,usd.address,minOrder,roundTick);
    await new Promise(r => setTimeout(r, slowDown));
    const wbtcMarket = await odex.odexs(0);
    console.log(`wbtcMarket: ${wbtcMarket[0]}`);
    await odexFactory.deploy(weth.address,usd.address,minOrder,roundTick);
    await new Promise(r => setTimeout(r, slowDown));
    const wethMarket = await odex.odexs(1);
    console.log(`wethMarket: ${wethMarket[0]}`);
    await odexFactory.deploy(odexTokenAddress,usd.address,minOrder,roundTick);
    await new Promise(r => setTimeout(r, slowDown));
    const odexMarket = await odex.odexs(2);
    console.log(`odexMarket: ${odexMarket[0]}`);

    // JSON Output
    const contracts = {
      odex: odex.address,
      odexFactory: odexFactory.address,
      wbtc: wbtc.address,
      weth: weth.address,
      usd: usd.address,
      odexToken: odexTokenAddress,
      wbtcMarket: wbtcMarket[0],
      wethMarket: wethMarket[0],
      odexMarket: odexMarket[0],
    }
    console.log(contracts);

    // Verify Etherscan
    await hre.run("verify:verify", {
      address: odex.address,
      constructorArguments: [
      ],
    });
    await new Promise(r => setTimeout(r, slowDown));
    await hre.run("verify:verify", {
      address: odexFactory.address,
      constructorArguments: [
        odex.address,
      ],
    });
    await new Promise(r => setTimeout(r, slowDown));
    await hre.run("verify:verify", {
      address: wbtc.address,
      constructorArguments: [
        'Wrapped Bitcoin','wBTC'
      ],
    });
    await new Promise(r => setTimeout(r, slowDown));
    await hre.run("verify:verify", {
      address: weth.address,
      constructorArguments: [
      ],
    });
    await new Promise(r => setTimeout(r, slowDown));
    await hre.run("verify:verify", {
      address: usd.address,
      constructorArguments: [
      ],
    });
    await new Promise(r => setTimeout(r, slowDown));
    await hre.run("verify:verify", {
      address: odexTokenAddress,
      constructorArguments: [
        owner.address,
      ],
    });
    await new Promise(r => setTimeout(r, slowDown));
    await hre.run("verify:verify", {
      address: wbtcMarket[0],
      constructorArguments: [
        wbtcMarket[4],
        odex.address,
        owner.address,
        wbtcMarket[2],
        wbtcMarket[3],
        wbtcMarket[6],
        wbtcMarket[7],
        wbtcMarket[8],
      ],
    });
    await new Promise(r => setTimeout(r, slowDown));
    await hre.run("verify:verify", {
      address: wethMarket[0],
      constructorArguments: [
        wethMarket[4],
        odex.address,
        owner.address,
        wethMarket[2],
        wethMarket[3],
        wethMarket[6],
        wethMarket[7],
        wethMarket[8],
      ],
    });
    await new Promise(r => setTimeout(r, slowDown));
    await hre.run("verify:verify", {
      address: odexMarket[0],
      constructorArguments: [
        odexMarket[4],
        odex.address,
        owner.address,
        odexMarket[2],
        odexMarket[3],
        odexMarket[6],
        odexMarket[7],
        odexMarket[8],
      ],
    });
    console.log('Verification complete');

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
