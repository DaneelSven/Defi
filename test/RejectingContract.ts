import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers, network } from "hardhat";

describe("Interaction with RejectingContract", function () {


    async function deployRejectingContract() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        const RejectingContract = await ethers.getContractFactory("RejectingContract");
        const rejectingContract = await RejectingContract.deploy();
        
        const WithDrawContract = await ethers.getContractFactory("WithdrawableContract");
        const withdrawContract = await WithDrawContract.deploy();
        const contractAddress = await withdrawContract.getAddress();

        // Fund YourContract with some Ether
        await owner.sendTransaction({
            to: contractAddress,
            value: ethers.parseEther("1.0"), // Sending 1 Ether
        });


        await network.provider.send("evm_increaseTime", [60]);
        await network.provider.send("evm_mine");

        return {
            rejectingContract,
            owner,
            otherAccount,
            contractAddress,
        };
    }

    it("should fail to withdraw due to rejection of Ether transfer", async function () {
        const { rejectingContract, contractAddress } = await loadFixture(deployRejectingContract);

        const withdrawAmount = ethers.parseEther("0.5");

        // Expect the withdraw call to fail when called through RejectingContract
        await expect(rejectingContract.testWithdraw(contractAddress, withdrawAmount))
            .to.be.revertedWith("FailedTransaction");
    });
});
