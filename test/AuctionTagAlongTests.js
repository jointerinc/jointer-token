const {
  constants,
  expectEvent,
  expectRevert,
  BN,
} = require("@openzeppelin/test-helpers");
const { ZERO_ADDRESS } = constants;

const { expect } = require("chai");

const TagAlong = artifacts.require("AuctionTagAlong");
const TagAlongRegistry = artifacts.require("TagAlongRegistry");
const AuctionRegisty = artifacts.require("TestAuctionRegistery");
const ERC20 = artifacts.require("TestERC20");

contract("~auction tag Along works", function (accounts) {
  const [
    other1,
    primaryOwner,
    systemAddress,
    multiSigPlaceHolder,
    liquidityPlaceHolder,
    contributer1,
  ] = accounts;
  const contributeAmount = new BN(1000);
  beforeEach(async function () {
    //contract that has address of all the contracts
    this.auctionRegistry = await AuctionRegisty.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("LIQUADITY"),
      liquidityPlaceHolder,
      { from: primaryOwner }
    );

    var tagAlongRegistry = await TagAlongRegistry.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    let tempTagAlong = await TagAlong.new({ from: primaryOwner });
    await tagAlongRegistry.addVersion(1, tempTagAlong.address, {
      from: primaryOwner,
    });
    await tagAlongRegistry.createProxy(
      1,
      primaryOwner,
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      { from: primaryOwner }
    );
    proxyAddress = await tagAlongRegistry.proxyAddress();
    this.tagAlong = await TagAlong.at(proxyAddress);

    this.erc20 = await ERC20.new({ from: other1 });
    this.erc20.mint(contributer1, contributeAmount, { from: contributer1 });
  });
  it("should initialize correctly", async function () {
    expect(await this.tagAlong.systemAddress()).to.equal(systemAddress);
    expect(await this.tagAlong.primaryOwner()).to.equal(primaryOwner);
    expect(await this.tagAlong.authorityAddress()).to.equal(
      multiSigPlaceHolder
    );
    expect(await this.tagAlong.contractsRegistry()).to.equal(
      this.auctionRegistry.address
    );
    expect(await this.tagAlong.liquadityAddress()).to.equal(
      liquidityPlaceHolder
    );
    // expect(await this.tagAlong.liquadityRatio()).to.be.bignumber.equal("100");
    // expect(await this.tagAlong.contributionRatio()).to.be.bignumber.equal(
    //   "100"
    // );
  });
  describe("All the functions", async function () {
    //maybe first test the depositToken and then other functions
    it("should deposite token correctly", async function () {
      await this.erc20.approve(this.tagAlong.address, contributeAmount, {
        from: contributer1,
      });
      let reciept = await this.tagAlong.depositeToken(
        this.erc20.address,
        contributer1,
        contributeAmount,
        {
          from: contributer1,
        }
      );
      expectEvent(reciept, "FundDeposited", {
        _token: this.erc20.address,
        _from: contributer1,
        _amount: contributeAmount,
      });
    });
    it("contribute Toward Liquadity should work", async function () {
      //this function is incomplete
      let initialBalance = new BN(1000000);
      let receipt = await this.tagAlong.sendTransaction({
        from: other1,
        value: initialBalance,
      });
      let amount = new BN(1000);
      await expectRevert(
        this.tagAlong.contributeTowardLiquadity(amount, { from: other1 }),
        "ERR_ONLY_LIQUADITY_ALLWOED"
      );

      await this.tagAlong.contributeTowardLiquadity(amount, {
        from: liquidityPlaceHolder,
      });

      expect(
        await web3.eth.getBalance(this.tagAlong.address)
      ).to.be.bignumber.equal(initialBalance.sub(amount));
    });
    it("should tranfer token liquidity", async function () {
      await this.erc20.approve(this.tagAlong.address, contributeAmount, {
        from: contributer1,
      });
      await this.tagAlong.depositeToken(
        this.erc20.address,
        contributer1,
        contributeAmount,
        {
          from: contributer1,
        }
      );
      expectRevert(
        this.tagAlong.transferTokenLiquadity(
          this.erc20.address,
          other1,
          contributeAmount,
          { from: other1 }
        ),
        "ERR_ONLY_LIQUADITY_ALLWOED"
      );
      let reciept = await this.tagAlong.transferTokenLiquadity(
        this.erc20.address,
        other1,
        contributeAmount,
        { from: liquidityPlaceHolder }
      );
    });
  });
});
