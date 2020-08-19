const {
  constants,
  expectEvent,
  expectRevert,
  balance,
  time,
  BN,
} = require("@openzeppelin/test-helpers");

const { ZERO_ADDRESS } = constants;

const { expect } = require("chai");

const { deployBancor } = require("./deployBancor");
const { forEach } = require("lodash");

const Auction = artifacts.require("Auction");
const AuctionRegistry = artifacts.require("AuctionRegistry");
const Liquidity = artifacts.require("Liquadity");
const LiquidityRegistry = artifacts.require("LiquadityRegistery");
const TagAlong = artifacts.require("AuctionTagAlong");
const TagAlongRegistry = artifacts.require("AuctionTagAlongRegistry");
const AuctionRegisty = artifacts.require("TestAuctionRegistery");
const CurrencyPrices = artifacts.require("TestCurrencyPrices");
const TokenVault = artifacts.require("TokenVault");
const TokenVaultRegistry = artifacts.require("TokenVaultRegistery");
const whiteListContract = artifacts.require("WhiteList");
const WhiteListRegistry = artifacts.require("WhiteListRegistery");
const Protection = artifacts.require("AuctionProtection");
const ProtectionRegistry = artifacts.require("ProtectionRegistry");
const JNTRToken = artifacts.require("MainToken");
const TestEscrow = artifacts.require("TestEscrow");

const denominator = new BN(10).pow(new BN(18));
const priceDenominator = new BN(10).pow(new BN(9));

const getWith18Decimals = function (amount) {
  return new BN(amount).mul(denominator);
};
const getWith9Decimals = function (amount) {
  return new BN(amount).mul(priceDenominator);
};

const IS_BYPASSED = 1 << 13;
const BANCOR_ADDRESS = 1 << 14;
const IS_ALLOWED_AUCTION = 1 << 15;

