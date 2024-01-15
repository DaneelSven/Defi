
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("WithdrawableContract", function () {


    async function deployRejectingContract() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();
        
        const WithDrawContract = await ethers.getContractFactory("WithdrawableContract");
        const withdrawContract = await WithDrawContract.deploy();
        const contractAddress = await withdrawContract.getAddress();

        return {
            withdrawContract,
            owner,
            otherAccount,
            contractAddress,
        };
    }

    it("should receive Ether", async function () {
        const { owner, contractAddress } = await loadFixture(deployRejectingContract);

        // Send Ether to the WithdrawableContract
        const transactionHash = await owner.sendTransaction({
            to: contractAddress,
            value: ethers.parseEther("1.0")
        });

        await expect(transactionHash).to.be.ok;

        // Check balance
        const contractBalance = await ethers.provider.getBalance(contractAddress);
        expect(ethers.formatEther(contractBalance)).to.equal("1.0");
    });

    it("should allow withdrawal of Ether", async function () {
        const {withdrawContract,  owner, contractAddress, otherAccount } = await loadFixture(deployRejectingContract);

        // Fund the contract
        await owner.sendTransaction({
            to: contractAddress,
            value: ethers.parseEther("1.0")
        });

        // Record initial balance of otherAccount
        const initialBalance = await ethers.provider.getBalance(otherAccount.address);

        // Withdraw Ether to otherAccount
        await withdrawContract.connect(otherAccount).withdraw(ethers.parseEther("0.5"));

        // Record new balance of otherAccount
        const newBalance = await ethers.provider.getBalance(otherAccount.address)

        // Check if the balance of otherAccount has increased by 0.5 Ether
        const afterBalance = initialBalance  + (ethers.parseEther("0.5"))
        const balanceDifference = afterBalance - (newBalance) 
        const acceptableRange = ethers.parseUnits("0.0001", "ether");

        expect(balanceDifference <= (acceptableRange)).to.be.true;
    });
});
