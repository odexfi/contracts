const hre = require("hardhat");

const contracts = {
    odex: '0x4ADf8fcE21302611aBBE3C43E6A2c5B46f8345A4',
    odexFactory: '0x06735E0951D84C4C4d4258aBF5B5aa281Bb96812',
    wbtc: '0xCd14Cd33C7Cb5ECBC9C0390f561B0110983F3A49',
    weth: '0x2ca583bF70155ec792D07D5F4D1AaFc522AD5e70',
    usd: '0x85B5eea334737318b902bDeF434E63ec5efBc113',
    odexToken: '0x553C033863B755E97FF96Ec1b633a89f8F26dBfA',
    wbtcMarket: '0xa9b050Bf7a714B5f43B3178c1E5e4d4eAE1584FF',
    wethMarket: '0x0F9a8be03cDD33E4E943d205c0B0Db1a3f1cF380',
    odexMarket: '0xE5Bca9b164cC27D9F845F641782aeFc77d62d4FC'
}

async function main() {
    const OdexMarket = await ethers.getContractFactory("OdexMarket");
    const odexMarket = OdexMarket.attach(contracts.wethMarket);
    [owner] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("Token");
    const USD = await ethers.getContractFactory("USD");
    const token = Token.attach(contracts.weth);
    const usd = USD.attach(contracts.usd);
    const tokenBalance = await token.balanceOf(owner.address);
    const usdBalance = await usd.balanceOf(owner.address);
    await token.connect(owner).approve(odexMarket.address, tokenBalance);
    await usd.connect(owner).approve(odexMarket.address, usdBalance);
    for (let i = 0; i < 500; i++) {
        const randomUSD = Math.floor(Math.random() * 2000) + 1;
        const usdAmount = ethers.utils.parseUnits(randomUSD.toString(), 6);
        const randomETH = Math.random().toFixed(6);
        const ethAmount = ethers.utils.parseEther(randomETH);
        const randomPrice = Math.floor(Math.random() * 20) + 1800;
        const price = ethers.utils.parseUnits(randomPrice.toString(), 6);
        if (Math.random() > 0.5) {
            console.log(`Buying $${usdAmount}`)
            const tx = await odexMarket.connect(owner).limitOrderBuy(usdAmount, price);
            tx.wait();
        } else {
            console.log(`Selling ${ethAmount} wei`)
            const tx = await odexMarket.connect(owner).limitOrderSell(ethAmount, price);
            tx.wait();
        }
    }
}

main().catch((error) => {
  console.error(error);
  //process.exitCode = 1;
});
