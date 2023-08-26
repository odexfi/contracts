const { expect } = require("chai");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("OdexFactory", function () {
  let odexFactory, odex, owner, trader1, trader2, token, usd, odexToken;

  async function deploy() {
    [owner, trader1, trader2] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("Token");
    const USD = await ethers.getContractFactory("USD");
    token = await Token.deploy('WETH','WETH');
    usd = await USD.deploy();
    const Odex = await ethers.getContractFactory("Odex");
    odex = await Odex.deploy();
    const OdexFactory = await ethers.getContractFactory("OdexFactory");
    odexFactory = await OdexFactory.deploy(odex.address);
  }

  describe("Deployment", async function () {
    it("Should deploy", async function () {
      await deploy();
    });

    it("Should setup new market", async function () {
      const minOrder = ethers.utils.parseUnits("1", 6);
      const roundTick = ethers.utils.parseUnits("1", 6);
      await odexFactory.deploy(token.address, usd.address, minOrder, roundTick);
      
      const firstODEX = await odex.odexs(0);
      odexMarket = await ethers.getContractAt("contracts/OdexMarket.sol:OdexMarket", firstODEX[0]);
      expect(await odexMarket.token()).to.eq(token.address);
      expect(await odexMarket.baseAsset()).to.eq(usd.address);
      const odexInfo = await odex.odexs(0);
      expect(odexInfo[0]).to.eq(odexMarket.address);
      expect(odexInfo[1]).to.eq(owner.address);
      expect(odexInfo[2]).to.eq(token.address);
      expect(odexInfo[3]).to.eq(usd.address);
      expect(odexInfo[4]).to.eq(0n);  
      expect(odexInfo[6]).to.eq(1000000n);      
    });

  });

});
