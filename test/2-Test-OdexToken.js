const { expect } = require("chai");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Odex", function () {
  let odexToken, owner, team, user1, user2, user3;
  const days = 60n * 60n * 24n;

  async function deploy() {
    [owner, team, user1, user2, user3] = await ethers.getSigners();
    const OdexToken = await ethers.getContractFactory("OdexToken");
    odexToken = await OdexToken.deploy(team.address);
  }

  describe("Deployment", async function () {
    it("Should deploy", async function () {
      await deploy();
      expect(await odexToken.symbol()).to.eq('ODEX');
    });
  });

  describe("Token Sale", function () {
    it("Should fail transfer due to token lock", async function () {
      await expect(odexToken.connect(owner).transfer(user1.address, 1000)).to.be.revertedWith('Token transfers not enabled yet');
    });

    it("Should fail to buyTokens before sale", async function () {
      const value = ethers.utils.parseEther("0.1");
      await expect(odexToken.connect(user2).buyTokens({value})).to.be.revertedWith('too soon');
    });

    it("Price per day should start correctly", async function () {
      const price = await odexToken.pricePerDay(0);
      const startingPrice = ethers.utils.parseEther("0.00001");
      await expect(price).to.eq(startingPrice);
    });

    it("Price per day should end correctly", async function () {
      const price = await odexToken.pricePerDay(30);
      const closingPrice = ethers.utils.parseEther("0.000013");
      await expect(price).to.eq(closingPrice);
    });

    it("Roll blockchain forwards to startDate", async function () {
      const startDate = await odexToken.startDate();
      await time.increaseTo(startDate);
    });
    
    it("Staggered Price should deliver price increases daily", async function () {
      const price1 = await odexToken.staggeredPrice();
      const startDate = await odexToken.startDate();
      const time1 = BigInt(startDate) + days - 60n;
      await time.increaseTo(time1);
      const price2 = await odexToken.staggeredPrice();
      await expect(price1).to.eq(price2);
      const time2 = BigInt(startDate) + days + 60n;
      await time.increaseTo(time2);
      const price3 = await odexToken.staggeredPrice();
      await expect(price3).to.gt(price1);
    });

    it("Should buyTokens", async function () {
      const value = ethers.utils.parseEther("0.1");
      const price = await odexToken.staggeredPrice();
      const multiplier = ethers.utils.parseEther("1");
      const amountOut = BigInt(value / price * multiplier);
      await odexToken.connect(user2).buyTokens({value});
      const balance = await odexToken.balanceOf(user2.address);
      // within 1bps
      const amountOutMin = amountOut * 9999n / 10000n;
      expect(balance).to.gt(amountOutMin);
      const amountOutMax = amountOut * 10001n / 10000n;
      expect(balance).to.lt(amountOutMax);
    });

    it("Roll blockchain forwards to endDate", async function () {
      const endDate = await odexToken.endDate();
      const afterClose = BigInt(endDate) + 60n;
      await time.increaseTo(afterClose);
    });

    it("Should goLive", async function () {
      await odexToken.connect(team).goLive();
      const bool = await odexToken.tokenLive();
      expect(bool).to.eq(true);
    });

    it("Should fail to buyTokens after close", async function () {
      const value = ethers.utils.parseEther("0.1");
      await expect(odexToken.connect(user2).buyTokens({value})).to.be.revertedWith('too late');
    });
  });

  describe("Standard ERC20", function () {
    it("Should transfer tokens from owner to user1", async function () {
      await odexToken.transfer(user1.address, 100);
      expect(await odexToken.balanceOf(user1.address)).to.eq(100);
    });
  
    it("Should fail if sender doesn’t have enough tokens", async function () {
      await expect(odexToken.connect(user1).transfer(owner.address, 1000)).to.be.revertedWith('ERC20: transfer amount exceeds balance');
    });

    it("Should approve tokens for spending by another address", async function () {
      await odexToken.connect(owner).approve(user1.address, 1000);
      expect(await odexToken.allowance(owner.address, user1.address)).to.eq(1000);
    });

    it("Should transfer tokens from one address to another using allowance", async function () {
      await odexToken.connect(user1).transferFrom(owner.address, user1.address, 1000);
      expect(await odexToken.balanceOf(user1.address)).to.eq(1100);
    });
  
    it("Should fail if sender tries to transfer more than allowance", async function () {
      await odexToken.approve(user1.address, 100);
      await expect(odexToken.connect(user1).transferFrom(owner.address, user1.address, 101)).to.be.revertedWith('ERC20: insufficient allowance');
    });

    it("Should return the correct balance", async function () {
      expect(await odexToken.balanceOf(user1.address)).to.eq(1100);
    });
  });

  describe("Minting", function () {
    it("Should mint community tokens", async function () {
      const value = ethers.utils.parseEther("50000000");
      await odexToken.connect(team).mintCommunity(user3.address, value);
      expect(await odexToken.balanceOf(user3.address)).to.eq(value);
    });
    it("Should fail to mint community more", async function () {
      const value = ethers.utils.parseEther("1");
      await expect(odexToken.connect(team).mintCommunity(user3.address, value)).to.be.revertedWith('exceeds mint limit');
    });
    it("Should mint partner tokens", async function () {
      const value = ethers.utils.parseEther("200000000");
      const expected = ethers.utils.parseEther("250000000");
      await odexToken.connect(team).mintPartner(user3.address, value);
      expect(await odexToken.balanceOf(user3.address)).to.eq(expected);
    });
    it("Should fail to mint partner more", async function () {
      const value = ethers.utils.parseEther("1");
      await expect(odexToken.connect(team).mintPartner(user3.address, value)).to.be.revertedWith('exceeds mint limit');
    });
    it("Should mint liquidity tokens", async function () {
      const value = ethers.utils.parseEther("50000000");
      const expected = ethers.utils.parseEther("300000000");
      await odexToken.connect(team).mintLiquidity(user3.address, value);
      expect(await odexToken.balanceOf(user3.address)).to.eq(expected);
    });
    it("Should fail to mint liquidity more", async function () {
      const value = ethers.utils.parseEther("1");
      await expect(odexToken.connect(team).mintLiquidity(user3.address, value)).to.be.revertedWith('exceeds mint limit');
    });
    it("Should fail to mint team tokens", async function () {
      const value = ethers.utils.parseEther("50000000");
      await expect(odexToken.connect(team).unlockTeamTokens(user3.address, value)).to.be.revertedWith('too soon');
    });
    it("Roll blockchain forwards to unlock", async function () {
      const endDate = await odexToken.endDate();
      const afterClose = BigInt(endDate) + 31560000n;
      await time.increaseTo(afterClose);
    });
    it("Should unlock team tokens", async function () {
      const value = ethers.utils.parseEther("50000000");
      const expected = ethers.utils.parseEther("350000000");
      await odexToken.connect(team).unlockTeamTokens(user3.address, value);
      expect(await odexToken.balanceOf(user3.address)).to.eq(expected);
    });
  });
});
