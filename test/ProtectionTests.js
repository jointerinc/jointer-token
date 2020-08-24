const {
  constants,
  expectEvent,
  expectRevert,
  BN,
} = require("@openzeppelin/test-helpers");

const { ZERO_ADDRESS } = constants;

const { expect } = require("chai");

const {
  advanceTimeAndBlock,
  advanceTime,
  takeSnapshot,
  revertToSnapshot,
} = require("./utils");
const Protection = artifacts.require("AuctionProtection");
const ProtectionRegistry = artifacts.require("ProtectionRegistry");
const TokenVault = artifacts.require("TokenVault");
const TokenVaultRegistry = artifacts.require("TokenVaultRegistery");
const TagAlong = artifacts.require("AuctionTagAlong");
const TagAlongRegistry = artifacts.require("TagAlongRegistry");
const AuctionRegisty = artifacts.require("TestAuctionRegistery");
const TestAuction = artifacts.require("TestAuction");

const TestERC20 = artifacts.require("TestERC20");

const denominator = new BN(10).pow(new BN(18));
const PERCENT_NOMINATOR = new BN(10).pow(new BN(6));

const getWithDecimals = function (amount) {
  return new BN(amount).mul(denominator);
};
const getWith6Decimals = function (amount) {
  return new BN(amount).mul(PERCENT_NOMINATOR);
};

const totalAmount = getWithDecimals(new BN(1)); //1* 10^18
const contributeAmount = getWith6Decimals(new BN(2)); // 2* 10^6

