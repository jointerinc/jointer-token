//Note: is there any assertion for below in auction protection...
// In the technical design it says "Once the user canceling the staking, he is out and there is no option to return those tokens or deposit any other tokens
// into the staking program."

const {
  constants,
  expectEvent,
  expectRevert,
  BN,
} = require("@openzeppelin/test-helpers");

const {ZERO_ADDRESS} = constants;

const {expect} = require("chai");

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
const AuctionTagAlong = artifacts.require("AuctionTagAlong");
const AuctionRegisty = artifacts.require("TestAuctionRegistery");

const TestERC20 = artifacts.require("TestERC20");

const denominator = new BN(10).pow(new BN(18));

const getWithDeimals = function (amount) {
  return new BN(amount).mul(denominator);
};

const totalAmount = new BN(100000);
const contributeAmount = new BN(1);

contract("~Protection works", function (accounts) {
  const [
    primaryOwner,
    systemAddress,
    multiSigPlaceHolder,
    auctionPlaceHolder,
    companyFundWallet,
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
      {from: primaryOwner}
    );
    //the prtection
    var protectionRegistry = await ProtectionRegistry.new(
      systemAddress,
      multiSigPlaceHolder,
      {from: primaryOwner}
    );
    let tempProtection = await Protection.new();
    await protectionRegistry.addVersion(1, tempProtection.address);
    await protectionRegistry.createProxy(
      1,
      primaryOwner,
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      {from: primaryOwner}
    );
    let proxyAddress = await protectionRegistry.proxyAddress();
    this.protection = await Protection.at(proxyAddress);
    //some other token
    this.erc20 = await TestERC20.new({from: primaryOwner});
    //main token
    this.mockMainToken = await TestERC20.new({from: primaryOwner});
    //token vault
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
    proxyAddress = await tokenVaultRegistry.proxyAddress();
    this.tokenVault = await TokenVault.at(proxyAddress);

    //tagAlong
    this.tagAlong = await AuctionTagAlong.new(
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      {from: primaryOwner}
    );

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
      auctionPlaceHolder,
      {
        from: primaryOwner,
      }
    );
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("TAG_ALONG"),
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
    //call updateAddresses in all the contracts
    await this.protection.updateAddresses();
    await this.tokenVault.updateAddresses();
    await this.tagAlong.updateAddresses();

    //Note: do we need the liquidity's address???

    //Mint some to the auction address
    await this.erc20.mint(auctionPlaceHolder, totalAmount, {
      from: primaryOwner,
    });
    await this.mockMainToken.mint(auctionPlaceHolder, totalAmount, {
      from: primaryOwner,
    });

    //Allow the token
    await this.protection.allowToken(this.erc20.address, {from: systemAddress});

    // console.log("protection: " + this.protection.address);
    // console.log("main token: " + this.mockMainToken.address);
    // console.log("accountA: " + accountA);
    // console.log("accountB: " + accountB);
    // console.log("accountC: " + accountC);
  });
  it("should initialize correctly", async function () {
    console.log(
      "There can be an error of one second because of the whole transaction not getting included in the same block(It is not a breaking error)"
    );

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
    expect(await this.protection.tagAlongAddress()).to.equal(
      this.tagAlong.address
    );
    expect(await this.protection.auctionAddress()).to.equal(auctionPlaceHolder);

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
    let receipt = await this.protection.lockEther(accountA, {
      from: auctionPlaceHolder,
      value: contributeAmount,
    });
    expectEvent(receipt, "FundLocked", {
      _token: ZERO_ADDRESS,
      _which: accountA,
      _amount: contributeAmount,
    });

    expect(await this.protection.lockedOn(accountA)).to.be.bignumber.equal(
      now.toString()
    );

    expect(
      await this.protection.currentLockedFunds(accountA, ZERO_ADDRESS)
    ).to.be.bignumber.equal(contributeAmount);
  });
  it("should lock tokens correctly", async function () {
    await expectRevert.unspecified(
      this.protection.lockTokens(
        this.erc20.address,
        auctionPlaceHolder,
        accountA,
        contributeAmount,
        {
          from: auctionPlaceHolder,
        }
      )
    );
    await this.erc20.approve(this.protection.address, contributeAmount, {
      from: auctionPlaceHolder,
    });
    await expectRevert(
      this.protection.lockTokens(
        this.erc20.address,
        auctionPlaceHolder,
        accountA,
        contributeAmount,
        {
          from: other1,
        }
      ),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    let now = (await web3.eth.getBlock("latest")).timestamp;
    let receipt = await this.protection.lockTokens(
      this.erc20.address,
      auctionPlaceHolder,
      accountA,
      contributeAmount,
      {
        from: auctionPlaceHolder,
      }
    );
    expectEvent(receipt, "FundLocked", {
      _token: this.erc20.address,
      _which: accountA,
      _amount: contributeAmount,
    });

    expect(await this.protection.lockedOn(accountA)).to.be.bignumber.equal(
      now.toString()
    );

    expect(
      await this.protection.currentLockedFunds(accountA, this.erc20.address)
    ).to.be.bignumber.equal(contributeAmount);
  });
  it("auction should be able to deposit token correctly", async function () {
    await this.protection.lockEther(accountA, {
      from: auctionPlaceHolder,
      value: contributeAmount,
    });
    await this.erc20.approve(this.protection.address, contributeAmount, {
      from: auctionPlaceHolder,
    });
    await this.protection.lockTokens(
      this.erc20.address,
      auctionPlaceHolder,
      accountA,
      contributeAmount,
      {
        from: auctionPlaceHolder,
      }
    );
    await expectRevert.unspecified(
      this.protection.depositToken(
        auctionPlaceHolder,
        accountA,
        contributeAmount,
        {from: auctionPlaceHolder}
      )
    );
    await this.mockMainToken.approve(
      this.protection.address,
      contributeAmount,
      {
        from: auctionPlaceHolder,
      }
    );
    await expectRevert(
      this.protection.depositToken(
        auctionPlaceHolder,
        accountA,
        contributeAmount,
        {from: other1}
      ),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    let receipt = await this.protection.depositToken(
      auctionPlaceHolder,
      accountA,
      contributeAmount,
      {from: auctionPlaceHolder}
    );
    expectEvent(receipt, "FundLocked", {
      _token: this.mockMainToken.address,
      _which: accountA,
      _amount: contributeAmount,
    });

    expect(
      await this.protection.lockedFunds(accountA, this.erc20.address)
    ).to.be.bignumber.equal(contributeAmount);
    expect(
      await this.protection.lockedFunds(accountA, ZERO_ADDRESS)
    ).to.be.bignumber.equal(contributeAmount);
    expect(await this.protection.lockedTokens(accountA)).to.be.bignumber.equal(
      contributeAmount
    );
  });
  it("should cancel investment correctly(Investor->tokens/company->JNTR)", async function () {
    await this.protection.lockEther(accountA, {
      from: auctionPlaceHolder,
      value: contributeAmount,
    });
    await this.erc20.approve(this.protection.address, contributeAmount, {
      from: auctionPlaceHolder,
    });
    await this.protection.lockTokens(
      this.erc20.address,
      auctionPlaceHolder,
      accountA,
      contributeAmount,
      {
        from: auctionPlaceHolder,
      }
    );
    await this.mockMainToken.approve(
      this.protection.address,
      contributeAmount,
      {
        from: auctionPlaceHolder,
      }
    );
    await this.protection.depositToken(
      auctionPlaceHolder,
      accountA,
      contributeAmount,
      {from: auctionPlaceHolder}
    );
    let snapId = (await takeSnapshot()).result;

    let now = await web3.eth.getBlock("latest").timestamp;
    await advanceTimeAndBlock(365 * 86400);

    await expectRevert(
      this.protection.cancelInvestment({from: accountA}),
      "ERR_INVESTMENT_CANCEL_PERIOD_OVER"
    );

    await revertToSnapshot(snapId);
    let receipt = await this.protection.cancelInvestment({from: accountA});
    expectEvent.inLogs(receipt.logs, "InvestMentCancelled", {
      _from: accountA,
      _tokenAmount: contributeAmount,
    });
    expectEvent(receipt, "FundTransfer", {
      _to: accountA,
      _token: ZERO_ADDRESS,
      _amount: contributeAmount,
    });
    expectEvent(receipt, "FundTransfer", {
      _to: accountA,
      _token: this.erc20.address,
      _amount: contributeAmount,
    });
    expectEvent(receipt, "FundTransfer", {
      _to: this.tokenVault.address,
      _token: this.mockMainToken.address,
      _amount: contributeAmount,
    });
    expect(await this.erc20.balanceOf(accountA)).to.be.bignumber.equal(
      contributeAmount
    );
    expect(
      await this.mockMainToken.balanceOf(this.tokenVault.address)
    ).to.be.bignumber.equal(contributeAmount);

    expect(
      await this.protection.lockedFunds(accountA, this.erc20.address)
    ).to.be.bignumber.equal("0");
    expect(
      await this.protection.lockedFunds(accountA, ZERO_ADDRESS)
    ).to.be.bignumber.equal("0");
    expect(await this.protection.lockedTokens(accountA)).to.be.bignumber.equal(
      "0"
    );
  });
  // There is some redundancy in the code but it works
  it("should unlock tokens correctly(Investor->JNTR/company->Tokens)", async function () {
    await this.protection.lockEther(accountA, {
      from: auctionPlaceHolder,
      value: contributeAmount,
    });
    await this.erc20.approve(this.protection.address, contributeAmount, {
      from: auctionPlaceHolder,
    });
    await this.protection.lockTokens(
      this.erc20.address,
      auctionPlaceHolder,
      accountA,
      contributeAmount,
      {
        from: auctionPlaceHolder,
      }
    );
    await this.mockMainToken.approve(
      this.protection.address,
      contributeAmount,
      {
        from: auctionPlaceHolder,
      }
    );
    await this.protection.depositToken(
      auctionPlaceHolder,
      accountA,
      contributeAmount,
      {from: auctionPlaceHolder}
    );

    let receipt = await this.protection.unLockTokens({from: accountA});
    let vaultRatio = await this.protection.vaultRatio();
    let walletAmount = contributeAmount.mul(vaultRatio).div(new BN(100));
    let tagAlongAmount = contributeAmount.sub(walletAmount);

    expectEvent(receipt, "FundTransfer", {
      _to: this.tagAlong.address,
      _token: this.erc20.address,
      _amount: tagAlongAmount,
    });
    expectEvent(receipt, "FundTransfer", {
      _to: companyFundWallet,
      _token: this.erc20.address,
      _amount: walletAmount,
    });
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
    expect(
      await this.erc20.balanceOf(this.tagAlong.address)
    ).to.be.bignumber.equal(tagAlongAmount);
    expect(await this.erc20.balanceOf(companyFundWallet)).to.be.bignumber.equal(
      walletAmount
    );
    expect(await this.mockMainToken.balanceOf(accountA)).to.be.bignumber.equal(
      contributeAmount
    );
    expect(
      await this.protection.lockedFunds(accountA, this.erc20.address)
    ).to.be.bignumber.equal("0");
    expect(
      await this.protection.lockedFunds(accountA, ZERO_ADDRESS)
    ).to.be.bignumber.equal("0");
    expect(await this.protection.lockedTokens(accountA)).to.be.bignumber.equal(
      "0"
    );
  });
  it("should unlock funds of someone by one of the owners", async function () {
    await this.protection.lockEther(accountA, {
      from: auctionPlaceHolder,
      value: contributeAmount,
    });
    await this.erc20.approve(this.protection.address, contributeAmount, {
      from: auctionPlaceHolder,
    });
    await this.protection.lockTokens(
      this.erc20.address,
      auctionPlaceHolder,
      accountA,
      contributeAmount,
      {
        from: auctionPlaceHolder,
      }
    );
    await this.mockMainToken.approve(
      this.protection.address,
      contributeAmount,
      {
        from: auctionPlaceHolder,
      }
    );
    await this.protection.depositToken(
      auctionPlaceHolder,
      accountA,
      contributeAmount,
      {from: auctionPlaceHolder}
    );

    await expectRevert(
      this.protection.unLockFundByAdmin(accountA, {from: systemAddress}),
      "ERR_ADMIN_CANT_UNLOCK_FUND"
    );
    await advanceTimeAndBlock(365 * 86400);
    await expectRevert(
      this.protection.unLockFundByAdmin(accountA, {from: other1}),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    //the method we are testing
    let receipt = await this.protection.unLockFundByAdmin(accountA, {
      from: systemAddress,
    });
    let vaultRatio = await this.protection.vaultRatio();
    let walletAmount = contributeAmount.mul(vaultRatio).div(new BN(100));
    let tagAlongAmount = contributeAmount.sub(walletAmount);

    expectEvent(receipt, "FundTransfer", {
      _to: this.tagAlong.address,
      _token: this.erc20.address,
      _amount: tagAlongAmount,
    });
    expectEvent(receipt, "FundTransfer", {
      _to: companyFundWallet,
      _token: this.erc20.address,
      _amount: walletAmount,
    });
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
    expect(
      await this.erc20.balanceOf(this.tagAlong.address)
    ).to.be.bignumber.equal(tagAlongAmount);
    expect(await this.erc20.balanceOf(companyFundWallet)).to.be.bignumber.equal(
      walletAmount
    );
    expect(await this.mockMainToken.balanceOf(accountA)).to.be.bignumber.equal(
      contributeAmount
    );
    expect(
      await this.protection.lockedFunds(accountA, this.erc20.address)
    ).to.be.bignumber.equal("0");
    expect(
      await this.protection.lockedFunds(accountA, ZERO_ADDRESS)
    ).to.be.bignumber.equal("0");
    expect(await this.protection.lockedTokens(accountA)).to.be.bignumber.equal(
      "0"
    );
  });
  describe("~Stacking works", async function () {
    it("should stack tokens by user correctly", async function () {
      await this.protection.lockEther(accountA, {
        from: auctionPlaceHolder,
        value: contributeAmount,
      });
      await this.erc20.approve(this.protection.address, contributeAmount, {
        from: auctionPlaceHolder,
      });
      await this.protection.lockTokens(
        this.erc20.address,
        auctionPlaceHolder,
        accountA,
        contributeAmount,
        {
          from: auctionPlaceHolder,
        }
      );
      await this.mockMainToken.approve(
        this.protection.address,
        contributeAmount,
        {
          from: auctionPlaceHolder,
        }
      );
      await this.protection.depositToken(
        auctionPlaceHolder,
        accountA,
        contributeAmount,
        {from: auctionPlaceHolder}
      );
      let roundId = await this.protection.stackRoundId();
      let receipt = await this.protection.stackToken({from: accountA});
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
      expectEvent(receipt, "FundTransfer", {
        _to: this.tagAlong.address,
        _token: this.erc20.address,
        _amount: tagAlongAmount,
      });
      expectEvent(receipt, "FundTransfer", {
        _to: companyFundWallet,
        _token: this.erc20.address,
        _amount: walletAmount,
      });
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
      expect(
        await this.erc20.balanceOf(this.tagAlong.address)
      ).to.be.bignumber.equal(tagAlongAmount);
      expect(
        await this.erc20.balanceOf(companyFundWallet)
      ).to.be.bignumber.equal(walletAmount);
      expect(
        await this.protection.lockedFunds(accountA, this.erc20.address)
      ).to.be.bignumber.equal("0");
      expect(
        await this.protection.lockedFunds(accountA, ZERO_ADDRESS)
      ).to.be.bignumber.equal("0");
      expect(
        await this.protection.lockedTokens(accountA)
      ).to.be.bignumber.equal("0");
    });
    it("should add the reward tokens correctly", async function () {
      await expectRevert.unspecified(
        this.protection.stackFund(contributeAmount, {
          from: auctionPlaceHolder,
        })
      );
      await this.mockMainToken.approve(
        this.protection.address,
        contributeAmount,
        {
          from: auctionPlaceHolder,
        }
      );
      //only auction protection should be able to
      await expectRevert(
        this.protection.stackFund(contributeAmount, {
          from: other1,
        }),
        "ERR_AUTHORIZED_ADDRESS_ONLY"
      );
      let roundId = await this.protection.stackRoundId();
      await this.protection.stackFund(contributeAmount, {
        from: auctionPlaceHolder,
      });
      expect(await this.protection.stackRoundId()).to.be.bignumber.equal(
        roundId.add(new BN(1))
      );
      //if nobody has stacked then it should go to the vault
      expect(
        await this.mockMainToken.balanceOf(this.tokenVault.address)
      ).to.be.bignumber.equal(contributeAmount);
      //if somebody stacks it then...
      await this.protection.lockEther(accountA, {
        from: auctionPlaceHolder,
        value: contributeAmount,
      });
      await this.erc20.approve(this.protection.address, contributeAmount, {
        from: auctionPlaceHolder,
      });
      await this.protection.lockTokens(
        this.erc20.address,
        auctionPlaceHolder,
        accountA,
        contributeAmount,
        {
          from: auctionPlaceHolder,
        }
      );
      await this.mockMainToken.approve(
        this.protection.address,
        contributeAmount,
        {
          from: auctionPlaceHolder,
        }
      );
      await this.protection.depositToken(
        auctionPlaceHolder,
        accountA,
        contributeAmount,
        {from: auctionPlaceHolder}
      );
      await this.protection.stackToken({from: accountA});
      expect(await this.protection.totalTokenAmount()).to.be.bignumber.equal(
        contributeAmount
      );
      await this.mockMainToken.approve(
        this.protection.address,
        contributeAmount,
        {
          from: auctionPlaceHolder,
        }
      );
      roundId = await this.protection.stackRoundId();
      await this.protection.stackFund(contributeAmount, {
        from: auctionPlaceHolder,
      });
      expect(await this.protection.stackRoundId()).to.be.bignumber.equal(
        roundId.add(new BN(1))
      );
      expect(await this.protection.totalTokenAmount()).to.be.bignumber.equal(
        contributeAmount.mul(new BN(2))
      );
    });

    //this test needs improvement for sure
    it("should distribute the reward correclty (_calculateStackFund)", async function () {
      await this.mockMainToken.approve(this.protection.address, totalAmount, {
        from: auctionPlaceHolder,
      });
      const amount1 = new BN(1000);
      const amount2 = new BN(1000);
      const amount3 = new BN(1000);

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
          await this.protection.depositToken(
            auctionPlaceHolder,
            accs[i],
            protectionBalance[day][i],
            {from: auctionPlaceHolder}
          );
          // console.log(protectionBalance[day][i].toString());

          await this.protection.stackToken({from: accs[i]});
          // console.log(":: " + (await this.protection.getStackBalance(accs[i])));
        }
        await this.protection.stackFund(rewards[day], {
          from: auctionPlaceHolder,
        });
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
      await this.mockMainToken.approve(
        this.protection.address,
        contributeAmount,
        {
          from: auctionPlaceHolder,
        }
      );
      await this.protection.depositToken(
        auctionPlaceHolder,
        accountA,
        contributeAmount,
        {from: auctionPlaceHolder}
      );
      await this.protection.stackToken({from: accountA});
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
