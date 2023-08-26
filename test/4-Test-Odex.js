const { expect } = require("chai");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Odex", function () {
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
      await odexFactory.connect(owner).deploy(token.address, usd.address, minOrder, roundTick);
      
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
            value: ethers.utils.parseEther("0.1")
          });
          await usd.connect(owner).transfer(trader2.address, usdAmount);
          await token.connect(owner).transfer(trader2.address, tokenAmount);
          await owner.sendTransaction({
            to: trader2.address,
            value: ethers.utils.parseEther("0.1")
          });
        });
    
        it("Make Some Trades", async function () {
          const usdAmount = ethers.utils.parseUnits("2000", 6);
          const price = ethers.utils.parseUnits("1800", 6);
          await usd.connect(trader1).approve(odexMarket.address, usdAmount);
          await odexMarket.connect(trader1).limitOrderBuy(usdAmount, price);
          const highestBid = await odexMarket.highestBid();
          expect(highestBid[0]).to.eq(BigInt(usdAmount));
          expect(highestBid[1]).to.eq(BigInt(price));
          const ethAmount = ethers.utils.parseEther("1");
          const tokenBal = await token.balanceOf(trader2.address);
          const usdBal = await usd.balanceOf(trader2.address);
          await token.connect(trader2).approve(odexMarket.address, ethAmount);
          await odexMarket.connect(trader2).limitOrderSell(ethAmount, price);
          const tokenBal2 = await token.balanceOf(trader2.address);
          const usdBal2 = await usd.balanceOf(trader2.address);
          expect(tokenBal2).to.lt(tokenBal);
          expect(usdBal2).to.gt(usdBal);
        });
    
        it("Check Trader ODEX Rewards", async function () {
          const odexBal1 = await odexToken.balanceOf(trader1.address);
          const rewardMinAmount = ethers.utils.parseEther("19");
          expect(odexBal1).to.gt(rewardMinAmount);
          const odexBal2 = await odexToken.balanceOf(trader2.address);
          
        });
      });
    
      describe("Metadata", async function () {
        it("Add metadata", async function () {
          await odex.connect(trader1).update('@myhandle');
          const me = await odex.metadata(trader1.address);
          expect(me).to.eq('@myhandle');
        });
      });


  });

});
