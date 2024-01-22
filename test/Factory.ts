import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers, network } from "hardhat";

describe("Factory and MyContract", function () {
    async function deployFactoryAndMyContract() {
        const [owner, addr1] = await ethers.getSigners();

        const MyContract = await ethers.getContractFactory("MyContract");
        const Factory = await ethers.getContractFactory("Factory");
        const factory = await Factory.deploy();

        return {
            MyContract,
            factory,
            owner,
            addr1
        };
    }

    describe("Factory Deployment", function () {
        it("Should deploy MyContract instances", async function () {
            const { MyContract, factory, owner } = await loadFixture(deployFactoryAndMyContract);
            const salt = ethers.id("unique_salt_1");
            await factory.createMyContract(salt);

            const deployedContracts = await factory.getDeployedContracts();
            expect(deployedContracts.length).to.equal(1);
        });

        it("Should compute the correct address for the new contract", async function () {
            const { MyContract, factory, owner } = await loadFixture(deployFactoryAndMyContract);
            const salt = ethers.id("unique_salt_2");
            const bytecode = await factory.getBytecode(owner.address);
            const computedAddress = await factory.getAddress(bytecode, salt);
            
            await factory.createMyContract(salt);
            const deployedContracts = await factory.getDeployedContracts();
            
            expect(deployedContracts[0]).to.equal(computedAddress);
        });
    });

    describe("MyContract Functionality", function () {
        it("Should set and get data correctly", async function () {

        });
    });

    describe("Factory Contract Ether Handling", function () {
        it("Should accept and emit event on Ether receive", async function () {
            const { factory, owner } = await loadFixture(deployFactoryAndMyContract);
            const depositAmount = ethers.parseEther("1.0");

            // await expect(owner.sendTransaction({
            //     to: factory.address,
            //     value: depositAmount
            // })).to.emit(factory, 'Received').withArgs(owner.address, depositAmount);

            // const balance = await ethers.provider.getBalance(factory.address);
            // expect(balance).to.equal(depositAmount);
        });
    });

});

