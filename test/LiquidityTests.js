const {
  constants,
  expectEvent,
  expectRevert,
  balance,
  BN,
} = require("@openzeppelin/test-helpers");

const { ZERO_ADDRESS } = constants;

const { expect } = require("chai");

const { takeSnapshot, revertToSnapshot } = require("./utils");

const TruffleContract = require("@truffle/contract");

const { deployBancor } = require("./deployBancor");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

const Liquidity = artifacts.require("Liquadity");
const LiquidityRegistry = artifacts.require("LiquadityRegistery");
const TagAlong = artifacts.require("AuctionTagAlong");
const TagAlongRegistry = artifacts.require("TagAlongRegistry");
const AuctionRegisty = artifacts.require("TestAuctionRegistery");
const CurrencyPrices = artifacts.require("TestCurrencyPrices");
const TokenVault = artifacts.require("TokenVault");
const TokenVaultRegistry = artifacts.require("TokenVaultRegistery");
const whiteListContract = artifacts.require("WhiteList");
const WhiteListRegistry = artifacts.require("WhiteListRegistery");
const TestAuction = artifacts.require("TestAuction");

const denominator = new BN(10).pow(new BN(18));

const getWithDeimals = function (amount) {
  return new BN(amount).mul(denominator);
};

var one;
var thousand;
var hundread;
var bancorNetwork;
var ethToMainToken;
var mainTokenTobaseToken;
var ethToBaseToken;
var baseTokenToMainToken;
var BNTToken;
contract("~liquidity works", function (accounts) {
  const [
    ,
    primaryOwner,
    systemAddress,
    multiSigPlaceHolder,
    auctionPlaceHolder,
    companyFundWallet,
    accountA,
    accountB,
    other1,
  ] = accounts;
  one = getWithDeimals(1);
  thousand = getWithDeimals(10000);
  hundread = getWithDeimals(100);

  beforeEach(async function () {
    var [
      BNTToken1,
      etherToken,
      smartTokenEthBnt,
      converterEthBnt,
      jntrToken,
      smartToken,
      converter,
      bancorNetwork1,
    ] = await deployBancor(accounts);

    this.jntrToken = jntrToken;
    this.smartToken = smartToken;
    this.converter = converter;
    bancorNetwork = bancorNetwork1;
    BNTToken = BNTToken1;

    // the main token is the JNTR
    ethToMainToken = [
      etherToken.address,
      smartTokenEthBnt.address,
      BNTToken.address,
      this.smartToken.address,
      this.jntrToken.address,
    ];

    baseTokenToMainToken = [
      BNTToken.address,
      this.smartToken.address,
      this.jntrToken.address,
    ];
    mainTokenTobaseToken = [
      this.jntrToken.address,
      this.smartToken.address,
      BNTToken.address,
    ];
    ethToBaseToken = [
      etherToken.address,
      smartTokenEthBnt.address,
      BNTToken.address,
    ];
    let baseTokenToEth = [
      BNTToken.address,
      smartTokenEthBnt.address,
      etherToken.address,
    ];

    //setup liquidity
    //auction registry
    this.auctionRegistry = await AuctionRegisty.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
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
    let proxyAddress = await tagAlongRegistry.proxyAddress();
    this.tagAlong = await TagAlong.at(proxyAddress);
    //the TokenVault
    var tokenVaultRegistry = await TokenVaultRegistry.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    let tempTokenVault = await TokenVault.new({ from: primaryOwner });
    await tokenVaultRegistry.addVersion(1, tempTokenVault.address, {
      from: primaryOwner,
    });
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
    //test currencyPrices

    this.currencyPrices = await CurrencyPrices.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );

    //the whiteList
    let stockTokenMaturityDays = 3560;
    let tokenMaturityDays = 0;
    let tokenHoldBackDays = 90;
    var whiteListRegistry = await WhiteListRegistry.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    let tempWhiteList = await whiteListContract.new();
    await whiteListRegistry.addVersion(1, tempWhiteList.address, {
      from: primaryOwner,
    });

    // txTimestamp = (await web3.eth.getBlock("latest")).timestamp;
    await whiteListRegistry.createProxy(
      1,
      primaryOwner,
      systemAddress,
      multiSigPlaceHolder,
      tokenHoldBackDays,
      tokenHoldBackDays,
      tokenHoldBackDays,
      tokenMaturityDays,
      tokenMaturityDays,
      stockTokenMaturityDays,
      this.auctionRegistry.address,
      { from: primaryOwner }
    );

    proxyAddress = await whiteListRegistry.proxyAddress();
    this.whiteList = await whiteListContract.at(proxyAddress);

    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("TAG_ALONG"),
      this.tagAlong.address,
      {
        from: primaryOwner,
      }
    );
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("VAULT"),
      this.tokenVault.address,
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
      web3.utils.fromAscii("CURRENCY"),
      this.currencyPrices.address,
      {
        from: primaryOwner,
      }
    );
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("WHITE_LIST"),
      this.whiteList.address,
      {
        from: primaryOwner,
      }
    );
    //deploying the liquidity
    let baseLinePrice = 1000000; //1$
    var liquidityRegistry = await LiquidityRegistry.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    let tempLiquidity = await Liquidity.new({ from: primaryOwner });
    await liquidityRegistry.addVersion(1, tempLiquidity.address, {
      from: primaryOwner,
    });
    await liquidityRegistry.createProxy(
      1,
      this.converter.address,
      BNTToken.address,
      this.jntrToken.address,
      this.smartToken.address,
      primaryOwner,
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      baseLinePrice,
      { from: primaryOwner }
    );
    proxyAddress = await liquidityRegistry.proxyAddress();
    this.liquidity = await Liquidity.at(proxyAddress);

    //set the paths
    this.liquidity.setTokenPath(0, ethToMainToken, { from: primaryOwner });
    this.liquidity.setTokenPath(1, baseTokenToMainToken, {
      from: primaryOwner,
    });
    this.liquidity.setTokenPath(2, mainTokenTobaseToken, {
      from: primaryOwner,
    });
    this.liquidity.setTokenPath(3, ethToBaseToken, { from: primaryOwner });
    this.liquidity.setTokenPath(4, baseTokenToEth, { from: primaryOwner });

    // this.liquidity = await Liquidity.new(
    //   this.converter.address,
    //   BNTToken.address,
    //   this.jntrToken.address,
    //   this.smartToken.address,
    //   systemAddress,
    //   multiSigPlaceHolder,
    //   this.auctionRegistry.address,
    //   baseLinePrice,
    //   ethToMainToken,
    //   baseTokenToMainToken,
    //   mainTokenTobaseToken,
    //   ethToBaseToken,
    //   baseTokenToEth
    // );
    //Add liquidity to auction registry

    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("LIQUADITY"),
      this.liquidity.address,
      {
        from: primaryOwner,
      }
    );
    //manually update the addresses
    await this.liquidity.updateAddresses();
    await this.tokenVault.updateAddresses();
    await this.tagAlong.updateAddresses();
    //Add liquidity address as a spender in tokenVault
    await this.tokenVault.addSpender(this.liquidity.address, {
      from: multiSigPlaceHolder,
    });
  });
  it("Bancor should setup correctly", async function () {});
  it("contributing with Eth should work correctly", async function () {
    let contributeAmount = new BN(1000);
    //only auction should be able to call this function
    await expectRevert(
      this.liquidity.contributeWithEther({
        from: other1,
        value: contributeAmount,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    let receipt = await this.liquidity.contributeWithEther({
      from: auctionPlaceHolder,
      value: contributeAmount,
    });
    let sideReserveRatio = await this.liquidity.sideReseverRatio();
    let sideReserveAmount = contributeAmount
      .mul(sideReserveRatio)
      .div(new BN(100));
    let mainReserveAmount = contributeAmount.sub(sideReserveAmount);

    //Here we are taking and extra mainReserveAmount out of the tokenVault
    //let tagAlongEthBalance = await balance.current(this.tagAlong.address);

    // if (mainReserveAmount <= tagAlongEthBalance)
    //   mainReserveAmount = mainReserveAmount.add(mainReserveAmount);
    mainReserveAmount = mainReserveAmount.add(mainReserveAmount);

    //mainReserveAmount + whatever tagAlong gave us gets converted into JNTR through bancor
    let tempAmounts = await bancorNetwork.getReturnByPath(
      ethToMainToken,
      mainReserveAmount
    );
    // console.log(await this.liquidity.isAppreciationLimitReached());
    //Now we have added eth and taken out jntr and given them to the tokenVault
    let vaultBalanceJntr = await this.jntrToken.balanceOf(
      this.tokenVault.address
    );
    
    expect(tempAmounts[0]).to.be.bignumber.equal(vaultBalanceJntr);

    expectEvent(receipt, "Contribution", {
      _token: ZERO_ADDRESS,
      _amount: mainReserveAmount,
      returnAmount: tempAmounts[0],
    });
    //The checkAppreciationLimit function is very complecated
    //need to understand it

    // expect(await this.liquidity.lastReserveBalance()).to.be.bignumber.equal(
    //   await this.converter.getReserveBalance(this.jntrToken.address)
    // );
  });
  describe("Jntr price recovery", async function () {
    const calculateJntrPrice = async function (
      baseReserve,
      mainReserve,
      BaseReserveRatio,
      MainReserveRatio,
      bntPrice
    ) {
      let bntRatio = baseReserve.div(BaseReserveRatio);
      let jntrRatio = mainReserve.div(MainReserveRatio);
      // console.log("bntRatio\t" + bntRatio);
      // console.log("jntrRatio\t" + jntrRatio);

      let jntrPrice;
      //the constant one is 10^18 to prevent the loss of precision
      nominator = one;
      // console.log(nominator.toString());
      // console.log(bntPrice.toString());
      jntrPrice = bntPrice
        .mul(bntRatio.mul(nominator).div(jntrRatio))
        .div(nominator);

      return jntrPrice;
    };
    var baseReserveRatio;
    var mainReserveRatio;
    var bntPriceBefore;
    var snapId;
    beforeEach(async function () {
      let tempBaseReserveRatio = await this.converter.reserves(
        BNTToken.address
      );
      let tempMainReserveRatio = await this.converter.reserves(
        this.jntrToken.address
      );
      baseReserveRatio = tempBaseReserveRatio[1];
      mainReserveRatio = tempMainReserveRatio[1];
      bntPriceBefore = new BN(1000000);
      await this.currencyPrices.setCurrencyPriceUSD(
        [BNTToken.address],
        [bntPriceBefore],
        { from: systemAddress }
      );
      //Lets give the tagAlong all the relay tokens(all two of them)
      await this.smartToken.approve(this.tagAlong.address, one.mul(new BN(2)), {
        from: accounts[0],
      });
      await this.tagAlong.depositeToken(
        this.smartToken.address,
        accounts[0],
        one.mul(new BN(2)),
        {
          from: accounts[0],
        }
      );
      // console.log(snapId);
      if (snapId == undefined) snapId = (await takeSnapshot()).result;
    });
    it("recovering price volatility should work", async function () {
      //Alright what we are doing here is recoving JNTR price to 1$
      //Lets do it as per the example in the TD

      //the baseLine price is set to 1000000(1$)

      //First get the price of Jntr
      //Case I: price of Bnt is not increased or decreased more than 5%
      let baseReserveBefore = await this.converter.getReserveBalance(
        BNTToken.address
      );
      let mainReserveBefore = await this.converter.getReserveBalance(
        this.jntrToken.address
      );

      //lets set the price as 1.03$ and nothing should change
      await this.currencyPrices.setCurrencyPriceUSD(
        [BNTToken.address],
        [1030000],
        { from: systemAddress }
      );

      await this.liquidity.recoverPriceVolatility({ from: systemAddress });

      let baseReserveAfter = await this.converter.getReserveBalance(
        BNTToken.address
      );
      let mainReserveAfter = await this.converter.getReserveBalance(
        this.jntrToken.address
      );

      expect(baseReserveBefore).to.be.bignumber.equal(baseReserveAfter);
      expect(mainReserveBefore).to.be.bignumber.equal(mainReserveAfter);

      // //case-II Price of BNT is increased more than 5%
      // //What should happen?? The price of bnt increases meaning the same jntr got by x$ bnt now costs more
      // //Meaning the price of jntr also increased
      // //What should happen? Price of jntr should reamin the same
      // //What we do?
      // //We need to sell the realy tokens i.e. supply of both jntr and bnt is decreased
      // //Now increase the suplly of jntr get back the price jntr to expected one
      // baseReserveBefore = await this.converter.getReserveBalance(
      //   BNTToken.address
      // );
      // mainReserveBefore = await this.converter.getReserveBalance(
      //   this.jntrToken.address
      // );

      // console.log("before");

      // console.log(baseReserveBefore.toString());
      // console.log(mainReserveBefore.toString());

      //for the test to work in current condition we have to take the snapshot
      //Which we should not have to

      //calculate the jntr price
      let jntrPriceBefore = await calculateJntrPrice(
        baseReserveBefore,
        mainReserveBefore,
        baseReserveRatio,
        mainReserveRatio,
        bntPriceBefore
      );
      // console.log("jntrPrcie:" + jntrPriceBefore);
      let bntPriceAfter = new BN(1060000);
      //lets set the price as 1.06$
      await this.currencyPrices.setCurrencyPriceUSD(
        [BNTToken.address],
        [bntPriceAfter],
        { from: systemAddress }
      );
      // console.log(
      //   "Before balance of tagalong of bnt" +
      //     (await BNTToken.balanceOf(this.tagAlong.address)).toString()
      // );

      await this.liquidity.recoverPriceVolatility({ from: systemAddress });

      // console.log("after");

      baseReserveAfter = await this.converter.getReserveBalance(
        BNTToken.address
      );
      mainReserveAfter = await this.converter.getReserveBalance(
        this.jntrToken.address
      );
      let jntrPriceAfter = await calculateJntrPrice(
        baseReserveAfter,
        mainReserveAfter,
        baseReserveRatio,
        mainReserveRatio,
        bntPriceAfter
      );
      //the price after should almost 1 $
      expect(jntrPriceAfter).to.be.bignumber.closeTo(
        new BN(999998),
        new BN(1111111)
      );

      // console.log(
      //   "After balance of tagalong of bnt(should be increased)" +
      //     (await BNTToken.balanceOf(this.tagAlong.address)).toString()
      // );
      //lets get back
      await revertToSnapshot(snapId);
      //case-III Price of jntr is decresed more than 6%
      baseReserveBefore = await this.converter.getReserveBalance(
        BNTToken.address
      );
      mainReserveBefore = await this.converter.getReserveBalance(
        this.jntrToken.address
      );

      // console.log("before");

      // console.log(baseReserveBefore.toString());
      // console.log(mainReserveBefore.toString());

      //calculate the jntr price
      jntrPriceBefore = await calculateJntrPrice(
        baseReserveBefore,
        mainReserveBefore,
        baseReserveRatio,
        mainReserveRatio,
        bntPriceBefore
      );
      // console.log("jntrPrcie:" + jntrPriceBefore);
      bntPriceAfter = new BN(940000);
      //lets set the price as 1.06$
      await this.currencyPrices.setCurrencyPriceUSD(
        [BNTToken.address],
        [bntPriceAfter],
        { from: systemAddress }
      );
      // console.log(
      //   "Before balance of tagalong of bnt" +
      //     (await BNTToken.balanceOf(this.tagAlong.address)).toString()
      // );

      await this.liquidity.recoverPriceVolatility({ from: systemAddress });

      // console.log("after");

      baseReserveAfter = await this.converter.getReserveBalance(
        BNTToken.address
      );
      mainReserveAfter = await this.converter.getReserveBalance(
        this.jntrToken.address
      );
      jntrPriceAfter = await calculateJntrPrice(
        baseReserveAfter,
        mainReserveAfter,
        baseReserveRatio,
        mainReserveRatio,
        bntPriceAfter
      );
      expect(jntrPriceAfter).to.be.bignumber.closeTo(
        new BN(999998),
        new BN(1111111)
      );
      // console.log("jntrPrcie:" + jntrPriceAfter);

      // console.log(baseReserveAfter.toString());
      // console.log(mainReserveAfter.toString());

      // console.log(
      //   "After balance of vault of bnt(should be increased)"
      //
      // );
    });

    it("should recover price correctly when attacker adds bnt to the pool", async function () {
      //lets get back first
      await revertToSnapshot(snapId);
      let baseReserveBefore = await this.converter.getReserveBalance(
        BNTToken.address
      );
      let mainReserveBefore = await this.converter.getReserveBalance(
        this.jntrToken.address
      );

      // console.log("before");

      // console.log(baseReserveBefore.toString());
      // console.log(mainReserveBefore.toString());

      //calculate the jntr price
      let jntrPriceBefore = await calculateJntrPrice(
        baseReserveBefore,
        mainReserveBefore,
        baseReserveRatio,
        mainReserveRatio,
        bntPriceBefore
      );
      // console.log("jntrPrice:" + jntrPriceBefore);

      //lets add transfer some bnt to the pool by a supposed attacked
      BNTToken.transfer(this.converter.address, one.div(new BN(10)), {
        from: accounts[0],
      });
      let lastReserveBalance = await this.liquidity.lastReserveBalance();
      // console.log(lastReserveBalance.toString());

      await this.liquidity.recoverPriceDueToManipulation({
        from: systemAddress,
      });

      // console.log("after");

      let baseReserveAfter = await this.converter.getReserveBalance(
        BNTToken.address
      );
      let mainReserveAfter = await this.converter.getReserveBalance(
        this.jntrToken.address
      );
      let jntrPriceAfter = await calculateJntrPrice(
        baseReserveAfter,
        mainReserveAfter,
        baseReserveRatio,
        mainReserveRatio,
        bntPriceBefore //same as last time becuse here manipulation is due to pool
      );
      //because there may be precision loss but it should be close to 1$
      expect(jntrPriceAfter).to.be.bignumber.closeTo(
        new BN(999998),
        new BN(1000001)
      );
      // console.log("jntrPrcie:" + jntrPriceAfter);

      // console.log(baseReserveAfter.toString());
      // console.log(mainReserveAfter.toString());
    });
  });

  //tests for redemption
  //What does the _recoverAfterRedemption do
  //This test is still remianing
  describe("Redemption works", async function () {
    const IS_ALLOWED_BUYBACK = 1 << 5;
    const KYC = 1 << 0; //0x01
    const AML = 1 << 1; //0x02
    //auctionStub
    var auction;
    const contributeAmount = new BN(10000);
    beforeEach(async function () {
      //lets deploy test auction for when liquidity calls it for auctionDay()
      auction = await TestAuction.new(ZERO_ADDRESS);
      await this.auctionRegistry.updateContractAddress(
        web3.utils.fromAscii("AUCTION"),
        auction.address,
        {
          from: multiSigPlaceHolder,
        }
      );
      await this.liquidity.updateAddresses();
      //Account should be whiteListed and it should be allowed to buy back
      let flags1 = IS_ALLOWED_BUYBACK | KYC | AML;
      let flags2 = KYC | AML;
      let maxWallets = 10;
      await this.whiteList.addNewWallet(accountA, flags1, maxWallets, {
        from: systemAddress,
      });
      //the accountB is just to check one negative condition of isAllowedBuyBack()
      await this.whiteList.addNewWallet(accountB, flags2, maxWallets, {
        from: systemAddress,
      });

      //lets give these guys some jntr
      await this.jntrToken.transfer(accountA, contributeAmount, {
        from: accounts[0],
      });
      await this.jntrToken.transfer(accountB, contributeAmount, {
        from: accounts[0],
      });

      await this.jntrToken.approve(this.liquidity.address, contributeAmount, {
        from: accountA,
      });
      await this.jntrToken.approve(this.liquidity.address, contributeAmount, {
        from: accountB,
      });
    });
    //case-I side reserve has enough ether

    it("When side reserve has enough ether", async function () {
      // let baseReserveBefore = await this.converter.getReserveBalance(
      //   BNTToken.address
      // );
      // let mainReserveBefore = await this.converter.getReserveBalance(
      //   this.jntrToken.address
      // );

      // console.log("before");

      // console.log(baseReserveBefore.toString());
      // console.log(mainReserveBefore.toString());
      // console.log((await BNTToken.balanceOf(accountA)).toString())

      ///here the side reserve has some ether
      await this.liquidity.sendTransaction({
        from: other1,
        value: contributeAmount,
      });
      //I need to know first how many BNT are we taking out
      //To calculate the exact things

      //should revert if address is not allowed to buyback
      await expectRevert(
        this.liquidity.redemption(mainTokenTobaseToken, contributeAmount, {
          from: accountB,
        }),
        "ERR_NOT_ALLOWED_BUYBACK"
      );

      //accountA comes for redemption of its JNTR
      //He wants to convert JNTR into either BNT or ether
      //In this case BNT
      let receipt = await this.liquidity.redemption(
        mainTokenTobaseToken,
        contributeAmount,
        { from: accountA }
      );

      let balanceBNTAccountA = await BNTToken.balanceOf(accountA);
      //redemption event should be fired
      expectEvent(receipt, "Redemption", {
        _token: BNTToken.address,
        _amount: contributeAmount,
        returnAmount: balanceBNTAccountA,
      });

      // let baseReserveAfter = await this.converter.getReserveBalance(
      //   BNTToken.address
      // );
      // let mainReserveAfter = await this.converter.getReserveBalance(
      //   this.jntrToken.address
      // );
      // console.log(baseReserveAfter.toString());
      // console.log(mainReserveAfter.toString());

      // //lets check what happens internally is correct or not
      // let a = await bancorNetwork.getReturnByPath(ethToBaseToken, balanceBNTAccountA)
      // console.log(a[0].toString())
      // console.log(a[1].toString())

      // let b = await bancorNetwork.getReturnByPath(baseTokenToMainToken, a[0] + a[1])
      // console.log((b[0]).toString())

      // console.log((await balance.current(this.liquidity.address)).toString())

      // let tagAlongBalanceJntr = await this.jntrToken.balanceOf(this.tokenVault.address)
      // console.log(tagAlongBalanceJntr.toString())
    });

   
  });
});