contract("~Protection works", function (accounts) {
  const [
    primaryOwner,
    systemAddress,
    multiSigPlaceHolder,
    companyFundWallet,
    stakingCompanyWallet,
    accountA,
    accountB,
    accountC,
    other1,
  ] = accounts;
  beforeEach(async function () {
    //auction registry
    this.auctionRegistry = await AuctionRegisty.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    //the prtection
    var protectionRegistry = await ProtectionRegistry.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    let tempProtection = await Protection.new();
    await protectionRegistry.addVersion(1, tempProtection.address);
    await protectionRegistry.createProxy(
      1,
      primaryOwner,
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      { from: primaryOwner }
    );
    let proxyAddress = await protectionRegistry.proxyAddress();
    this.protection = await Protection.at(proxyAddress);
    //some other token
    this.erc20 = await TestERC20.new({ from: primaryOwner });
    //main token
    this.mockMainToken = await TestERC20.new({ from: primaryOwner });

    //The stub auction
    this.auctionStub = await TestAuction.new(this.protection.address);
    //token vault
    var tokenVaultRegistry = await TokenVaultRegistry.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    let tempTokenVault = await TokenVault.new();
    await tokenVaultRegistry.addVersion(1, tempTokenVault.address);
    await tokenVaultRegistry.createProxy(
      1,
      primaryOwner,
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      { from: primaryOwner }
    );
    proxyAddress = await tokenVaultRegistry.proxyAddress();
    this.tokenVault = await TokenVault.at(proxyAddress);

    //tagAlong
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

    //Add all the addresses to the auction registry
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("VAULT"),
      this.tokenVault.address,
      {
        from: primaryOwner,
      }
    );
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("MAIN_TOKEN"),
      this.mockMainToken.address,
      {
        from: primaryOwner,
      }
    );
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("AUCTION_PROTECTION"),
      this.protection.address,
      {
        from: primaryOwner,
      }
    );
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("AUCTION"),
      this.auctionStub.address,
      {
        from: primaryOwner,
      }
    );
    // tagalong treat as liquadity because we only have to check token balance 
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("LIQUADITY"),
      this.tagAlong.address,
      {
        from: primaryOwner,
      }
    );
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("COMPANY_FUND_WALLET"),
      companyFundWallet,
      {
        from: primaryOwner,
      }
    );
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("STACKING_TOKEN_WALLET"),
      stakingCompanyWallet,
      {
        from: primaryOwner,
      }
    );

    //call updateAddresses in all the contracts
    await this.protection.updateAddresses();
    await this.tokenVault.updateAddresses();
    await this.tagAlong.updateAddresses();

    //Note: do we need the liquidity's address???

    //Mint some to the auction address
    await this.erc20.mint(this.auctionStub.address, totalAmount, {
      from: primaryOwner,
    });
    await this.mockMainToken.mint(this.auctionStub.address, totalAmount, {
      from: primaryOwner,
    });

    //Allow the token
    // await this.protection.allowToken(this.erc20.address, {
    //   from: systemAddress,
    // });

    // console.log("protection: " + this.protection.address);
    // console.log("main token: " + this.mockMainToken.address);
    // console.log("accountA: " + accountA);
    // console.log("accountB: " + accountB);
    // console.log("accountC: " + accountC);
  });
  it("should initialize correctly", async function () {
    // console.log(
    //   "There can be an error of one second because of the whole transaction not getting included in the same block(It is not a breaking error)"
    // );

    expect(await this.protection.systemAddress()).to.equal(systemAddress);
    expect(await this.protection.primaryOwner()).to.equal(primaryOwner);
    expect(await this.protection.authorityAddress()).to.equal(
      multiSigPlaceHolder
    );
    expect(await this.protection.contractsRegistry()).to.equal(
      this.auctionRegistry.address
    );

    expect(await this.protection.vaultAddress()).to.equal(
      this.tokenVault.address
    );
    expect(await this.protection.mainTokenAddress()).to.equal(
      this.mockMainToken.address
    );
    expect(await this.protection.companyFundWalletAddress()).to.equal(
      companyFundWallet
    );
   
    expect(await this.protection.liquadityAddress()).to.equal(
      this.tagAlong.address
    );
    expect(await this.protection.auctionAddress()).to.equal(
      this.auctionStub.address
    );

    expect(await this.protection.tokenLockDuration()).to.be.bignumber.equal(
      "365"
    );
    expect(await this.protection.vaultRatio()).to.be.bignumber.equal("90");
  });
  it("should lock ether correctly", async function () {
    await expectRevert(
      this.protection.lockEther(accountA, {
        from: other1,
        value: contributeAmount,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    let now = (await web3.eth.getBlock("latest")).timestamp;
    let receipt = await this.auctionStub.lockEther(accountA, {
      value: contributeAmount,
    });
    expectEvent.inTransaction(receipt.tx, Protection, "FundLocked", {
      _token: ZERO_ADDRESS,
      _which: accountA,
      _amount: contributeAmount,
    });

    expect(await this.protection.lockedOn(accountA)).to.be.bignumber.equal("1");

    expect(
      await this.protection.currentLockedFunds(accountA, ZERO_ADDRESS)
    ).to.be.bignumber.equal(contributeAmount);
  });
  it("auction should be able to deposit token correctly", async function () {
    await this.auctionStub.lockEther(accountA, {
      value: contributeAmount,
    });
    // await this.auctionStub.approve(
    //   this.erc20.address,
    //   this.protection.address,
    //   contributeAmount
    // );
    // await this.auctionStub.lockTokens(
    //   this.erc20.address,
    //   this.auctionStub.address,
    //   accountA,
    //   contributeAmount
    // );
    await expectRevert.unspecified(
      this.auctionStub.depositToken(
        this.auctionStub.address,
        accountA,
        contributeAmount
      )
    );
    await this.auctionStub.approve(
      this.mockMainToken.address,
      this.protection.address,
      contributeAmount
    );

    await expectRevert(
      this.protection.depositToken(
        this.auctionStub.address,
        accountA,
        contributeAmount,
        { from: other1 }
      ),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    let receipt = await this.auctionStub.depositToken(
      this.auctionStub.address,
      accountA,
      contributeAmount
    );
    expectEvent.inTransaction(receipt.tx, Protection, "FundLocked", {
      _token: this.mockMainToken.address,
      _which: accountA,
      _amount: contributeAmount,
    });

    // expect(
    //   await this.protection.lockedFunds(accountA, this.erc20.address)
    // ).to.be.bignumber.equal(contributeAmount);
    expect(
      await this.protection.lockedFunds(accountA, ZERO_ADDRESS)
    ).to.be.bignumber.equal(contributeAmount);
    expect(await this.protection.lockedTokens(accountA)).to.be.bignumber.equal(
      contributeAmount
    );
  });
  it("should cancel investment correctly(Investor->tokens/company->JNTR)", async function () {
    await this.auctionStub.lockEther(accountA, {
      value: contributeAmount,
    });
    // await this.auctionStub.approve(
    //   this.erc20.address,
    //   this.protection.address,
    //   contributeAmount
    // );
    // await this.auctionStub.lockTokens(
    //   this.erc20.address,
    //   this.auctionStub.address,
    //   accountA,
    //   contributeAmount
    // );
    await this.auctionStub.approve(
      this.mockMainToken.address,
      this.protection.address,
      contributeAmount
    );
    await this.auctionStub.depositToken(
      this.auctionStub.address,
      accountA,
      contributeAmount
    );
    let snapId = (await takeSnapshot()).result;
    await this.auctionStub.changeAuctionDay(367);
    // console.log(
    //   "locked on: " + (await this.protection.lockedOn(accountA)).toString()
    // );
    // console.log((await this.auctionStub.auctionDay()).toString());
    // console.log((await this.protection.tokenLockDuration()).toString());
    // //Just to test the cancelling  period
    // console.log(await this.protection.isTokenLockEndDay("1"));

    await expectRevert(
      this.protection.cancelInvestment({ from: accountA }),
      "ERR_INVESTMENT_CANCEL_PERIOD_OVER"
    );
    // await this.auctionStub.changeAuctionDay(1);

    await revertToSnapshot(snapId);
    let receipt = await this.protection.cancelInvestment({ from: accountA });
    expectEvent.inLogs(receipt.logs, "InvestMentCancelled", {
      _from: accountA,
      _tokenAmount: contributeAmount,
    });
    expectEvent(receipt, "FundTransfer", {
      _to: accountA,
      _token: ZERO_ADDRESS,
      _amount: contributeAmount,
    });
    // expectEvent(receipt, "FundTransfer", {
    //   _to: accountA,
    //   _token: this.erc20.address,
    //   _amount: contributeAmount,
    // });
    expectEvent(receipt, "FundTransfer", {
      _to: this.tokenVault.address,
      _token: this.mockMainToken.address,
      _amount: contributeAmount,
    });
    // expect(await this.erc20.balanceOf(accountA)).to.be.bignumber.equal(
    //   contributeAmount
    // );
    expect(
      await this.mockMainToken.balanceOf(this.tokenVault.address)
    ).to.be.bignumber.equal(contributeAmount);

    // expect(
    //   await this.protection.lockedFunds(accountA, this.erc20.address)
    // ).to.be.bignumber.equal("0");
    expect(
      await this.protection.lockedFunds(accountA, ZERO_ADDRESS)
    ).to.be.bignumber.equal("0");
    expect(await this.protection.lockedTokens(accountA)).to.be.bignumber.equal(
      "0"
    );
  });
  // There is some redundancy in the code but it works
  it("should unlock tokens correctly(Investor->JNTR/company->Tokens)", async function () {
    //    console.log("tagAlong: " +  await this.protection.tagAlongAddress());

    // console.log("companyFundWallet: " + await this.protection.companyFundWallet());

    await this.auctionStub.lockEther(accountA, {
      value: contributeAmount,
    });
    // await this.auctionStub.approve(
    //   this.erc20.address,
    //   this.protection.address,
    //   contributeAmount
    // );
    // await this.auctionStub.lockTokens(
    //   this.erc20.address,
    //   this.auctionStub.address,
    //   accountA,
    //   contributeAmount
    // );
    await this.auctionStub.approve(
      this.mockMainToken.address,
      this.protection.address,
      contributeAmount
    );
    await this.auctionStub.depositToken(
      this.auctionStub.address,
      accountA,
      contributeAmount
    );
    let receipt = await this.protection.unLockTokens({ from: accountA });
    let vaultRatio = await this.protection.vaultRatio();
    let walletAmount = contributeAmount.mul(vaultRatio).div(new BN(100));
    let tagAlongAmount = contributeAmount.sub(walletAmount);

    // expectEvent(receipt, "FundTransfer", {
    //   _to: this.tagAlong.address,
    //   _token: this.erc20.address,
    //   _amount: tagAlongAmount,
    // });
    // expectEvent(receipt, "FundTransfer", {
    //   _to: companyFundWallet,
    //   _token: this.erc20.address,
    //   _amount: walletAmount,
    // });
    expectEvent(receipt, "FundTransfer", {
      _to: this.tagAlong.address,
      _token: ZERO_ADDRESS,
      _amount: tagAlongAmount,
    });
    expectEvent(receipt, "FundTransfer", {
      _to: companyFundWallet,
      _token: ZERO_ADDRESS,
      _amount: walletAmount,
    });
    expectEvent(receipt, "FundTransfer", {
      _to: accountA,
      _token: this.mockMainToken.address,
      _amount: contributeAmount,
    });
    expectEvent(receipt, "TokenUnLocked", {
      _from: accountA,
      _tokenAmount: contributeAmount,
    });
    // expect(
    //   await this.erc20.balanceOf(this.tagAlong.address)
    // ).to.be.bignumber.equal(tagAlongAmount);
    // expect(await this.erc20.balanceOf(companyFundWallet)).to.be.bignumber.equal(
    //   walletAmount
    // );
    expect(await this.mockMainToken.balanceOf(accountA)).to.be.bignumber.equal(
      contributeAmount
    );
    // expect(
    //   await this.protection.lockedFunds(accountA, this.erc20.address)
    // ).to.be.bignumber.equal("0");
    expect(
      await this.protection.lockedFunds(accountA, ZERO_ADDRESS)
    ).to.be.bignumber.equal("0");
    expect(await this.protection.lockedTokens(accountA)).to.be.bignumber.equal(
      "0"
    );
  });
  it("should unlock funds of someone by one of the owners", async function () {
    await this.auctionStub.lockEther(accountA, {
      value: contributeAmount,
    });
    // await this.auctionStub.approve(
    //   this.erc20.address,
    //   this.protection.address,
    //   contributeAmount
    // );
    // await this.auctionStub.lockTokens(
    //   this.erc20.address,
    //   this.auctionStub.address,
    //   accountA,
    //   contributeAmount
    // );
    await this.auctionStub.approve(
      this.mockMainToken.address,
      this.protection.address,
      contributeAmount
    );
    await this.auctionStub.depositToken(
      this.auctionStub.address,
      accountA,
      contributeAmount
    );

    await expectRevert(
      this.protection.unLockFundByAdmin(accountA, { from: systemAddress }),
      "ERR_ADMIN_CANT_UNLOCK_FUND"
    );
    await this.auctionStub.changeAuctionDay(400);
    await expectRevert(
      this.protection.unLockFundByAdmin(accountA, { from: other1 }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );

    //the method we are testing
    let receipt = await this.protection.unLockFundByAdmin(accountA, {
      from: systemAddress,
    });
    let vaultRatio = await this.protection.vaultRatio();
    let walletAmount = contributeAmount.mul(vaultRatio).div(new BN(100));
    let tagAlongAmount = contributeAmount.sub(walletAmount);

    // expectEvent(receipt, "FundTransfer", {
    //   _to: this.tagAlong.address,
    //   _token: this.erc20.address,
    //   _amount: tagAlongAmount,
    // });
    // expectEvent(receipt, "FundTransfer", {
    //   _to: companyFundWallet,
    //   _token: this.erc20.address,
    //   _amount: walletAmount,
    // });
    expectEvent(receipt, "FundTransfer", {
      _to: this.tagAlong.address,
      _token: ZERO_ADDRESS,
      _amount: tagAlongAmount,
    });
    expectEvent(receipt, "FundTransfer", {
      _to: companyFundWallet,
      _token: ZERO_ADDRESS,
      _amount: walletAmount,
    });
    expectEvent(receipt, "FundTransfer", {
      _to: accountA,
      _token: this.mockMainToken.address,
      _amount: contributeAmount,
    });
    expectEvent(receipt, "TokenUnLocked", {
      _from: accountA,
      _tokenAmount: contributeAmount,
    });
    // expect(
    //   await this.erc20.balanceOf(this.tagAlong.address)
    // ).to.be.bignumber.equal(tagAlongAmount);
    // expect(await this.erc20.balanceOf(companyFundWallet)).to.be.bignumber.equal(
    //   walletAmount
    // );
    expect(await this.mockMainToken.balanceOf(accountA)).to.be.bignumber.equal(
      contributeAmount
    );
    // expect(
    //   await this.protection.lockedFunds(accountA, this.erc20.address)
    // ).to.be.bignumber.equal("0");
    expect(
      await this.protection.lockedFunds(accountA, ZERO_ADDRESS)
    ).to.be.bignumber.equal("0");
    expect(await this.protection.lockedTokens(accountA)).to.be.bignumber.equal(
      "0"
    );
  });
  describe("~Stacking works", async function () {
    it("should stack tokens by user correctly", async function () {
      await this.auctionStub.lockEther(accountA, {
        value: contributeAmount,
      });
      // await this.auctionStub.approve(
      //   this.erc20.address,
      //   this.protection.address,
      //   contributeAmount
      // );
      // await this.auctionStub.lockTokens(
      //   this.erc20.address,
      //   this.auctionStub.address,
      //   accountA,
      //   contributeAmount
      // );
      await this.auctionStub.approve(
        this.mockMainToken.address,
        this.protection.address,
        contributeAmount
      );
      await this.auctionStub.depositToken(
        this.auctionStub.address,
        accountA,
        contributeAmount
      );
      let roundId = await this.protection.stackRoundId();
      let receipt = await this.protection.stackToken({ from: accountA });
      let vaultRatio = await this.protection.vaultRatio();
      let walletAmount = contributeAmount.mul(vaultRatio).div(new BN(100));
      let tagAlongAmount = contributeAmount.sub(walletAmount);
      expectEvent(receipt, "StackAdded", {
        _roundId: roundId,
        _whom: accountA,
        _amount: contributeAmount,
      });
      expect(await this.protection.totalTokenAmount()).to.be.bignumber.equal(
        contributeAmount
      );
      expect(
        await this.protection.getStackBalance(accountA)
      ).to.be.bignumber.equal(contributeAmount);
      // expectEvent(receipt, "FundTransfer", {
      //   _to: this.tagAlong.address,
      //   _token: this.erc20.address,
      //   _amount: tagAlongAmount,
      // });
      // expectEvent(receipt, "FundTransfer", {
      //   _to: companyFundWallet,
      //   _token: this.erc20.address,
      //   _amount: walletAmount,
      // });
      expectEvent(receipt, "FundTransfer", {
        _to: this.tagAlong.address,
        _token: ZERO_ADDRESS,
        _amount: tagAlongAmount,
      });
      expectEvent(receipt, "FundTransfer", {
        _to: companyFundWallet,
        _token: ZERO_ADDRESS,
        _amount: walletAmount,
      });
      // expect(
      //   await this.erc20.balanceOf(this.tagAlong.address)
      // ).to.be.bignumber.equal(tagAlongAmount);
      // expect(
      //   await this.erc20.balanceOf(companyFundWallet)
      // ).to.be.bignumber.equal(walletAmount);
      // expect(
      //   await this.protection.lockedFunds(accountA, this.erc20.address)
      // ).to.be.bignumber.equal("0");
      expect(
        await this.protection.lockedFunds(accountA, ZERO_ADDRESS)
      ).to.be.bignumber.equal("0");
      expect(
        await this.protection.lockedTokens(accountA)
      ).to.be.bignumber.equal("0");
    });
    it("should add the reward tokens correctly", async function () {
      //revert if tokens are not approved
      await expectRevert.unspecified(
        this.auctionStub.stackFund(contributeAmount)
      );
      await this.auctionStub.approve(
        this.mockMainToken.address,
        this.protection.address,
        contributeAmount
      );
      //only auction protection should be able to
      await expectRevert(
        this.protection.stackFund(contributeAmount, {
          from: other1,
        }),
        "ERR_AUTHORIZED_ADDRESS_ONLY"
      );
      let roundId = await this.protection.stackRoundId();
      await this.auctionStub.stackFund(contributeAmount);
      expect(await this.protection.stackRoundId()).to.be.bignumber.equal(
        roundId.add(new BN(1))
      );
      //if nobody has stacked then it should go to the stakingCompanyWallet
      expect(
        await this.mockMainToken.balanceOf(this.tokenVault.address)
      ).to.be.bignumber.equal(contributeAmount);
      //if somebody stacks it then...
      await this.auctionStub.lockEther(accountA, {
        value: contributeAmount,
      });
      // await this.auctionStub.approve(
      //   this.erc20.address,
      //   this.protection.address,
      //   contributeAmount
      // );
      // await this.auctionStub.lockTokens(
      //   this.erc20.address,
      //   this.auctionStub.address,
      //   accountA,
      //   contributeAmount
      // );
      await this.auctionStub.approve(
        this.mockMainToken.address,
        this.protection.address,
        contributeAmount
      );
      await this.auctionStub.depositToken(
        this.auctionStub.address,
        accountA,
        contributeAmount
      );
      await this.protection.stackToken({ from: accountA });
      expect(await this.protection.totalTokenAmount()).to.be.bignumber.equal(
        contributeAmount
      );
      await this.auctionStub.approve(
        this.mockMainToken.address,
        this.protection.address,
        contributeAmount
      );
      roundId = await this.protection.stackRoundId();
      await this.auctionStub.stackFund(contributeAmount);
      expect(await this.protection.stackRoundId()).to.be.bignumber.equal(
        roundId.add(new BN(1))
      );
      expect(await this.protection.totalTokenAmount()).to.be.bignumber.equal(
        contributeAmount.mul(new BN(2))
      );
    });
    //this test needs improvement for sure
    it("should distribute the reward correclty (_calculateStackFund)", async function () {
      await this.auctionStub.approve(
        this.mockMainToken.address,
        this.protection.address,
        totalAmount
      );
      const amount1 = getWith6Decimals(new BN(1000));
      const amount2 = getWith6Decimals(new BN(1000));
      const amount3 = getWith6Decimals(new BN(1000));
      var accs = [accountA, accountB, accountC];
      var rewards = [amount1, amount2, amount3];
      var protectionBalance = [
        [amount1, amount2, amount3],
        [amount1, amount2, amount3],
        [amount1, amount2, amount3],
      ];
      var balance = new Array(3).fill(new BN(0));
      //It is just to store balabce everyday to be able to compare afterwards
      var balanceDayWise = [...Array(3)].map((e) => Array(3).fill(new BN(0)));
      var total = new BN(0);
      //caculate here using javascript
      for (let day = 0; day < accs.length; day++) {
        total = total.add(
          protectionBalance[day][0]
            .add(protectionBalance[day][1])
            .add(protectionBalance[day][2])
        );
        let ratio = rewards[day].mul(denominator).div(total);
        for (let i = 0; i < accs.length; i++) {
          balance[i] = balance[i].add(protectionBalance[day][i]);
          let indReward = balance[i].mul(ratio).div(denominator);
          balance[i] = balance[i].add(indReward);
          // console.log(": " + balance[i]);
          balanceDayWise[day][i] = balance[i];
        }
        total = total.add(rewards[day]);
      }
      for (let day = 0; day < accs.length; day++) {
        for (let i = 0; i < accs.length; i++) {
          await this.auctionStub.depositToken(
            this.auctionStub.address,
            accs[i],
            protectionBalance[day][i]
          );
          // console.log(day);
          // console.log(i);
          // console.log(protectionBalance[day][i].toString());
          await this.protection.stackToken({ from: accs[i] });
          // console.log(":: " + (await this.protection.getStackBalance(accs[i])));
        }
        await this.auctionStub.stackFund(rewards[day]);
        for (let i = 0; i < accs.length; i++) {
          expect(
            await this.protection.getStackBalance(accs[i])
          ).to.be.bignumber.equal(balanceDayWise[day][i]);
        }
      }
    });
    it("should unlock tokens from stacking correctly", async function () {
      //The calcultion is happing correctly(see the test above) So we just need to check if
      //things other than calcualting is happening correclty
      await this.auctionStub.approve(
        this.mockMainToken.address,
        this.protection.address,
        contributeAmount
      );
      await this.auctionStub.depositToken(
        this.auctionStub.address,
        accountA,
        contributeAmount
      );
      await this.protection.stackToken({ from: accountA });
      let totalTokenAmount = await this.protection.totalTokenAmount();
      let roundId = await this.protection.stackRoundId();
      let reciept = await this.protection.unlockTokenFromStack({
        from: accountA,
      });
      expectEvent(reciept, "StackRemoved", {
        _roundId: roundId,
        _whom: accountA,
        _amount: contributeAmount,
      });
      expect(await this.protection.totalTokenAmount()).to.be.bignumber.equal(
        totalTokenAmount.sub(contributeAmount)
      );
      expect(
        await this.protection.getStackBalance(accountA)
      ).to.be.bignumber.equal("0");
    });
    //choosing not to test the distributionStackInBatch because none of the storage variables it changes
    //are publicly avaibale for calling
  });
});
