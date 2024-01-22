import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { ContractRunner, parseUnits } from "ethers";

describe("TokenSale", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployTokenSale() {
    const intialSupply = 1000;
    const maxSupply = ethers.parseUnits("100000", 18);

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const TokenSale = await ethers.getContractFactory("TokenSale");
    const tokenSale = await TokenSale.deploy(owner, intialSupply, maxSupply, {
      value: ethers.parseEther("100"),  
    });
    const contractAddress = await tokenSale.getAddress();
    const ownerBalanceWei = await tokenSale.balanceOf(owner);
    
    // Deploy a contract that rejects ether
    const RejectingContract = await ethers.getContractFactory("RejectingContract");
    const rejectingContract = await RejectingContract.deploy() as unknown as ContractRunner;


    return {
      tokenSale,
      rejectingContract,
      intialSupply,
      maxSupply,
      owner,
      otherAccount,
      contractAddress,
      ownerBalanceWei,
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { tokenSale, owner } = await loadFixture(deployTokenSale);

      expect(await tokenSale.owner()).to.equal(owner.address);
    });

    it("Should set the right max supply", async function () {
      const { tokenSale, maxSupply } = await loadFixture(deployTokenSale);

      expect(await tokenSale.cap()).to.equal(maxSupply);
    });

    it("Should set the right initial supply to the owner and contract balance", async function () {
      const { tokenSale } = await loadFixture(deployTokenSale);
      const totalSupply = await tokenSale.totalSupply();

      expect(totalSupply).to.equal(ethers.parseUnits("2000", 18));
    });
  });

  describe("mintTokensToAddress", function () {
    it("Should revert with InvalidValue if eth send is not equal to 1", async function () {
      const { tokenSale, owner } = await loadFixture(deployTokenSale);

      await expect(
        tokenSale
          .connect(owner)
          .mintTokensToAddress({ value: ethers.parseEther("10") })
      ).to.be.revertedWithCustomError(tokenSale, "InvalidValue");
    });

    it("Should transfer tokens if the Contract has the tokens", async function () {
      const { tokenSale, owner } = await loadFixture(deployTokenSale);

      const tokenBalanceBefore = await tokenSale.balanceOf(owner);

      await tokenSale
        .connect(owner)
        .mintTokensToAddress({ value: ethers.parseEther("1") });

      const tokenBalanceAfter = await tokenSale.balanceOf(owner);

      expect(tokenBalanceAfter).to.equal(
        tokenBalanceBefore + ethers.parseUnits("1000", 18)
      );
    });

    it("Should mint tokens if the Contract does not have the tokens", async function () {
      const { tokenSale, owner, otherAccount, contractAddress } =
        await loadFixture(deployTokenSale);

      const tokenBalanceBefore = await tokenSale.balanceOf(contractAddress);

      // trigger case where balance does not have enough tokens
      await tokenSale
        .connect(owner)
        .transferTokensOut(otherAccount, ethers.parseUnits("500", 18));

      await tokenSale
        .connect(owner)
        .mintTokensToAddress({ value: ethers.parseEther("1") });

      const tokenBalanceAfter = await tokenSale.balanceOf(owner);

      expect(tokenBalanceAfter).to.equal(
        tokenBalanceBefore + ethers.parseUnits("1000", 18)
      );
    });
  });

  describe("Partial Refund", function () {
    describe("Validations", function () {
      it("Should revert with NoToken() custom error if amount is lower or equal to 0", async function () {
        const { tokenSale } = await loadFixture(deployTokenSale);
        const nullAmount = ethers.parseUnits("0", 18);

        await expect(
          tokenSale.sellBack(nullAmount)
        ).to.be.revertedWithCustomError(tokenSale, "NoTokens");
      });

      it("Should revert with Exceed max supply customer error if amount will result in too high max supply", async function () {
        const { tokenSale, contractAddress, owner, ownerBalanceWei } =
          await loadFixture(deployTokenSale);

        const contractBalanceWei = await tokenSale.balanceOf(contractAddress);
        const amountTokens =
          contractBalanceWei + ethers.parseUnits("1000000000", 18);

        await expect(
          tokenSale.sellBack(amountTokens)
        ).to.be.revertedWithCustomError(tokenSale, "ERC20ExceededCap");
      });
    });

    describe("Transfer and Mint", function () {
      it("Should transfer tokens if the Contract has the requested amount", async function () {
        const { tokenSale, owner, ownerBalanceWei, contractAddress } =
          await loadFixture(deployTokenSale);

        const contractBalanceBeforeWei =
          await tokenSale.balanceOf(contractAddress);

        const amount = contractBalanceBeforeWei - ethers.parseUnits("1", 18);
        await tokenSale.connect(owner).sellBack(amount);

        const ownerBalanceAfter = await tokenSale.balanceOf(owner);
        const contractBalanceAfter = await tokenSale.balanceOf(contractAddress);

        expect(ownerBalanceAfter).to.equal(ownerBalanceWei - amount);
        expect(contractBalanceAfter).to.equal(
          contractBalanceBeforeWei + amount
        );
      });

      it("Should mint the tokens to the caller if Contract does not have the funds", async function () {
        const { tokenSale, contractAddress, owner } =
          await loadFixture(deployTokenSale);

        const contractBalanceWei = await tokenSale.balanceOf(contractAddress);
        const amountTokens = contractBalanceWei + ethers.parseUnits("1", 18);

        const totalSupplyBefore = await tokenSale.totalSupply();
        await tokenSale.connect(owner).sellBack(amountTokens);

        const totalSupplyAfter = await tokenSale.totalSupply();

        expect(totalSupplyAfter).to.equal(totalSupplyBefore + amountTokens);
      });

      it("Should send the correct Ether amount based on token amount input", async function () {
        const { tokenSale, owner, contractAddress } =
          await loadFixture(deployTokenSale);

        const tokensPerEth = ethers.parseUnits("2000", 18);
        const contractBalanceEth =
          await ethers.provider.getBalance(contractAddress);

        const contractBalance = await tokenSale.balanceOf(contractAddress);

        await tokenSale.connect(owner).sellBack(contractBalance);
        const etherAmount =
          (contractBalance * parseUnits("1", 18)) / tokensPerEth;
        const contractBalanceEtAfter =
          await ethers.provider.getBalance(contractAddress);

        expect(contractBalanceEtAfter).to.equal(
          contractBalanceEth - etherAmount
        );
      });
    });

    describe("Events", function () {
      it("Should emit an event on withdrawals", async function () {
        const { tokenSale, owner } = await loadFixture(deployTokenSale);
        const withdrawAmount = ethers.parseUnits("1", 18);

        await expect(tokenSale.connect(owner).withdraw(withdrawAmount)).to.emit(
          tokenSale,
          "EtherWithdrawn"
        );
      });

      it("Should emit custom error if amount is less than balance ", async function () {
        const { tokenSale, owner } = await loadFixture(deployTokenSale);
        const withdrawAmount = ethers.parseUnits("1000", 18);

        expect(tokenSale.connect(owner).withdraw(withdrawAmount)).to.emit(
          tokenSale,
          "LowContractBalance"
        );
      });

      it("Should emit an event on opening Sale", async function () {
        const { tokenSale, owner } = await loadFixture(deployTokenSale);
        await tokenSale.connect(owner).closeSale();

        await expect(tokenSale.connect(owner).openSale()).to.emit(
          tokenSale,
          "OpenSale"
        );
      });

      it("Should emit an event on closing the Sale", async function () {
        const { tokenSale, owner } = await loadFixture(deployTokenSale);

        await expect(tokenSale.connect(owner).closeSale()).to.emit(
          tokenSale,
          "ClosingSale"
        );
      });

      it("Should emit an event on ether received", async function () {
        const { tokenSale, owner, contractAddress } =
          await loadFixture(deployTokenSale);

        await owner.sendTransaction({
          to: contractAddress,
          value: ethers.parseEther("1"),
        });

        await expect(
          owner.sendTransaction({
            to: contractAddress,
            value: ethers.parseEther("1"),
          })
        ).to.emit(tokenSale, "EtherReceived");
      });
    });
  });
});
