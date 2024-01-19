import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ContractTransactionReceipt, LogDescription } from "ethers";
import { ethers } from "hardhat";



describe("Minimal Proxy Factory Contract", function () {
  // and reset Hardhat Network to that snapshot in every test.
  async function deployMpFactory() {
    // Contracts are deployed using the first signer/account by default
    const [owner, addr1, addr2] = await ethers.getSigners();

    const MasterContract = await ethers.getContractFactory("MasterContract");
    const masterContract = await MasterContract.deploy();
    const masterContractAddress = await masterContract.getAddress();


    const Factory = await ethers.getContractFactory("MinimalProxyFactory");
    const factory = await Factory.deploy(masterContractAddress);
    const factoryAddress = await factory.getAddress();

    return {
      masterContract,
      factory,
      owner,
      addr1,
      addr2,
      masterContractAddress,
      factoryAddress,
    };
  }

  describe("Deployment", function () {
    it("Should track each deployed MyContract", async function () {
      const { factory } = await loadFixture(deployMpFactory);

      const tx = await factory.deployProxy(ethers.id("my_salt_1"));
      const receipt = await tx. wait() as ContractTransactionReceipt


    // Check for the ProxyDeployed event in the transaction receipt logs
    const event = receipt.logs.map(log => {
        try {
            // @ts-ignore
            return factory.interface.parseLog(log);
        } catch (error) {
            return null;
        }
    }).find(log => log && log.name === 'ProxyDeployed') as LogDescription

    expect(event).to.not.be.undefined;    
    const proxyAddress = event.args.proxyAddress;

      // Check if the deployed proxy's address matches the expected address.
      expect(await factory.getAllDeployedProxies()).to.include(proxyAddress);
    });

    // it("Should set and get data through the proxy", async function () {
    //     const { factory, masterContract } = await loadFixture(deployMpFactory);

    //     // Deploy a new minimal proxy for the MasterContract
    //     const salt = ethers.id("unique_salt");
    //     const tx = await factory.deployProxy(salt);
    //     const receipt = await tx.wait();
    //     //@ts-ignore
    //     const event = receipt.logs.map(log => factory.interface.parseLog(log)).find(log => log.name === 'ProxyDeployed');
    //     const proxyAddress = event!.args.proxyAddress;

    //     // Get the contract at the proxy's address
    //     const proxyContract = await ethers.getContractAt("MasterContract", proxyAddress);

    //     // Set data through the proxy
    //     const setDataTx = await proxyContract.setData(123);
    //     await setDataTx.wait();
        
    //     // Get data through the proxy
    //     const data = await proxyContract.getData();
        
    //     // Verify the data was correctly set and retrieved
    //     expect(data).to.equal(123);
    // });

  });

  describe("getCreate2Addresses", function () {
    it("Should return the correct address", async function () {
      const { factory, owner, masterContractAddress } =
        await loadFixture(deployMpFactory);

      const salt = ethers.id("my_salt_2");
      const proxyBytecode =
        "0x3d602d80600a3d3981f3363d3d373d3d3d363d73" +
        masterContractAddress.slice(2) +
        "5af43d82803e903d91602b57fd5bf3";

      const expectedAddress = await factory.getCreate2Address(
        proxyBytecode,
        salt
      );

      // Deploy a new minimal proxy
      await factory.deployProxy(salt);

      // Check if the computed address matches the expected address.
      expect(await factory.getCreate2Address(proxyBytecode, salt)).to.equal(
        expectedAddress
      );
    });
  });

  describe("getDeployedContracts", function () {
    it("Should return all deployed proxy instances", async function () {
      const { factory, owner, masterContractAddress } =
        await loadFixture(deployMpFactory);

      // Deploy multiple minimal proxies
      const salt1 = ethers.id("my_salt_3");
      const salt2 = ethers.id("my_salt_4");
      await factory.deployProxy(salt1);
      await factory.deployProxy(salt2);

      // Check if the deployedProxies array contains the expected number of contracts.
      expect((await factory.getAllDeployedProxies()).length).to.equal(2);
    });
  });
});
