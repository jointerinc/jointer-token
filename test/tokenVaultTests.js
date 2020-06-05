const {
  constants,
  expectEvent,
  expectRevert,
  BN,
} = require("@openzeppelin/test-helpers");

const {ZERO_ADDRESS} = constants;

const {expect} = require("chai");

const TokenVault = artifacts.require("TokenVault");
const TokenVaultRegistry = artifacts.require("TokenVaultRegistery");
const AuctionRegisty = artifacts.require("TestAuctionRegistery");
const TestERC20 = artifacts.require("TestERC20");

contract("~Token vault works", function (accounts) {
  const [
    primaryOwner,
    systemAddress,
    testTokenHolder,
    multiSigPlaceHolder,
    auctionProtectionPlaceHolder,
    spender,
    other1,
  ] = accounts;

  const startingAmount = new BN(20);
  const transferringAmount = new BN(10);

  beforeEach(async function () {
    this.auctionRegistry = await AuctionRegisty.new(
      systemAddress,
      multiSigPlaceHolder,
      {from: primaryOwner}
    );
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("AUCTION_PROTECTION"),
      auctionProtectionPlaceHolder,
      {
        from: primaryOwner,
      }
    );
    var tokenVaultRegistry = await TokenVaultRegistry.new(
      systemAddress,
      multiSigPlaceHolder,
      {from: primaryOwner}
    );
    let tempTokenVault = await TokenVault.new();
    await tokenVaultRegistry.addVersion(1, tempTokenVault.address);
    await tokenVaultRegistry.createProxy(
      1,
      primaryOwner,
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      {from: primaryOwner}
    );
    let proxyAddress = await tokenVaultRegistry.proxyAddress();
    this.tokenVault = await TokenVault.at(proxyAddress);

    this.erc20 = await TestERC20.new();
    await this.erc20.mint(testTokenHolder, startingAmount, {
      from: testTokenHolder,
    });
  });
  it("should initialize correctly", async function () {
    expect(await this.tokenVault.systemAddress()).to.equal(systemAddress);
    expect(await this.tokenVault.primaryOwner()).to.equal(primaryOwner);
    expect(await this.tokenVault.authorityAddress()).to.equal(
      multiSigPlaceHolder
    );
    expect(await this.tokenVault.contractsRegistry()).to.equal(
      this.auctionRegistry.address
    );
    expect(await this.tokenVault.auctionProtectionAddress()).to.equal(
      auctionProtectionPlaceHolder
    );
  });
  it("should accept eth correctly", async function () {
    let receipt = await this.tokenVault.sendTransaction({
      from: other1,
      value: transferringAmount,
    });
    expectEvent(receipt, "FundDeposited", {
      _token: ZERO_ADDRESS,
      _from: other1,
      _amount: transferringAmount,
    });
  });
  it("should deposit token correctly", async function () {
    //should throw if tokens were not approved
    //unsoecified becuase it is likely that error would of underflow from testERC20 and not from ensureTransferFrom
    await expectRevert.unspecified(
      this.tokenVault.depositeToken(
        this.erc20.address,
        testTokenHolder,
        transferringAmount,
        {from: testTokenHolder}
      )
    );
    await this.erc20.approve(this.tokenVault.address, transferringAmount, {
      from: testTokenHolder,
    });
    let receipt = await this.tokenVault.depositeToken(
      this.erc20.address,
      testTokenHolder,
      transferringAmount,
      {from: testTokenHolder}
    );
    expectEvent(receipt, "FundDeposited", {
      _token: this.erc20.address,
      _from: testTokenHolder,
      _amount: transferringAmount,
    });
  });
  it("should add spender correctly", async function () {
    await expectRevert(
      this.tokenVault.addSpender(spender, {from: other1}),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    let receipt = await this.tokenVault.addSpender(spender, {
      from: multiSigPlaceHolder,
    });
    expectEvent(receipt, "TokenSpenderAdded", {_which: spender});

    expect(await this.tokenVault.isSpender(spender)).to.be.equal(true);
    await expectRevert(
      this.tokenVault.addSpender(spender, {from: multiSigPlaceHolder}),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
  });
  it("should remove spender correctly", async function () {
    await this.tokenVault.addSpender(spender, {
      from: multiSigPlaceHolder,
    });
    //if called by other1
    await expectRevert(
      this.tokenVault.removeSpender(spender, {from: other1}),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    //if not a spender already
    await expectRevert(
      this.tokenVault.removeSpender(other1, {from: multiSigPlaceHolder}),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    let receipt = await this.tokenVault.removeSpender(spender, {
      from: multiSigPlaceHolder,
    });
    expectEvent(receipt, "TokenSpenderRemoved", {_which: spender});

    expect(await this.tokenVault.isSpender(spender)).to.be.equal(false);
  });
  it("should transfer tokens correctly", async function () {
    await this.tokenVault.addSpender(spender, {
      from: multiSigPlaceHolder,
    });
    //throw if insufficient funds
    await expectRevert.unspecified(
      this.tokenVault.directTransfer(
        this.erc20.address,
        other1,
        transferringAmount,
        {from: spender}
      )
    );
    await this.erc20.transfer(this.tokenVault.address, transferringAmount, {
      from: testTokenHolder,
    });
    //throw if not one of spenders address
    await expectRevert(
      this.tokenVault.directTransfer(
        this.erc20.address,
        other1,
        transferringAmount,
        {from: other1}
      ),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );

    let receipt = await this.tokenVault.directTransfer(
      this.erc20.address,
      other1,
      transferringAmount,
      {from: spender}
    );
    expectEvent(receipt, "FundTransfer", {
      _by: spender,
      _to: other1,
      _token: this.erc20.address,
      amount: transferringAmount,
    });
  });
  it("should transfer eth correctly", async function () {
    await this.tokenVault.addSpender(spender, {
      from: multiSigPlaceHolder,
    });
    //throw if insufficient funds
    await expectRevert.unspecified(
      this.tokenVault.transferEther(other1, transferringAmount, {from: spender})
    );
    await this.tokenVault.sendTransaction({
      from: other1,
      value: transferringAmount,
    });
    //throw if not one of spenders address
    await expectRevert(
      this.tokenVault.transferEther(other1, transferringAmount, {from: other1}),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );

    let receipt = await this.tokenVault.transferEther(
      other1,
      transferringAmount,
      {from: spender}
    );
    expectEvent(receipt, "FundTransfer", {
      _by: spender,
      _to: other1,
      _token: ZERO_ADDRESS,
      amount: transferringAmount,
    });
  });
  //choosing to not test remaining one line methods
});
