import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("TokenA Contract", function () {

    async function deployToken() {
        // Contracts are deployed using the first signer/account by default
        const [owner, addr1, addr2] = await ethers.getSigners();
    
        const TokenB = await ethers.getContractFactory("TokenB");
        const tokenB= await TokenB.deploy();
        const tokenAddress = await tokenB.getAddress();
    

    
        return {
          tokenB,
          tokenAddress,
          owner,
          addr1,
          addr2,
        
        };
      }
    
    describe("Deployment", function () {
        it("should assign the total supply of tokens to the owner", async function () {
            const { tokenB, owner } = await loadFixture(deployToken);

            const ownerBalance = await tokenB.balanceOf(owner.address);
            expect(await tokenB.totalSupply()).to.equal(ownerBalance);
        });

        it("should have correct initial supply of 10000 tokens", async function () {
            const { tokenB } = await loadFixture(deployToken);

            const expectedSupply = ethers.parseUnits("10000", 18);
            expect(await tokenB.totalSupply()).to.equal(expectedSupply);
        });
    });

    describe("Minting Tokens", function () {
        it("should mint tokens correctly", async function () {
            const { tokenB, addr1 } = await loadFixture(deployToken);

            const mintAmount = ethers.parseUnits("500", 18);
            await tokenB.mint(addr1.address, mintAmount);

            const addr1Balance = await tokenB.balanceOf(addr1.address);
            expect(addr1Balance).to.equal(mintAmount);

            const totalSupplyAfterMint = await tokenB.totalSupply();
            const expectedTotalSupply = ethers.parseUnits("10500", 18);
            expect(totalSupplyAfterMint).to.equal(expectedTotalSupply);
        });
    });
});
