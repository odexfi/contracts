const { expect } = require("chai");

describe("OdexMarket", function () {
  let odex, odexMarket, owner, trader1, trader2, token, usd, odexToken;

  async function deploy() {
    [owner, trader1, trader2] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("Token");
    const USD = await ethers.getContractFactory("USD");
    token = await Token.deploy('WETH','WETH');
    usd = await USD.deploy();
    const Odex = await ethers.getContractFactory("Odex");
    const odex = await Odex.deploy();
    const OdexFactory = await ethers.getContractFactory("OdexFactory");
    const odexFactory = await OdexFactory.deploy(odex.address);
    const minOrder = ethers.utils.parseUnits("1", 6);
    const roundTick = ethers.utils.parseUnits("1", 6);
    await odexFactory.deploy(token.address,usd.address,minOrder,roundTick);
    const firstODEX = await odex.odexs(0);
    odexMarket = await ethers.getContractAt("contracts/OdexMarket.sol:OdexMarket", firstODEX[0]);
    const odexTokenAddress = await odex.odexToken();
    odexToken = await ethers.getContractAt("contracts/OdexToken.sol:OdexToken", odexTokenAddress);
  }

  describe("Deployment", async function () {
    it("Should deploy", async function () {
      await deploy();
      expect(await odexMarket.token()).to.eq(token.address);
      expect(await odexMarket.baseAsset()).to.eq(usd.address);
      expect(await token.symbol()).to.eq('WETH');
      expect(await usd.symbol()).to.eq('gUSD');
    });

  });

  describe("Test token baseAsset conversion", async function () {
    it("multiplier", async function () {
      const expected = ethers.utils.parseEther("1");
      const multiplier = await odexMarket.multiplier();
      expect(multiplier).to.eq(expected);
    });
    it("tokensToBaseAssets", async function () {
      const tokenAmount = 1000000000000000n;
      const price = 2001000000n;
      const baseAssetAmount = await odexMarket.tokensToBaseAsset(tokenAmount, price);
      expect(baseAssetAmount).to.gt(0);
    });
    it("baseAssetToTokens", async function () {
      const baseAssetAmount = 5000000n;
      const price = 2001000000n;
      const tokenAmount = await odexMarket.baseAssetToTokens(baseAssetAmount, price);
      expect(tokenAmount).to.gt(0);
    });
  });

  describe("Test Orders Add Liquidity", async function () {
    it("Send some funds", async function () {
      const tokenAmount = ethers.utils.parseEther("5");
      const usdAmount = ethers.utils.parseUnits("10000", 6);
      const usdBalance = await usd.balanceOf(owner.address);
      const tokenBalance = await token.balanceOf(owner.address);
      expect(usdBalance).to.gt(usdAmount);
      expect(tokenBalance).to.gt(tokenAmount);
      await usd.connect(owner).transfer(trader1.address, usdAmount);
      await token.connect(owner).transfer(trader1.address, tokenAmount);
      await owner.sendTransaction({
        to: trader1.address,
        value: ethers.utils.parseEther("1")
      });
      await usd.connect(owner).transfer(trader2.address, usdAmount);
      await token.connect(owner).transfer(trader2.address, tokenAmount);
      await owner.sendTransaction({
        to: trader2.address,
        value: ethers.utils.parseEther("1")
      });
    });

    it("Place limitOrderBuy", async function () {
      const amount = ethers.utils.parseUnits("10", 6);
      const price = ethers.utils.parseUnits("1998", 6);
      await usd.connect(trader1).approve(odexMarket.address, amount);
      await odexMarket.connect(trader1).limitOrderBuy(amount, price);
      const highestBid = await odexMarket.highestBid();
      expect(highestBid[0]).to.eq(BigInt(amount));
      expect(highestBid[1]).to.eq(BigInt(price));
      const lowestBid = await odexMarket.lowestBid();
      expect(lowestBid[0]).to.eq(BigInt(amount));
      expect(lowestBid[1]).to.eq(BigInt(price));
    });

    it("Place limitOrderSell", async function () {
      const amount = ethers.utils.parseEther("0.001");
      const price = ethers.utils.parseUnits("2002", 6);
      await token.connect(trader1).approve(odexMarket.address, amount);
      await odexMarket.connect(trader1).limitOrderSell(amount, price);
      const highestAsk = await odexMarket.highestAsk();
      expect(highestAsk[0]).to.eq(BigInt(amount));
      expect(highestAsk[1]).to.eq(BigInt(price));
      const lowestAsk = await odexMarket.lowestAsk();
      expect(lowestAsk[0]).to.eq(BigInt(amount));
      expect(lowestAsk[1]).to.eq(BigInt(price));
    });

    it("Place more competitve limitOrderBuy", async function () {
      const amount = ethers.utils.parseUnits("10", 6);
      const price = ethers.utils.parseUnits("1999", 6); // try less competitive order
      await usd.connect(trader1).approve(odexMarket.address, amount);
      await odexMarket.connect(trader1).limitOrderBuy(amount, price);
      const highestBid = await odexMarket.highestBid();
      expect(highestBid[0]).to.eq(BigInt(amount));
      expect(highestBid[1]).to.eq(BigInt(price));
    });

    it("Place more competitve limitOrderSell", async function () {
      const amount = ethers.utils.parseEther("0.001");
      const price = ethers.utils.parseUnits("2001", 6);
      await token.connect(trader1).approve(odexMarket.address, amount);
      await odexMarket.connect(trader1).limitOrderSell(amount, price);
      const lowestAsk = await odexMarket.lowestAsk();
      expect(lowestAsk[0]).to.eq(BigInt(amount));
      expect(lowestAsk[1]).to.eq(BigInt(price));
    });
  });

  describe("Test Orders Take Liquidity", async function () {
    
    it("Place limitOrderBuy", async function () {
      const amount = ethers.utils.parseUnits("5", 6);
      const price = ethers.utils.parseUnits("9999", 6);
      const tokenBal = await token.balanceOf(trader2.address);
      const usdBal = await usd.balanceOf(trader2.address);
      await usd.connect(trader2).approve(odexMarket.address, amount);
      await odexMarket.connect(trader2).limitOrderBuy(amount, price);
      const tokenBal2 = await token.balanceOf(trader2.address);
      const usdBal2 = await usd.balanceOf(trader2.address);
      expect(tokenBal2).to.gt(tokenBal);
      expect(usdBal2).to.lt(usdBal);
    });

    it("Place limitOrderSell", async function () {
      const amount = ethers.utils.parseEther("0.0015");
      const price = ethers.utils.parseUnits("1000", 6);
      const tokenBal = await token.balanceOf(trader2.address);
      const usdBal = await usd.balanceOf(trader2.address);
      await token.connect(trader2).approve(odexMarket.address, amount);
      await odexMarket.connect(trader2).limitOrderSell(amount, price);
      const tokenBal2 = await token.balanceOf(trader2.address);
      const usdBal2 = await usd.balanceOf(trader2.address);
      expect(tokenBal2).to.lt(tokenBal);
      expect(usdBal2).to.gt(usdBal);
    });
  });

});