var one;
var thousand;
var hundread;
var bancorNetwork;
var ethToMainToken;
var BNTToken;
contract("~Auction works", function (accounts) {
  const [
    ,
    primaryOwner,
    systemAddress,
    multiSigPlaceHolder,
    companyFundWallet,
    companyMainTokenWallet, //Will hold alll the main tokens
    stackingFundWallet, //If nobody has stacked then this is where the stacking bonus goes to
    accountA,
    accountB,
    other1,
  ] = accounts;
  one = getWith18Decimals(1);
  thousand = getWith18Decimals(10000);
  hundread = getWith18Decimals(100);

  const downSideProtectioRatio = new BN(90);
  const fundWalletRatio = new BN(90);
  const hundreadPercentage = new BN(100);

  beforeEach(async function () {
    var [
      BNTToken,
      etherToken,
      smartTokenEthBnt,
      converterEthBnt,
      jntrToken,
      smartToken,
      converter,
      bancorNetwork,
      smartTokenMainBNT,
      converterMainBNT,
    ] = await deployBancor(accounts);

    //Now I want this.jntrToken to be actual mainToken
    //What should I do??
    //Create and extra converter pass it here and do the rest here
    //setup for mainToken

    //auction registry
    this.auctionRegistry = await AuctionRegisty.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    //Deploy Whitelist
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
      { from: primaryOwner }
    );

    let proxyAddress = await whiteListRegistry.proxyAddress();
    this.whiteList = await whiteListContract.at(proxyAddress);
    
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("WHITE_LIST"),
      this.whiteList.address,
      {
        from: primaryOwner,
      }
    );
    
    

    //setup WhiteList
    //add acounts[0] to whitlist(make it bypassed)
    // let flags = IS_BYPASSED || IS_ALLOWED_AUCTION;
    let flags = 49152;
    let maxWallets = 0;

    await this.whiteList.addNewWallet(accounts[0], flags, maxWallets, {
      from: systemAddress,
    });

    
    //converter needs to be whitelisted too
    // flags = BANCOR_ADDRESS || IS_ALLOWED_AUCTION;
    flags = 49152;
    await this.whiteList.addNewWallet(
      converterMainBNT.address,
      flags,
      maxWallets,
      {
        from: systemAddress,
      }
    );
    //We need to whitelist the convertETHBNT too
    //Because when converting eth into jntr it would go throught this
    await this.whiteList.addNewWallet(
      converterEthBnt.address,
      flags,
      maxWallets,
      {
        from: systemAddress,
      }
    );
    //We also need to whitlist bancorNtwork becuase it will hold the mainToken when converting ethTOmain
    await this.whiteList.addNewWallet(
      bancorNetwork.address,
      flags,
      maxWallets,
      {
        from: systemAddress,
      }
    );

    //deploy the actual main token
    this.mainToken = await JNTRToken.new(
      "JNTR",
      "JNTR",
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      [accounts[0]],
      [thousand],
      { from: primaryOwner }
    );

    this.escrow = await TestEscrow.new(this.mainToken.address);
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("ESCROW"),
      this.escrow.adress,
      {
        from: primaryOwner,
      }
    );
    
    await this.whiteList.addNewWallet(this.escrow.adress, flags, maxWallets, {
      from: systemAddress,
    });
    //With this lets fast forward in future where token holdeback days are over

    //Now add it as a reserve
    await converterMainBNT.addReserve(this.mainToken.address, 500000, {
      from: accounts[0],
    });
    await converterMainBNT.setConversionFee(1000, { from: accounts[0] });
    //fund the BNTJNTR Pool woth initial tokens
    //to do that first get those two tokens
    await BNTToken.issue(accounts[0], thousand, {
      from: accounts[0],
    });
    //now fund the pool

    await BNTToken.transfer(converterMainBNT.address, one, {
      from: accounts[0],
    });
    await this.mainToken.transfer(converterMainBNT.address, one, {
      from: accounts[0],
    });

    //issue initial smart tokens equal to usd equivalent of the both reserve
    await smartTokenMainBNT.issue(accounts[0], one.mul(new BN(2)), {
      from: accounts[0],
    });

    //activate the pool
    //the pool would be invalid if it is not the owner of the corresponding smart token
    await smartTokenMainBNT.transferOwnership(converterMainBNT.address, {
      from: accounts[0],
    });
    await converterMainBNT.acceptTokenOwnership({
      from: accounts[0],
    });

    this.jntrToken = this.mainToken;
    this.smartToken = smartTokenMainBNT;
    this.converter = converterMainBNT;

    //setup for Auction

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

    //the prtection
    var protectionRegistry = await ProtectionRegistry.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    let tempProtection = await Protection.new();
    await protectionRegistry.addVersion(1, tempProtection.address, {
      from: primaryOwner,
    });
    await protectionRegistry.createProxy(
      1,
      primaryOwner,
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      { from: primaryOwner }
    );
    proxyAddress = await protectionRegistry.proxyAddress();
    this.protection = await Protection.at(proxyAddress);

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
    //the paths
    //base token is the BNT
    // the main token is the JNTR
    ethToMainToken = [
      etherToken.address,
      smartTokenEthBnt.address,
      BNTToken.address,
      this.smartToken.address,
      this.jntrToken.address,
    ];

    let baseTokenToMainToken = [
      BNTToken.address,
      this.smartToken.address,
      this.jntrToken.address,
    ];
    let mainTokenTobaseToken = [
      this.jntrToken.address,
      this.smartToken.address,
      BNTToken.address,
    ];
    let ethToBaseToken = [
      etherToken.address,
      smartTokenEthBnt.address,
      BNTToken.address,
    ];
    let baseTokenToEth = [
      BNTToken.address,
      smartTokenEthBnt.address,
      etherToken.address,
    ];
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
    //Put all these addresses in the auction Registry
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("LIQUADITY"),
      this.liquidity.address,
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
      web3.utils.fromAscii("VAULT"),
      this.tokenVault.address,
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
      web3.utils.fromAscii("COMPANY_FUND_WALLET"),
      companyFundWallet,
      {
        from: primaryOwner,
      }
    );
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("COMPANY_MAIN_TOKEN_WALLET"),
      companyMainTokenWallet,
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
      web3.utils.fromAscii("STACKING_TOKEN_WALLET"),
      stackingFundWallet,
      {
        from: primaryOwner,
      }
    );

    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("MAIN_TOKEN"),
      this.jntrToken.address,
      {
        from: primaryOwner,
      }
    );

    //the startTime would be now from my understnding
    //th minAuctionTime would be less than a day
    let startTime = await time.latest();
    let minAuctionTime = time.duration.hours(23);
    let interval = time.duration.days(1);
    var auctionRegistry = await AuctionRegistry.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    let tempAuction = await Auction.new({ from: primaryOwner });
    await auctionRegistry.addVersion(1, tempAuction.address, {
      from: primaryOwner,
    });
    await auctionRegistry.createProxy(
      1,
      startTime,
      minAuctionTime,
      interval,
      9,
      primaryOwner,
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      { from: primaryOwner }
    );
    proxyAddress = await auctionRegistry.proxyAddress();
    this.auction = await Auction.at(proxyAddress);

    //Add this address to the registry
    await this.auctionRegistry.registerContractAddress(
      web3.utils.fromAscii("AUCTION"),
      this.auction.address,
      {
        from: primaryOwner,
      }
    );
    //manually update the addresses
    await this.auction.updateAddresses();
    await this.liquidity.updateAddresses();
    await this.tokenVault.updateAddresses();
    await this.tagAlong.updateAddresses();
    await this.protection.updateAddresses();
    await this.jntrToken.updateAddresses();
    //Add liquidity address as a spender in tokenVault
    await this.tokenVault.addSpender(this.liquidity.address, {
      from: multiSigPlaceHolder,
    });

    //Whitelist accountA and AccountB
    // flags = IS_BYPASSED || IS_ALLOWED_AUCTION; // KYC|AML
    flags = 49152;
    // console.log(flags);
    maxWallets = 10;
    await this.whiteList.addNewWallet(accountA, flags, maxWallets, {
      from: systemAddress,
    });
    await this.whiteList.addNewWallet(accountB, flags, maxWallets, {
      from: systemAddress,
    });
    //We need to whiteList evryone who gets their hands on the jntr
    //flags = IS_BYPASSED || IS_ALLOWED_AUCTION;
    flags = 40960;
    maxWallets = 0;
    await this.whiteList.addNewWallet(
      this.tokenVault.address,
      flags,
      maxWallets,
      {
        from: systemAddress,
      }
    );
    await this.whiteList.addNewWallet(
      this.tagAlong.address,
      flags,
      maxWallets,
      {
        from: systemAddress,
      }
    );
    await this.whiteList.addNewWallet(
      this.liquidity.address,
      flags,
      maxWallets,
      {
        from: systemAddress,
      }
    );
    await this.whiteList.addNewWallet(this.auction.address, flags, maxWallets, {
      from: systemAddress,
    });
    await this.whiteList.addNewWallet(companyFundWallet, flags, maxWallets, {
      from: systemAddress,
    });
    await this.whiteList.addNewWallet(
      this.protection.address,
      flags,
      maxWallets,
      {
        from: systemAddress,
      }
    );
    //Because if no one has stacked then the stacking bonus goes to stackingFundWallet
    await this.whiteList.addNewWallet(stackingFundWallet, flags, maxWallets, {
      from: systemAddress,
    });
    //This is the wallet where the minting fees after auction end goes
    await this.whiteList.addNewWallet(
      companyMainTokenWallet,
      flags,
      maxWallets,
      {
        from: systemAddress,
      }
    );
    //Alo lets just fast forward in the future where holdback days are over
    await time.increase(time.duration.days(tokenHoldBackDays));
  });
  it("Auction should be initialized correctly", async function () {
    //lets see if converting eth to main token works

    // await this.converter.quickConvert2(ethToMainToken, 10, 1, ZERO_ADDRESS, 0, {
    //   from: accountA,
    //   value: 10,
    // });
    //console.log(await this.auction.lastAuctionStart());
    //90% goes to DownsideProtection
    expect(
      await this.auction.dayWiseDownSideProtectionRatio(1)
    ).to.be.bignumber.equal(downSideProtectioRatio);
    //90% of remaining 10% i.e. 9% goes to comapanyWallet
    expect(await this.auction.fundWalletRatio()).to.be.bignumber.equal(
      fundWalletRatio
    );

    //other initializations
    expect(await this.auction.totalContribution()).to.be.bignumber.equal(
      getWith9Decimals(2500000)
    );
    expect(await this.auction.yesterdayContribution()).to.be.bignumber.equal(
      getWith9Decimals(500)
    );
    expect(await this.auction.allowedMaxContribution()).to.be.bignumber.equal(
      getWith9Decimals(500)
    );
    expect(await this.auction.todaySupply()).to.be.bignumber.equal(
      getWith18Decimals(50000)
    );

    // //To make sure everybody has everybody's address
    // console.log(await this.protection.auctionAddress());
    // console.log(await this.protection.auctionAddress());
    // console.log(this.auction.address);
  });
  it("should contribute with ether correclty", async function () {
    let contributionAmount = getWith9Decimals(new BN(500));

    const companyFundWalletTracker = await balance.tracker(
      companyFundWallet,
      "wei"
    );
    const protectionTracker = await balance.tracker(
      this.protection.address,
      "wei"
    );
    const liquidityEthTracker = await balance.tracker(
      this.liquidity.address,
      "wei"
    );
    await this.currencyPrices.setCurrencyPriceUSD([ZERO_ADDRESS,this.jntrToken.address], [one,one], {
      from: systemAddress,
    });
    // await this.currencyPrices.setCurrencyPriceUSD([joie], [one], {
    //   from: systemAddress,
    // });
    // console.log(await web3.eth.getBalance(companyFundWallet));
    let auctionDay = await this.auction.auctionDay();
    console.log("auctionDay",auctionDay);

    await this.auction.contributeWithEther({
      from: accountA,
      value: contributionAmount,
    });
    //lets calulate and make sure that amount went where it was supposed to

    //90% of it goes to the downside protection
    //Ether gets locked
    let downSideAmount = contributionAmount
      .mul(downSideProtectioRatio)
      .div(hundreadPercentage);

    //90% of reamaning goes to the comany fund wallet
    let temp = contributionAmount.sub(downSideAmount);
    let companyFundWalletAmount = temp
      .mul(fundWalletRatio)
      .div(hundreadPercentage);

    temp = temp.sub(companyFundWalletAmount);
    //Remainig goes to reserves
    let reserveAmount = temp;

    // console.log(await web3.eth.getBalance(companyFundWallet));

    //lest start checking if they did go to where they were supposed to
    expect(await companyFundWalletTracker.delta()).to.be.bignumber.equal(
      companyFundWalletAmount
    );

    expect(await protectionTracker.delta()).to.be.bignumber.equal(
      downSideAmount
    );

    //Now lets see how the remaiing 1% is divides in to main reserve and side reserve

    //0.1% to main reserve(Which is bancor) and 0.9% to side reserve ( Which will stay in the
    //liqudity contract itself??
    // Thats suprising but that is what is happening)
    let sideReserveRatio = await this.liquidity.sideReseverRatio(); //Which is 90%
    // console.log(sideReserveRatio.toString());
    let sideReserveAmount = reserveAmount
      .mul(sideReserveRatio)
      .div(hundreadPercentage);

    expect(await liquidityEthTracker.delta()).to.be.bignumber.equal(
      sideReserveAmount
    );
    //for the remaining 0.1% gets converted into jntr with help of bancor and given to tokenVault
    //These tests are done already in the liquidity so choosing not to do it again
  });
  it("should keep track of top5 contributors", async function () {
    //the current way to calculate bonus can be optimized
    //by keeping track of only first 5 addresses

    //first things first
    //add currencyPrices
    let ethPrice = one;
    let mainTokenPrice = one;
    await this.currencyPrices.setCurrencyPriceUSD(
      [ZERO_ADDRESS, this.jntrToken.address],
      [ethPrice, mainTokenPrice],
      { from: systemAddress }
    );
    //lets make a programmable test
    //change the vaules here to test if it works correctly
    //Max 10 and it only tests the condition when two accounts does not have same contribution
    let contributionInEth = [80000, 90000, 40000, 50000, 60000, 70000];

    let amountToAccount = new Map();
    let i = 0;
    contributionInEth.forEach((element) => {
      amountToAccount.set(element, i);
      i++;
    });

    let contributionBN = [];
    contributionInEth.forEach((element) => {
      contributionBN.push(new BN(element));
    });

    //Whitelist them
    for (let i = 0; i < contributionInEth.length; i++) {
      let isWhiteListed = await this.whiteList.isWhiteListed(accounts[i]);
      let flags = 32768;
      let maxWallets = 10;
      if (!isWhiteListed) {
        await this.whiteList.addNewWallet(accounts[i], flags, maxWallets, {
          from: systemAddress,
        });
      }
    }

    for (let i = 0; i < contributionInEth.length; i++) {
      await this.auction.contributeWithEther({
        from: accounts[i],
        value: contributionBN[i],
      });
    }
    let auctionDay = await this.auction.auctionDay();
    console.log(auctionDay);
    //following is true only becuase I have set the price of ether to be 1* 10^18
    for (let i = 0; i < contributionInEth.length; i++) {
      expect(
        await this.auction.walletDayWiseContribution(auctionDay, accounts[i])
      ).to.be.bignumber.equal(contributionBN[i]);
    }

    contributionInEth.sort();
    contributionInEth.reverse();

    for (let i = 0; i < 5; i++) {
      expect(
        await this.auction.topContributiorIndex(
          auctionDay,
          accounts[amountToAccount.get(contributionInEth[i])]
        )
      ).to.be.bignumber.equal((i + 1).toString());
    }
  });

  // Next We need to check what happens when auction ends
  // Also after it is updated We need to check the bonus calculation
  // That includes two things "FundAdded" and distributeTokens

  describe("Auction Ends correctly", async function () {
    beforeEach(async function () {
      //Also we would need to allow the token becuse you cannot lock tokens in protection if token is not allowed
      // await this.protection.allowToken(this.jntrToken.address, {
      //   from: systemAddress,
      // });
      //set the price for ether and the jntr in the currencyPrices
      //1 eth = 1* 10 ^18
      //1 jntr =1 * 10^ 18
      //need to figure out what is the deimal situation in auction
      await this.currencyPrices.setCurrencyPriceUSD(
        [ZERO_ADDRESS, this.jntrToken.address],
        [one, one],
        { from: systemAddress }
      );
      //Also we need to whitelist every address that contributes
      //accountA and accountB are already whitelisted

      await this.jntrToken.transfer(accountA, one, {
        from: accounts[0],
      });
      await this.jntrToken.transfer(accountB, one, {
        from: accounts[0],
      });
    });
    it("when today's supply is less then the yesterday's supply", async function () {
      let yesterdaySupply = new BN(200000);
      let todaySupply = new BN(100000);

      //contribute yesterDay supply and end the auction
      await this.auction.contributeWithEther({
        from: accountA,
        value: yesterdaySupply,
      });
      await this.auction.auctionEnd({ from: systemAddress });

      //contribute today supply and end the auction
      await this.auction.contributeWithEther({
        from: accountB,
        value: todaySupply,
      });
      let auctionDay = await this.auction.auctionDay();
      let supplyOfJNTR = await this.auction.todaySupply();
      let stackingWalletJNTRBalance = await this.jntrToken.balanceOf(
        stackingFundWallet
      );
      let companyTokenWalletJNTRBalnce = await this.jntrToken.balanceOf(
        companyMainTokenWallet
      );
      // console.log(companyTokenWalletJNTRBalnce.toString());
      await this.auction.auctionEnd({ from: systemAddress });

      //lets make sure everything is set correctly

      let allowedMaxContributionPercent = await this.auction.maxContributionAllowed(); //Which is 150
      let maxContributionAllowed1 = todaySupply
        .mul(allowedMaxContributionPercent)
        .div(hundreadPercentage);

      let maxContributionAllowed2 = yesterdaySupply
        .mul(allowedMaxContributionPercent)
        .div(hundreadPercentage);
      //Following because the max for these two will be the ones getting selected(This will be the case when auctionDay = 2)
      let maxContributionAllowed =
        maxContributionAllowed1 > maxContributionAllowed2
          ? maxContributionAllowed1
          : maxContributionAllowed2;

      expect(await this.auction.allowedMaxContribution()).to.be.bignumber.equal(
        maxContributionAllowed
      );
      //expect bonusSupply to be zero
      expect(
        await this.auction.dayWiseSupplyBonus(auctionDay)
      ).to.be.bignumber.equal("0");

      // console.log((await this.auction.dayWiseSupply(auctionDay)).toString());

      expect(
        await this.auction.dayWiseSupply(auctionDay)
      ).to.be.bignumber.equal(supplyOfJNTR);

      let dayWiseSupply = await this.auction.dayWiseSupply(auctionDay);
      //calculate the stacking Amount(Which is 1% of the dayWiseSupply)
      //Find the difference of jntrBalance
      stackingWalletJNTRBalance = (
        await this.jntrToken.balanceOf(stackingFundWallet)
      ).sub(stackingWalletJNTRBalance);

      //This difference should be same as 1% of the dayWise supply
      let stackingRatio = await this.auction.stacking();
      let stackingAmount = dayWiseSupply
        .mul(stackingRatio)
        .div(hundreadPercentage);

      expect(stackingAmount).to.be.bignumber.equal(stackingWalletJNTRBalance);

      //calculate the management fees (which is (100/98 -1) of the supply + stackingAmount)
      let totalSupply = dayWiseSupply.add(stackingAmount);
      let managementFees = await this.auction.mangmentFee(); //which is =2
      let temp = totalSupply
        .mul(hundreadPercentage)
        .div(hundreadPercentage.sub(managementFees));
      let fees = temp.sub(totalSupply);

      //Find the difference of jntrBalance
      companyTokenWalletJNTRBalnce = (
        await this.jntrToken.balanceOf(companyMainTokenWallet)
      ).sub(companyTokenWalletJNTRBalnce);

      expect(fees).to.be.bignumber.equal(companyTokenWalletJNTRBalnce);
    });
    it("when today's supply is greater then the yesterday's supply", async function () {
      let yesterdaySupply = new BN(200000);
      let todaySupply = new BN(300000);

      //contribute yesterDay supply and end the auction
      await this.auction.contributeWithEther({
        from: accountA,
        value: yesterdaySupply,
      });

      await this.auction.auctionEnd({ from: systemAddress });

      //contribute today supply and end the auction
      await this.auction.contributeWithEther({
        from: accountB,
        value: todaySupply,
      });
      let auctionDay = await this.auction.auctionDay();
      let supplyOfJNTR = await this.auction.todaySupply();
      let stackingWalletJNTRBalance = await this.jntrToken.balanceOf(
        stackingFundWallet
      );
      let companyTokenWalletJNTRBalnce = await this.jntrToken.balanceOf(
        companyMainTokenWallet
      );
      // console.log(companyTokenWalletJNTRBalnce.toString());

      await this.auction.auctionEnd({ from: systemAddress });

      //lets make sure everything is set correctly

      let allowedMaxContributionPercent = await this.auction.maxContributionAllowed(); //Which is 150
      let maxContributionAllowed1 = todaySupply
        .mul(allowedMaxContributionPercent)
        .div(hundreadPercentage);

      let maxContributionAllowed2 = yesterdaySupply
        .mul(allowedMaxContributionPercent)
        .div(hundreadPercentage);
      //Following because the max for these two will be the ones getting selected(This will be the case when auctionDay = 2)
      let maxContributionAllowed =
        maxContributionAllowed1 > maxContributionAllowed2
          ? maxContributionAllowed1
          : maxContributionAllowed2;

      expect(await this.auction.allowedMaxContribution()).to.be.bignumber.equal(
        maxContributionAllowed
      );
      //calculate the bonus
      //Which will be on the today's supply which is decided by yesterday's contribution(i.e. supplyOf JNTR)
      let groupBonusRatio = await this.auction.groupBonusRatio(); //Which is 2
      //The bonus is (supply*(today*ratio/yesterday) - supply)

      let temp = todaySupply
        .mul(denominator)
        .div(yesterdaySupply)
        .mul(groupBonusRatio);

      let bonusSupply = supplyOfJNTR
        .mul(temp)
        .div(denominator)
        .sub(supplyOfJNTR);
      expect(
        await this.auction.dayWiseSupplyBonus(auctionDay)
      ).to.be.bignumber.equal(bonusSupply);

      let dayWiseSupply = await this.auction.dayWiseSupply(auctionDay);

      expect(dayWiseSupply).to.be.bignumber.equal(
        bonusSupply.add(supplyOfJNTR)
      );
      //calculate the stacking Amount(Which is 1% of the dayWiseSupply)
      //Find the difference of jntrBalance
      stackingWalletJNTRBalance = (
        await this.jntrToken.balanceOf(stackingFundWallet)
      ).sub(stackingWalletJNTRBalance);

      //This difference should be same as 1% of the dayWise supply
      let stackingRatio = await this.auction.stacking();
      let stackingAmount = dayWiseSupply
        .mul(stackingRatio)
        .div(hundreadPercentage);

      expect(stackingAmount).to.be.bignumber.equal(stackingWalletJNTRBalance);

      //calculate the management fees (which is (100/98 -1) of the supply + stackingAmount)
      let totalSupply = dayWiseSupply.add(stackingAmount);
      let managementFees = await this.auction.mangmentFee(); //which is =2
      temp = totalSupply
        .mul(hundreadPercentage)
        .div(hundreadPercentage.sub(managementFees));
      let fees = temp.sub(totalSupply);

      //Find the difference of jntrBalance
      companyTokenWalletJNTRBalnce = (
        await this.jntrToken.balanceOf(companyMainTokenWallet)
      ).sub(companyTokenWalletJNTRBalnce);

      expect(fees).to.be.bignumber.equal(companyTokenWalletJNTRBalnce);
    });
    // it("when the today's contribution is zero(TODO)", async function () {});whe
  });
  //Will need to change this becuase of new change
  it("should distribute Tokens correctly", async function () {
    //set the price for ether and the jntr in the currencyPrices
    //1 eth = 1* 10 ^18
    //1 jntr =1 * 10^ 18
    //need to figure out what is the deimal situation in auction
    await this.currencyPrices.setCurrencyPriceUSD(
      [ZERO_ADDRESS, this.jntrToken.address],
      [one, one],
      { from: systemAddress }
    );
    //need to allow the token to be able to lock the tokens
    // await this.protection.allowToken(this.jntrToken.address, {
    //   from: systemAddress,
    // });
    //here lets end the first auction
    let yesterdaySupply = new BN(900000);
    // let todaySupply = new BN(300000);

    //contribute yesterDay supply and end the auction
    await this.auction.contributeWithEther({
      from: accountA,
      value: yesterdaySupply,
    });
    await this.auction.auctionEnd({ from: systemAddress });

    //Made this just so that yesterdays supply is not a too big of a number(i.e 50000 * DECIMAL_NOMINATOR)

    //contribute today supply and end the auction
    let contributionInEth = [80000, 90000, 40000, 50000, 60000, 70000];

    let contributionBN = [];
    contributionInEth.forEach((element) => {
      contributionBN.push(new BN(element));
    });

    //Whitelist them
    for (let i = 0; i < contributionInEth.length; i++) {
      let isWhiteListed = await this.whiteList.isWhiteListed(accounts[i]);
      //console.log(isWhiteListed);
      let flags = 32768;
      let maxWallets = 10;

      if (!isWhiteListed) {
        await this.whiteList.addNewWallet(accounts[i], flags, maxWallets, {
          from: systemAddress,
        });
      }
    }

    for (let i = 0; i < contributionInEth.length; i++) {
      await this.auction.contributeWithEther({
        from: accounts[i],
        value: contributionBN[i],
      });
    }
    let auctionDay = await this.auction.auctionDay();

    await this.auction.auctionEnd({ from: systemAddress });

    //We will calculate the individual bonus according to this array
    let individualBonus = [0, 50, 40, 30, 20, 10];
    let individualBonusBN = [];
    individualBonus.forEach((element) => {
      individualBonusBN.push(new BN(element));
    });

    //lets get all the necessary amounts for auctionDay
    let bonusSupply = await this.auction.dayWiseSupplyBonus(auctionDay);
    let coreSupply = await this.auction.dayWiseSupplyCore(auctionDay);
    let downSideProtectioRatio = await this.auction.dayWiseDownSideProtectionRatio(
      auctionDay
    ); //Its 90%
    let totalContribution = await this.auction.dayWiseContribution(auctionDay); //total contribution that day

    //to get amountToaccount
    // accounts[amountToAccount.get(contributionInEth[i])]

    //Loop trhough and check
    for (let i = 0; i < contributionInEth.length; i++) {
      let recipet = await this.auction.disturbuteTokens(
        auctionDay,
        [accounts[i]],
        {
          from: systemAddress,
        }
      );

      let contributionByWallet = await this.auction.walletDayWiseContribution(
        auctionDay,
        accounts[i]
      );
      //Here you get the part if bonus and core supply on pro rata basis
      let accountCoreSupply = coreSupply
        .mul(contributionByWallet)
        .div(totalContribution);
      let accountBonusSupply = new BN(0);
      if (bonusSupply > 0) {
        accountBonusSupply = bonusSupply
          .mul(contributionByWallet)
          .div(totalContribution);
      }
      //This is how much user gets
      let accountCoreAndBonus = accountCoreSupply.add(accountBonusSupply); //The returnAmount
      //On return amount the user will get individual bonus

      // let individualBonusOfAccountPercentage =  //At which index the account is??
      let accountIndex = await this.auction.topContributiorIndex(
        auctionDay,
        accounts[i]
      );
      // console.log(accountIndex.toString());
      let individualBonusPercetage = individualBonusBN[accountIndex.toString()];
      // console.log(individualBonusPercetage.mul(priceDenominator).toString());
      // console.log(
      //   (await this.auction.calculateBouns(auctionDay, accounts[i])).toString()
      // );
      // console.log((await this.auction.indexReturn[2]).toString());

      let newAccountCoreAndBonus = new BN(0);
      let fees = new BN(0);
      if (individualBonusPercetage > 0) {
        newAccountCoreAndBonus = accountCoreAndBonus
          .mul(individualBonusPercetage.mul(priceDenominator))
          .div(hundreadPercentage.mul(priceDenominator));

        //calculate the fees only if they are being rewarded???
        let managementFees = await this.auction.mangmentFee(); //which is =2
        let temp = newAccountCoreAndBonus
          .mul(hundreadPercentage)
          .div(hundreadPercentage.sub(managementFees));
        fees = temp.sub(newAccountCoreAndBonus);
      }
      newAccountCoreAndBonus = newAccountCoreAndBonus.add(accountCoreAndBonus);

      //The _userAmount
      let nintyPercentOfCore = accountCoreSupply
        .mul(hundreadPercentage.sub(downSideProtectioRatio))
        .div(hundreadPercentage);

      //This event args will test if everything works as it supposed to
      expectEvent(recipet, "TokenDistrubuted", {
        _whom: accounts[i],
        dayId: auctionDay,
        _totalToken: newAccountCoreAndBonus,
        lockedToken: newAccountCoreAndBonus.sub(nintyPercentOfCore),
        _userToken: nintyPercentOfCore,
      });
    }
  });
});
//minimium for contribution with eth is 10000 wei
//if 1000 it fails
//somewhere in dividing it fails
//I dont know where

//Note: when the first auction ends the 500*Price denomitors's 1% gets added to stacking Wallet
//Keep in mind that in the first auction end the vaules being used
