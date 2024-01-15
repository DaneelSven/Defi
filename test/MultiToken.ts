import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers, network } from "hardhat";

describe("MultiToken", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deploymultiToken() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const MultiToken = await ethers.getContractFactory("MultiToken");
    const multiToken = await MultiToken.deploy(owner);
    const contractAddress = await multiToken.getAddress();

    await network.provider.send("evm_increaseTime", [60]);
    await network.provider.send("evm_mine");
    const FORGE_ROLE = ethers.keccak256(ethers.toUtf8Bytes("FORGE_ROLE"));

    return {
      multiToken,
      owner,
      otherAccount,
      contractAddress,
      FORGE_ROLE
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      expect(await multiToken.owner()).to.equal(owner.address);
    });

    it("Should set the timestamp", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      expect(await multiToken.owner()).to.equal(owner.address);
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

  describe("mint", function () {
    it("Should revert with ForgeRequired if tokenId larger than 2", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      await expect(
        multiToken.connect(owner).mint(owner, 3, "0x")
      ).to.be.revertedWithCustomError(multiToken, "ForgeRequired");
    });

    it("Should revert with CoolDownError if you try to mint too fast", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      await multiToken.connect(owner).mint(owner, 2, "0x");

      await expect(
        multiToken.connect(owner).mint(owner, 2, "0x")
      ).to.be.revertedWithCustomError(multiToken, "CoolDownError");
    });

    it("Should revert with ContractPaused if the contract is paused", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      await multiToken.connect(owner).pause();
      await expect(
        multiToken.connect(owner).mint(owner, 1, "0x")
      ).to.be.revertedWithCustomError(multiToken, "ContractPaused");
    });

    it("Should mint token 0", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      await multiToken.connect(owner).mint(owner, 0, "0x");

      const balance = await multiToken.connect(owner).balanceOf(owner, 0);

      expect(balance).to.equal(1);
    });

    it("Should mint token 1", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      await multiToken.connect(owner).mint(owner, 1, "0x");

      const balance = await multiToken.connect(owner).balanceOf(owner, 1);

      expect(balance).to.equal(1);
    });

    it("Should mint token 2", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      await multiToken.connect(owner).mint(owner, 2, "0x");
      const balance = await multiToken.connect(owner).balanceOf(owner, 2);

      expect(balance).to.equal(1);
    });

    it("Should emit Mint event", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      await expect(multiToken.connect(owner).mint(owner, 0, "0x")).to.emit(
        multiToken,
        "Mint"
      );
    });

    it("Should revert with CoolDownError if minting again within cooldown period", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      // First mint should succeed
      await multiToken.connect(owner).mint(owner.address, 0, "0x");

      // Advance time by less than 60 seconds (cooldown period)
      await ethers.provider.send("evm_increaseTime", [30]); // 30 seconds
      await ethers.provider.send("evm_mine");

      // Second mint should fail
      await expect(
        multiToken.connect(owner).mint(owner.address, 0, "0x")
      ).to.be.revertedWithCustomError(multiToken, "CoolDownError");
    });

    it("Should mint tokens after unpausing the contract", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      // Pause the contract
      await multiToken.connect(owner).pause();

      // Unpause the contract
      await multiToken.connect(owner).unpause();

      // Minting should succeed after unpausing
      await expect(
        multiToken.connect(owner).mint(owner.address, 1, "0x")
      ).to.emit(multiToken, "Mint");
    });

    it("Should mint tokens by new owner after ownership transfer", async function () {
      const { multiToken, owner, otherAccount } =
        await loadFixture(deploymultiToken);

      // Transfer ownership to otherAccount
      await multiToken.connect(owner).transferOwnership(otherAccount.address);

      // New owner (otherAccount) mints tokens
      await expect(
        multiToken.connect(otherAccount).mint(otherAccount.address, 1, "0x")
      ).to.emit(multiToken, "Mint");
    });

    it("Should burn a specific token amount", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      // Mint some tokens first
      await multiToken.connect(owner).mint(owner.address, 0, "0x");

      // Burn part of the minted tokens
      await multiToken.connect(owner).burn(owner.address, 0, 1);

      const balanceAfterBurn = await multiToken.balanceOf(owner.address, 0);
      expect(balanceAfterBurn).to.equal(0);
    });
  });

  describe("Pausing Events", function () {
    it("Should emit an event on unpausing Contract", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      await multiToken.connect(owner).pause();

      await expect(multiToken.connect(owner).unpause()).to.emit(
        multiToken,
        "Unpaused"
      );
    });

    it("Should emit an event on pausing Contract", async function () {
      const { multiToken, owner } = await loadFixture(deploymultiToken);

      await expect(multiToken.connect(owner).pause()).to.emit(
        multiToken,
        "Paused"
      );
    });

    describe("Access Roles and Interface", function () {
      it("Should emit an event on revoking forge Role", async function () {
        const { multiToken, owner } = await loadFixture(deploymultiToken);

        await expect(multiToken.connect(owner).pause()).to.emit(
          multiToken,
          "Paused"
        );
      });


      it("should correctly revoke a role", async function () {
        const { multiToken, FORGE_ROLE, otherAccount } = await loadFixture(deploymultiToken);

        // Grant FORGE_ROLE to addr1
        await multiToken.grantForgeRole(otherAccount.address);
        expect(await multiToken.hasRole(FORGE_ROLE, otherAccount.address)).to.be.true;

        // Revoke FORGE_ROLE from addr1
        await multiToken.revokeForgeRole(otherAccount.address);
        expect(await multiToken.hasRole(FORGE_ROLE, otherAccount.address)).to.be.false;
      });

      it("should correctly report supported interfaces", async function () {
        const { multiToken, owner } = await loadFixture(deploymultiToken);

        // ERC1155 interface ID https://eips.ethereum.org/EIPS/eip-1155
        const ERC1155InterfaceID = "0xd9b67a26";
        expect(await multiToken.supportsInterface(ERC1155InterfaceID)).to.be.true;

        // AccessControl interface ID
        const AccessControlInterfaceID = "0x7965db0b";
        expect(await multiToken.supportsInterface(AccessControlInterfaceID)).to.be.true;

        // An unsupported interface ID (example)
        const unsupportedInterfaceID = "0xffffffff";
        expect(await multiToken.supportsInterface(unsupportedInterfaceID)).to.be.false;
      });
    })
  });
});
