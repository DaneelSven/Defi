import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers, network } from "hardhat";

describe("Forging", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deploymultiToken() {
    // Contracts are deployed using the first signer/account by default
    const [owner, addr1, addr2] = await ethers.getSigners();

    const MultiToken = await ethers.getContractFactory("MultiToken");
    const multiToken = await MultiToken.deploy(owner);
    const multiTokenAddress = await multiToken.getAddress();

    const Forging = await ethers.getContractFactory("Forging");
    const forging = await Forging.deploy(owner, multiTokenAddress);
    await increaseTime(60);

    await forging.connect(owner).mintTokens(0);
    await increaseTime(60);

    await forging.connect(owner).mintTokens(1);
    await increaseTime(60);

    await forging.connect(owner).mintTokens(2);
    await increaseTime(60);

    await multiToken
      .connect(owner)
      .setApprovalForAll(await forging.getAddress(), true);

    await forging.connect(addr1).mintTokens(0);
    await increaseTime(60);

    await forging.connect(addr1).mintTokens(1);
    await increaseTime(60);

    await forging.connect(addr1).mintTokens(2);
    await increaseTime(60);

    await multiToken
      .connect(addr1)
      .setApprovalForAll(await forging.getAddress(), true);

    // allow multitoken to call forging functionality
    await multiToken.connect(owner).grantForgeRole(forging.getAddress());

    // TODO add second forging contract and try to forge tokens from someone which is not authroized to call forge functionality

    return {
      multiToken,
      owner,
      addr1,
      addr2,
      multiTokenAddress,
      forging,
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { forging, owner } = await loadFixture(deploymultiToken);

      expect(await forging.owner()).to.equal(owner.address);
    });
  });

  describe("URI", function () {
    it("Should set the the uri", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      await multiToken.connect(owner).setURI("ipfs://test");
      const uri = await multiToken.connect(owner).getURI();

      expect(uri).to.be.a("string");
      expect(uri).to.include("ipfs://test");
    });
  });

  describe("Forge Access", function () {
    it("Should emit Forge request", async function () {
      const { forging, owner } = await loadFixture(deploymultiToken);

      await forging.connect(owner).requestForgeAccess();
      await expect(forging.connect(owner).requestForgeAccess()).to.emit(
        forging,
        "RequestForgeAccess"
      );
    });
  });

  describe("mintTokens", function () {
    it("Should revert with ForgeRequired if tokenId larger than 2", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      await expect(
        multiToken.connect(owner).mint(owner, 3, "0x")
      ).to.be.revertedWithCustomError(multiToken, "ForgeRequired");
    });
  });

  describe("forgeToken", function () {
    it("Should forge token id 3", async function () {
      const { forging, owner } = await loadFixture(deploymultiToken);

      await expect(forging.connect(owner).forgeToken(3)).to.emit(
        forging,
        "Forge"
      );
    });

    it("Should forge token id 4", async function () {
      const { forging, owner } = await loadFixture(deploymultiToken);

      await expect(forging.connect(owner).forgeToken(4)).to.emit(
        forging,
        "Forge"
      );
    });

    it("Should forge token id 5", async function () {
      const { forging, owner } = await loadFixture(deploymultiToken);

      await expect(forging.connect(owner).forgeToken(5)).to.emit(
        forging,
        "Forge"
      );
    });

    it("Should forge token id 6", async function () {
      const { forging, owner } = await loadFixture(deploymultiToken);

      await expect(forging.connect(owner).forgeToken(6)).to.emit(
        forging,
        "Forge"
      );
    });

    it("Should revert with InsufficientTokensBurn", async function () {
      const { forging, addr2 } = await loadFixture(deploymultiToken);

      await expect(
        forging.connect(addr2).forgeToken(6)
      ).to.be.revertedWithCustomError(forging, "InsufficientTokensBurn");
    });

    it("Should revert with InvalidForgeId", async function () {
      const { forging, addr1 } = await loadFixture(deploymultiToken);

      await expect(
        forging.connect(addr1).forgeToken(7)
      ).to.be.revertedWithCustomError(forging, "InvalidForgeId");
    });
  });

  describe("trade", function () {
    it("Should trade tokens successfully", async function () {
      const { forging, addr1 } = await loadFixture(deploymultiToken);

      await expect(forging.connect(addr1).trade(1, 0))
        .to.emit(forging, "Trade")
        .withArgs(1, 0, 1);
    });

    it("Should revert with InvalidElement", async function () {
      const { forging, addr1 } = await loadFixture(deploymultiToken);

      await expect(
        forging.connect(addr1).trade(3, 0)
      ).to.be.revertedWithCustomError(forging, "InvalidElement");
    });

    it("Should revert with InsufficientTokensBurn for insufficient tokens", async function () {
      const { forging, addr2 } = await loadFixture(deploymultiToken);

      await expect(
        forging.connect(addr2).trade(0, 1)
      ).to.be.revertedWithCustomError(forging, "InsufficientTokensBurn");
    });

    it("Should revert with InsufficientTokensBurn for insufficient tokens", async function () {
      const { forging, addr2 } = await loadFixture(deploymultiToken);

      await forging.connect(addr2).mintTokens(1);

      await expect(
        forging.connect(addr2).trade(0, 1)
      ).to.be.revertedWithCustomError(forging, "InsufficientTokensBurn");
    });
  });

  describe("mintTokens", async function () {
    const { multiToken, forging, owner, addr1 } =
      await loadFixture(deploymultiToken);

    it("Should allow the owner to mint tokens", async function () {
      await expect(forging.connect(owner).mintTokens(0)).to.emit(
        multiToken,
        "Mint"
      );
    });

    it("Should prevent non-owners from minting tokens", async function () {
      await expect(forging.connect(addr1).mintTokens(0)).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });
  });
});

async function increaseTime(increaseTime: number) {
  await network.provider.send("evm_increaseTime", [increaseTime]);
  await network.provider.send("evm_mine");
}
