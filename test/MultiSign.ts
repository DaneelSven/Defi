import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("MultiSigWallet Contract", function () {
  async function deployMultiSigWallet() {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();

    const MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
    const owners = [owner.address, addr1.address, addr2.address];
    const numConfirmationsRequired = 2;
    const multiSigWallet = await MultiSigWallet.deploy(
      owners,
      numConfirmationsRequired
    );
    const contractAddress = await multiSigWallet.getAddress();
    return {
      multiSigWallet,
      owner,
      addr1,
      addr2,
      addr3,
      numConfirmationsRequired,
      contractAddress,
    };
  }

  describe("Deployment", function () {
    it("should correctly initialize the owners and the number of required confirmations", async function () {
      const { multiSigWallet, owner, addr1, addr2, numConfirmationsRequired } =
        await loadFixture(deployMultiSigWallet);

      const owners = await multiSigWallet.getOwners();
      expect(owners).to.include.members([
        owner.address,
        addr1.address,
        addr2.address,
      ]);
      expect(await multiSigWallet.numConfirmationsRequired()).to.equal(
        numConfirmationsRequired
      );
    });
  });

  describe("Transaction Submission", function () {
    it("should allow an owner to submit a transaction", async function () {
      const { multiSigWallet, addr3 } = await loadFixture(deployMultiSigWallet);
      const to = addr3.address;
      const value = ethers.parseEther("1");
      const data = "0x";

      await multiSigWallet.submitTransaction(to, value, data);
      const txCount = await multiSigWallet.getTransactionCount();

      const transaction = await multiSigWallet.getTransaction(0);
      expect(txCount).to.equal(1);
      expect(transaction.to).to.equal(to);
      expect(transaction.value).to.equal(value);
      expect(transaction.data).to.equal(data);
      expect(transaction.executed).to.equal(false);
      expect(transaction.numConfirmations).to.equal(0);
    });
  });

  describe("Transaction Confirmation", function () {
    it("should allow owners to confirm a transaction", async function () {
      const { multiSigWallet, owner, addr1, addr3 } =
        await loadFixture(deployMultiSigWallet);
      const to = addr3.address;
      const value = ethers.parseEther("1");
      const data = "0x";

      await multiSigWallet.submitTransaction(to, value, data);
      await multiSigWallet.connect(owner).confirmTransaction(0);
      await multiSigWallet.connect(addr1).confirmTransaction(0);

      const transaction = await multiSigWallet.getTransaction(0);
      expect(transaction.numConfirmations).to.equal(2);
    });
  });

  describe("Transaction Execution", function () {
    it("should execute a transaction after required confirmations", async function () {
      const { multiSigWallet, owner, addr1, addr3, contractAddress } =
        await loadFixture(deployMultiSigWallet);
      const to = addr3.address;
      const value = ethers.parseEther("1");
      const data = "0x";

      // Send ETH to the multisig wallet for the transaction
      await owner.sendTransaction({ to: contractAddress, value });

      await multiSigWallet.submitTransaction(to, value, data);
      await multiSigWallet.connect(owner).confirmTransaction(0);
      await multiSigWallet.connect(addr1).confirmTransaction(0);
      await multiSigWallet.connect(owner).executeTransaction(0);

      const transaction = await multiSigWallet.getTransaction(0);
      expect(transaction.executed).to.equal(true);
    });
  });

  describe("Transaction Revocation", function () {
    it("should allow an owner to revoke confirmation", async function () {
      const { multiSigWallet, owner, addr1, addr3 } =
        await loadFixture(deployMultiSigWallet);
      const to = addr3.address;
      const value = ethers.parseEther("1");
      const data = "0x";

      await multiSigWallet.submitTransaction(to, value, data);
      await multiSigWallet.connect(owner).confirmTransaction(0);
      await multiSigWallet.connect(addr1).confirmTransaction(0);
      await multiSigWallet.connect(owner).revokeConfirmation(0);

      const transaction = await multiSigWallet.getTransaction(0);
      expect(transaction.numConfirmations).to.equal(1);
    });
  });

  describe("Ether Handling", function () {
    it("should accept Ether deposits", async function () {
      const { multiSigWallet, owner, contractAddress } =
        await loadFixture(deployMultiSigWallet);
      const depositAmount = ethers.parseEther("1.0");

      await owner.sendTransaction({
        to: contractAddress,
        value: depositAmount,
      });

      const balance = await ethers.provider.getBalance(contractAddress);
      expect(balance).to.equal(depositAmount);
    });
  });

  // ... (previous setup and successful test cases)

  describe("MultiSigWallet Contract - Failures", function () {
    // ...

    describe("Transaction Submission Failures", function () {
      it("should not allow non-owners to submit a transaction", async function () {
        const { multiSigWallet, addr3 } =
          await loadFixture(deployMultiSigWallet);
        const to = addr3.address;
        const value = ethers.parseEther("1");
        const data = "0x";

        await expect(
          multiSigWallet.connect(addr3).submitTransaction(to, value, data)
        ).to.be.revertedWithCustomError(multiSigWallet, "notOwner");
      });
    });

    describe("Transaction Confirmation Failures", function () {
      it("should not allow non-owners to confirm a transaction", async function () {
        const { multiSigWallet, addr3 } =
          await loadFixture(deployMultiSigWallet);
        const to = addr3.address;
        const value = ethers.parseEther("1");
        const data = "0x";

        await multiSigWallet.submitTransaction(to, value, data);

        await expect(
          multiSigWallet.connect(addr3).confirmTransaction(0)
        ).to.be.revertedWithCustomError(multiSigWallet, "notOwner");
      });

      it("should not allow confirming a non-existing transaction", async function () {
        const { multiSigWallet, owner } =
          await loadFixture(deployMultiSigWallet);

        await expect(
          multiSigWallet.connect(owner).confirmTransaction(999)
        ).to.be.revertedWithCustomError(multiSigWallet, "txNotExists");
      });

      it("should not allow confirming an already confirmed transaction", async function () {
        const { multiSigWallet, owner, addr3 } =
          await loadFixture(deployMultiSigWallet);
        const to = addr3.address;
        const value = ethers.parseEther("1");
        const data = "0x";

        await multiSigWallet.submitTransaction(to, value, data);
        await multiSigWallet.connect(owner).confirmTransaction(0);

        await expect(
          multiSigWallet.connect(owner).confirmTransaction(0)
        ).to.be.revertedWithCustomError(multiSigWallet, "txAlreadyConfirmed");
      });
    });

    describe("Transaction Execution Failures", function () {
      it("should not allow executing a transaction without required confirmations", async function () {
        const { multiSigWallet, owner, addr3 } =
          await loadFixture(deployMultiSigWallet);
        const to = addr3.address;
        const value = ethers.parseEther("1");
        const data = "0x";

        await multiSigWallet.submitTransaction(to, value, data);
        await multiSigWallet.connect(owner).confirmTransaction(0);

        await expect(
          multiSigWallet.connect(owner).executeTransaction(0)
        ).to.be.revertedWithCustomError(multiSigWallet, "cannotExecuteTx");
      });

      it("should not allow non-owners to execute a transaction", async function () {
        const { multiSigWallet, addr3 } =
          await loadFixture(deployMultiSigWallet);
        const to = addr3.address;
        const value = ethers.parseEther("1");
        const data = "0x";

        await multiSigWallet.submitTransaction(to, value, data);

        await expect(
          multiSigWallet.connect(addr3).executeTransaction(0)
        ).to.be.revertedWithCustomError(multiSigWallet, "notOwner()");
      });
    });

    describe("Transaction Revocation Failures", function () {
      it("should not allow non-owners to revoke a confirmation", async function () {
        const { multiSigWallet, owner, addr3 } =
          await loadFixture(deployMultiSigWallet);
        const to = addr3.address;
        const value = ethers.parseEther("1");
        const data = "0x";

        await multiSigWallet.submitTransaction(to, value, data);
        await multiSigWallet.connect(owner).confirmTransaction(0);

        await expect(
          multiSigWallet.connect(addr3).revokeConfirmation(0)
        ).to.be.revertedWithCustomError(multiSigWallet, "notOwner");
      });

      it("should not allow revoking a confirmation for a non-existing transaction", async function () {
        const { multiSigWallet, owner } =
          await loadFixture(deployMultiSigWallet);

        await expect(
          multiSigWallet.connect(owner).revokeConfirmation(999)
        ).to.be.revertedWithCustomError(multiSigWallet, "txNotExists");
      });

      it("should not allow revoking a non-confirmed transaction", async function () {
        const { multiSigWallet, owner, addr1, addr3 } =
          await loadFixture(deployMultiSigWallet);
        const to = addr3.address;
        const value = ethers.parseEther("1");
        const data = "0x";

        await multiSigWallet.submitTransaction(to, value, data);
        await multiSigWallet.connect(owner).confirmTransaction(0);

        await expect(
          multiSigWallet.connect(addr1).revokeConfirmation(0)
        ).to.be.revertedWithCustomError(multiSigWallet, "txNotConfirmed");
      });
    });
  });
});
