import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Swapper", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployTokenSale() {

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const initialApproval = ethers.parseUnits("10000", 18);


    const TokenA = await ethers.getContractFactory("TokenA")
    const tokenA = await TokenA.deploy()

    const TokenB = await ethers.getContractFactory("TokenB")
    const tokenB = await TokenB.deploy()

    const Swapper = await ethers.getContractFactory("Swapper");
    const swapper = await Swapper.deploy(tokenA, tokenB);
    const contractAddress = await swapper.getAddress();


    // Approve transfers
    await tokenA.connect(owner).approve(contractAddress, initialApproval);
    await tokenB.connect(owner).approve(contractAddress, initialApproval)

    const amountTokensA_1000 = ethers.parseUnits("1000", 18);
    const amountTokenB_1000 = ethers.parseUnits("1000", 18);


    return {
      swapper,
      tokenA,
      tokenB,
      owner,
      otherAccount,
      contractAddress,
      amountTokensA_1000,
      amountTokenB_1000
    };
  }

  async function deployTokenSaleWithLiquidity() {
    const { swapper, amountTokensA_1000, amountTokenB_1000 } = await loadFixture(deployTokenSale);

    await swapper.addLiquidity(amountTokensA_1000, amountTokenB_1000);

    return { swapperLiquid: swapper }
  }

  describe("Adding Liquidity", function () {
    it("Should add initial liquidity for token A and Token B and add these to reserves", async function () {
      const { swapper, amountTokensA_1000, amountTokenB_1000 } = await loadFixture(deployTokenSale);

      await swapper.addLiquidity(amountTokensA_1000, amountTokenB_1000);

      const reserveA = await swapper.reserveTokenA();
      const reserveB = await swapper.reserveTokenB();

      expect(reserveA).to.equal(amountTokensA_1000);
      expect(reserveB).to.equal(amountTokenB_1000);
    });

    it("Should add initial liquidity for token A and Token B and add these to the balance of the contract", async function () {
      const { swapper, amountTokensA_1000, amountTokenB_1000 } = await loadFixture(deployTokenSale);

      await swapper.addLiquidity(amountTokensA_1000, amountTokenB_1000);

      const balanceA = await swapper.getTokenABalance();
      const balanceB = await swapper.getTokenBBalance();

      expect(balanceA).to.equal(amountTokensA_1000);
      expect(balanceB).to.equal(amountTokenB_1000);
    });

    it("Should add liquidity and calculate correct price of Token A and Token B", async function () {
      const { swapper, amountTokensA_1000 } = await loadFixture(deployTokenSale);

      const amountB = ethers.parseUnits("2000", 18);
      await swapper.addLiquidity(amountTokensA_1000, amountB);

      const priceA = await swapper.getPriceOfA(amountTokensA_1000);
      const priceB = await swapper.getPriceOfB(amountTokensA_1000);

      const calculateA = (ethers.parseUnits("2000", 18) * amountTokensA_1000) / ethers.parseUnits("1000", 18)
      const calculateB = (ethers.parseUnits("1000", 18) * amountTokensA_1000) / ethers.parseUnits("2000", 18)

      expect(priceA).to.equal(calculateA);
      expect(priceB).to.equal(calculateB);
    });

    it("Should add correct liquity after initial liquidity is provided, caluculte price, reserve and liquidity correctly", async function () {
      const { swapper, amountTokensA_1000, amountTokenB_1000 } = await loadFixture(deployTokenSale);

      // initial liquidity
      await swapper.addLiquidity(amountTokensA_1000, amountTokenB_1000);

      const totalSupplyInit = await swapper.totalSupply();

      const amountB = ethers.parseUnits("3000", 18)

      // double liquidity for A and Quadrouple for B
      await swapper.addLiquidity(amountTokensA_1000, amountB);

      const priceA = await swapper.getPriceOfA(amountTokensA_1000);
      const priceB = await swapper.getPriceOfB(amountTokenB_1000);

      const calculateA = (ethers.parseUnits("4000", 18) * amountTokensA_1000) / ethers.parseUnits("2000", 18)
      const calculateB = (ethers.parseUnits("2000", 18) * amountTokensA_1000) / ethers.parseUnits("4000", 18)

      const totalSupplyAfter = await swapper.totalSupply()

      const balanceA = await swapper.getTokenABalance();
      const balanceB = await swapper.getTokenBBalance();

      expect(balanceA).to.equal(ethers.parseUnits("2000", 18));
      expect(balanceB).to.equal(ethers.parseUnits("4000", 18));

      expect(priceA).to.equal(calculateA);
      expect(priceB).to.equal(calculateB);

      // TODO investigate error here with calucating
      // expect(totalSupplyAfter).to.equal(totalSupplyInit + ethers.parseUnits("1000"))
    });
  });


  describe("Burns correct tokens", function () {

    it("Should burn tokens and remove them from total supply", async function () {
      const { owner } = await loadFixture(deployTokenSale)
      const { swapperLiquid } = await loadFixture(deployTokenSaleWithLiquidity)

      const lpTokens = ethers.parseUnits("500", 18)
      await swapperLiquid.connect(owner).burn(lpTokens)

      const totalSupply = await swapperLiquid.totalSupply();
      const delta = ethers.parseUnits("0.000001", 18);

      expect(totalSupply).to.be.closeTo(ethers.parseUnits("500", 18), delta);
    });

    it("Should send TokenA and TokenB to the user buring", async function () {
      const { owner, tokenA, tokenB } = await loadFixture(deployTokenSale)
      const { swapperLiquid } = await loadFixture(deployTokenSaleWithLiquidity)

      const balanceABefore = await tokenA.balanceOf(owner.address)
      const balanceBBefore = await tokenB.balanceOf(owner.address)

      const lpTokens = ethers.parseUnits("500", 18)
      await swapperLiquid.connect(owner).burn(lpTokens)

      const balanceAAfter = await tokenA.balanceOf(owner.address)
      const balanceBAfter = await tokenB.balanceOf(owner.address)

      const delta = ethers.parseUnits("0.000001", 18);

      expect(balanceAAfter).to.be.closeTo(balanceABefore + ethers.parseUnits("500", 18), delta);
      expect(balanceBAfter).to.be.closeTo(balanceBBefore + ethers.parseUnits("500", 18), delta);
    });

    it("Should decrease the reserves", async function () {
      const { owner, tokenA, tokenB } = await loadFixture(deployTokenSale)
      const { swapperLiquid } = await loadFixture(deployTokenSaleWithLiquidity)

      const reservesA = await swapperLiquid.reserveTokenA();
      const reservesB = await swapperLiquid.reserveTokenB();

      const lpTokens = ethers.parseUnits("500", 18)
      await swapperLiquid.connect(owner).burn(lpTokens)

      const reservesAAfter = await swapperLiquid.reserveTokenA();
      const reservesBAfter = await swapperLiquid.reserveTokenB();

      const delta = ethers.parseUnits("0.000001", 18);

      expect(reservesAAfter).to.be.closeTo(reservesA - ethers.parseUnits("500", 18), delta);
      expect(reservesBAfter).to.be.closeTo(reservesB - ethers.parseUnits("500", 18), delta);

    });
  });

  describe("Swapps correct tokens", function () {

    // it("Should swap Token B for an exact amount of Token A", async function () {
    //   const { owner, tokenA, tokenB } = await loadFixture(deployTokenSale)
    //   const { swapperLiquid } = await loadFixture(deployTokenSaleWithLiquidity)
    //   // Specify the amount of Token A to receive
    //   const amountTokenAToReceive = ethers.parseUnits("100", 18);

    //   // Get initial balances and reserves
    //   const initialOwnerTokenABalance = await tokenA.balanceOf(owner.address);
    //   const initialOwnerTokenBBalance = await tokenB.balanceOf(owner.address);
    //   const initialReserveA = await swapperLiquid.reserveTokenA();
    //   const initialReserveB = await swapperLiquid.reserveTokenB();

    //   // Calculate required Token B to swap for exact Token A (match this calculation with your Solidity function logic)
    //   const amountTokenBRequired = (ethers.parseUnits("1000", 0) * (amountTokenAToReceive * (initialReserveB))) / (ethers.parseUnits("997", 0) * (initialReserveA - (amountTokenAToReceive)));


    //   // Perform the swap
    //   await swapperLiquid.connect(owner).swapTokenBForExactTokenA(amountTokenAToReceive);

    //   // Get final balances and reserves
    //   const finalOwnerTokenABalance = await tokenA.balanceOf(owner.address);
    //   const finalOwnerTokenBBalance = await tokenB.balanceOf(owner.address);
    //   const finalReserveA = await swapperLiquid.reserveTokenA();
    //   const finalReserveB = await swapperLiquid.reserveTokenB();

    //   // Check owner's Token A balance increased by the exact amount
    //   expect(finalOwnerTokenABalance - (initialOwnerTokenABalance)).to.equal(amountTokenAToReceive);

    //   // Check owner's Token B balance decreased by the required amount
    //   expect(initialOwnerTokenBBalance - (finalOwnerTokenBBalance)).to.equal(amountTokenBRequired);

    //   // Check reserve A decreased by the exact amount of Token A
    //   expect(initialReserveA - (finalReserveA)).to.equal(amountTokenAToReceive);

    //   // Check reserve B increased by the required amount of Token B
    //   expect(finalReserveB - (initialReserveB)).to.equal(amountTokenBRequired);
    // });
  });
});
