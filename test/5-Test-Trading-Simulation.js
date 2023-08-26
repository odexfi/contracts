const { expect } = require("chai");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Trading Simulation", function () {
  let odex, odexMarket, odexFactory, owner, trader1, trader2, token, usd, odexToken;

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
    const odexTokenAddress = await odex.odexToken();
    odexToken = await ethers.getContractAt("contracts/OdexToken.sol:OdexToken", odexTokenAddress);
  }

  describe("Deployment", async function () {
    it("Should deploy", async function () {
      await deploy();
    });

    it("Should setup new market", async function () {
      const minOrder = ethers.utils.parseUnits("1", 6);
      const roundTick = ethers.utils.parseUnits("1", 6);
      await odexFactory.deploy(token.address,usd.address,minOrder,roundTick);
      const firstODEX = await odex.odexs(0);
      odexMarket = await ethers.getContractAt("contracts/OdexMarket.sol:OdexMarket", firstODEX[0]);
    });

  });

  describe("Setup ODEX Rewards", async function () {
    it("Roll blockchain forwards to endDate", async function () {
      const endDate = await odexToken.endDate();
      const afterClose = BigInt(endDate) + 60n;
      await time.increaseTo(afterClose);
    });

    it("Should goLive", async function () {
      await odexToken.connect(owner).goLive();
      const bool = await odexToken.tokenLive();
      expect(bool).to.eq(true);
    });

    it("Should setup ODEX rewards", async function () {
      const ethRewards = 2n * 10n ** 22n;
      const usdRewards = 11n * 10n ** 30n;
      /* 1eth 1800usd trading fees = 10bps 0.001 ETH / 1.8USD
        ETH = 0.001e18 * 2e22 / 1e18 = 20e18 ODEX
        USDC = 1.8e6 * 11e30 / 1e18 = 19.8 ODEX
      */
      await odex.connect(owner).rewardsAsset(token.address,ethRewards);
      await odex.connect(owner).rewardsAsset(usd.address,usdRewards);
    });
  });

  describe("Simulate Trading (slow)", async function () {
    it("Send some funds", async function () {
      const tokenAmount = ethers.utils.parseEther("50");
      const usdAmount = ethers.utils.parseUnits("100000", 6);
      const usdBalance = await usd.balanceOf(owner.address);
      const tokenBalance = await token.balanceOf(owner.address);
      expect(usdBalance).to.gt(usdAmount);
      expect(tokenBalance).to.gt(tokenAmount);
      await usd.connect(owner).transfer(trader1.address, usdAmount);
      await token.connect(owner).transfer(trader1.address, tokenAmount);
      await owner.sendTransaction({
        to: trader1.address,
        value: ethers.utils.parseEther("0.1")
      });
      await usd.connect(owner).transfer(trader2.address, usdAmount);
      await token.connect(owner).transfer(trader2.address, tokenAmount);
      await owner.sendTransaction({
        to: trader2.address,
        value: ethers.utils.parseEther("0.1")
      });
    });

    it("Make 500 random trades between 2 users", async function () {
      for (let i = 0; i < 500; i++) {
        const traders = [trader1,trader2];
        const randomIndex = Math.floor(Math.random() * traders.length);
        const trader = traders[randomIndex];
        const randomUSD = Math.floor(Math.random() * 2000) + 1;
        const usdAmount = ethers.utils.parseUnits(randomUSD.toString(), 6);
        const randomETH = Math.random().toFixed(6);
        const ethAmount = ethers.utils.parseEther(randomETH);
        const randomPrice = Math.floor(Math.random() * 300) + 1800;
        const price = ethers.utils.parseUnits(randomPrice.toString(), 6);
        if (Math.random() > 0.5) {
          //console.log(`Buying $${usdAmount}`)
          await usd.connect(trader).approve(odexMarket.address, usdAmount);
          await odexMarket.connect(trader).limitOrderBuy(usdAmount, price);
        } else {
          //console.log(`Selling ${ethAmount} wei`)
          await token.connect(trader).approve(odexMarket.address, ethAmount);
          await odexMarket.connect(trader).limitOrderSell(ethAmount, price);
        }
      }
    });

    it("Check Trader ODEX Rewards", async function () {
      const odexBal1 = await odexToken.balanceOf(trader1.address);
      const rewardMinAmount = ethers.utils.parseEther("100");
      expect(odexBal1).to.gt(rewardMinAmount);
      const odexBal2 = await odexToken.balanceOf(trader2.address);
      expect(odexBal2).to.gt(rewardMinAmount);
    });
  });
});
