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

const {
  advanceTimeAndBlock,
  advanceTime,
  takeSnapshot,
  revertToSnapshot,
} = require("./utils");

const TruffleContract = require("@truffle/contract");

const Auction = artifacts.require("Auction");
const AuctionRegistry = artifacts.require("AuctionRegistry");
const Liquidity = artifacts.require("Liquadity");
const LiquidityRegistry = artifacts.require("LiquadityRegistery");
const AuctionTagAlong = artifacts.require("AuctionTagAlong");
const AuctionRegisty = artifacts.require("TestAuctionRegistery");
const CurrencyPrices = artifacts.require("TestCurrencyPrices");
const TokenVault = artifacts.require("TokenVault");
const TokenVaultRegistry = artifacts.require("TokenVaultRegistery");
const whiteListContract = artifacts.require("WhiteList");
const WhiteListRegistry = artifacts.require("WhiteListRegistery");
const Protection = artifacts.require("AuctionProtection");
const ProtectionRegistry = artifacts.require("ProtectionRegistry");

var SmartToken = require("./bancorArtifacts/SmartToken.json");
var BancorConverterFactory = require("./bancorArtifacts/BancorConverterFactory.json");
var BancorConverter = require("./bancorArtifacts/BancorConverter.json");
var ContractRegistry = require("./bancorArtifacts/ContractRegistry.json");
var ERC20Token = require("./bancorArtifacts/ERC20Token.json");
var ContractFeatures = require("./bancorArtifacts/ContractFeatures.json");
var BancorFormula = require("./bancorArtifacts/BancorFormula.json");
var BancorNetwork = require("./bancorArtifacts/BancorNetwork.json");
var BancorNetworkPathFinder = require("./bancorArtifacts/BancorNetworkPathFinder.json");
var BancorConverterRegistry = require("./bancorArtifacts/BancorConverterRegistry.json");
var BancorConverterRegistryData = require("./bancorArtifacts/BancorConverterRegistry.json");
var EtherToken = require("./bancorArtifacts/EtherToken.json");
const { italic } = require("ansi-colors");

ContractRegistry = TruffleContract(ContractRegistry);
SmartToken = TruffleContract(SmartToken);
BancorConverterFactory = TruffleContract(BancorConverterFactory);
BancorConverter = TruffleContract(BancorConverter);
ContractFeatures = TruffleContract(ContractFeatures);
BancorFormula = TruffleContract(BancorFormula);
BancorNetwork = TruffleContract(BancorNetwork);
BancorNetworkPathFinder = TruffleContract(BancorNetworkPathFinder);
BancorConverterRegistry = TruffleContract(BancorConverterRegistry);
EtherToken = TruffleContract(EtherToken);
ERC20Token = TruffleContract(ERC20Token);
BancorConverterRegistryData = TruffleContract(BancorConverterRegistryData);

var bancorContracts = [
  SmartToken,
  BancorConverterFactory,
  BancorConverter,
  ContractRegistry,
  ContractFeatures,
  BancorFormula,
  BancorNetworkPathFinder,
  BancorNetwork,
  BancorConverterRegistry,
  EtherToken,
  BancorConverterRegistryData,
  ERC20Token,
];
const denominator = new BN(10).pow(new BN(18));

const getWithDeimals = function (amount) {
  return new BN(amount).mul(denominator);
};

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
    accountA,
    accountB,
    other1,
  ] = accounts;
  one = getWithDeimals(1);
  thousand = getWithDeimals(10000);
  hundread = getWithDeimals(100);

  const downSideProtectioRatio = new BN(90);
  const fundWalletRatio = new BN(90);
  const hundreadPercentage = new BN(100);
  beforeEach(async function () {
    //setting up bancor
    //deploy all the necessary contracts first
    bancorContracts.forEach((element) => {
      element.setProvider(web3.currentProvider);
    });
    var contractRegistry = await ContractRegistry.new({ from: accounts[0] });
    var bancorFormula = await BancorFormula.new({ from: accounts[0] });
    var contractFeatures = await ContractFeatures.new({ from: accounts[0] });
    bancorNetwork = await BancorNetwork.new(contractRegistry.address, {
      from: accounts[0],
    });
    var bancorNetworkPathFinder = await BancorNetworkPathFinder.new(
      contractRegistry.address,
      { from: accounts[0] }
    );
    var bancorConverterRegistry = await BancorConverterRegistry.new(
      contractRegistry.address,
      { from: accounts[0] }
    );
    var bancorConverterRegistryData = await BancorConverterRegistryData.new(
      contractRegistry.address,
      { from: accounts[0] }
    );
    var etherToken = await EtherToken.new("ETHTOKEN", "ETHTOKEN", {
      from: accounts[0],
    });
    BNTToken = await SmartToken.new("Bancor Token", "BNT", 18, {
      from: accounts[0],
    });

    //register all the addresses to the contractRefistry
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("ContractRegistry"),
      contractRegistry.address,
      { from: accounts[0] }
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("ContractFeatures"),
      contractFeatures.address,
      { from: accounts[0] }
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BancorFormula"),
      bancorFormula.address,
      { from: accounts[0] }
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BancorNetwork"),
      bancorNetwork.address,
      { from: accounts[0] }
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BancorNetworkPathFinder"),
      bancorNetworkPathFinder.address,
      { from: accounts[0] }
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BancorConverterRegistry"),
      bancorConverterRegistry.address,
      { from: accounts[0] }
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BancorConverterRegistryData"),
      bancorConverterRegistryData.address,
      { from: accounts[0] }
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BNTToken"),
      BNTToken.address,
      { from: accounts[0] }
    );
    //the etheretoken
    await bancorNetwork.registerEtherToken(etherToken.address, true, {
      from: accounts[0],
    });
    //set bnt as anchor token
    await bancorNetworkPathFinder.setAnchorToken(BNTToken.address, {
      from: accounts[0],
    });

    //First lets make a pair of BNT and the EtherToken itself

    var smartTokenEthBnt = await SmartToken.new("ETHBNT", "ETHBNT", 18, {
      from: accounts[0],
    });
    var converterEthBnt = await BancorConverter.new(
      smartTokenEthBnt.address,
      contractRegistry.address,
      30000,
      BNTToken.address,
      500000,
      { from: accounts[0] }
    );

    await converterEthBnt.addReserve(etherToken.address, 500000, {
      from: accounts[0],
    });
    await converterEthBnt.setConversionFee(1000, { from: accounts[0] });
    //fund the EthBnt Pool woth initial tokens
    //to do that first get those two tokens
    await BNTToken.issue(accounts[0], thousand, {
      from: accounts[0],
    });
    await etherToken.deposit({ from: accounts[0], value: one });
    //now fund the pool

    await BNTToken.transfer(converterEthBnt.address, one, {
      from: accounts[0],
    });
    await etherToken.transfer(converterEthBnt.address, one, {
      from: accounts[0],
    });

    //issue initial smart tokens equal to usd equivalent of the both reserve
    await smartTokenEthBnt.issue(accounts[0], one.mul(new BN(2)), {
      from: accounts[0],
    });

    //activate the pool
    //the pool would be invalid if it is not the owner of the corresponding smart token
    await smartTokenEthBnt.transferOwnership(converterEthBnt.address, {
      from: accounts[0],
    });
    await converterEthBnt.acceptTokenOwnership({
      from: accounts[0],
    });

    //Let's try and see if this eth-bnt pool works
    await etherToken.deposit({ from: accounts[3], value: 10 });
    await etherToken.approve(converterEthBnt.address, 10, { from: accounts[3] });

    await converterEthBnt.quickConvert2(
      [etherToken.address, smartTokenEthBnt.address, BNTToken.address],
      10,
      1,
      ZERO_ADDRESS,
      0,
      { from: accounts[3] }
    );

    //Now make a pair between the JNtR and BNT
    this.smartToken = await SmartToken.new("BNTJNTR", "BNTJNTR", 18, {
      from: accounts[0],
    });
    this.bancorConverterFactory = await BancorConverterFactory.new({
      from: accounts[0],
    });

    this.jntrToken = await ERC20Token.new("JNTR", "JNTR", 18, thousand, {
      from: accounts[0],
    });

    //the conoverter contract
    let receipt = await this.bancorConverterFactory.createConverter(
      this.smartToken.address,
      contractRegistry.address,
      30000,
      BNTToken.address,
      500000,
      { from: accounts[0] }
    );

    this.converter = await BancorConverter.at(receipt.logs[0].args._converter, {
      from: accounts[0],
    });

    await this.converter.acceptOwnership({
      from: accounts[0],
    }); //We need to do this if we are using the bancorConverter factory
    //It accepts the ownership to account[0]

    await this.converter.addReserve(this.jntrToken.address, 500000, {
      from: accounts[0],
    });
    await this.converter.setConversionFee(1000, {
      from: accounts[0],
    });

    //fund pool with initial tokens

    await this.jntrToken.transfer(this.converter.address, one, {
      from: accounts[0],
    });
    await BNTToken.transfer(this.converter.address, one, {
      from: accounts[0],
    });

    //issue initial liquidity tokens

    await this.smartToken.issue(accounts[0], one.mul(new BN(2)), {
      from: accounts[0],
    });

    //Activate the system

    await this.smartToken.transferOwnership(this.converter.address, {
      from: accounts[0],
    });
    await this.converter.acceptTokenOwnership({
      from: accounts[0],
    });

    //Add the converter to the registry(TODO)

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

    //setup for Auction
    //auction registry
    this.auctionRegistry = await AuctionRegisty.new(
      systemAddress,
      multiSigPlaceHolder,
      { from: primaryOwner }
    );
    //tagAlong
    this.tagAlong = await AuctionTagAlong.new(
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
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

    //set the paths
    this.liquidity.setTokenPath(0, ethToMainToken, { from: systemAddress });
    this.liquidity.setTokenPath(1, baseTokenToMainToken, { from: systemAddress });
    this.liquidity.setTokenPath(2, mainTokenTobaseToken, { from: systemAddress });
    this.liquidity.setTokenPath(3, ethToBaseToken, { from: systemAddress });
    this.liquidity.setTokenPath(4, baseTokenToEth, { from: systemAddress });
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
      web3.utils.fromAscii("WHITE_LIST"),
      this.whiteList.address,
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
      web3.utils.fromAscii("AUCTION_PROTECTION"),
      this.protection.address,
      {
        from: primaryOwner,
      }
    );
    //the startTime would be now from my understnding
    //th minAuctionTime would be less than a day
    let startTime = await time.latest();
    let minAuctionTime = time.duration.hours(23);
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
    //Add liquidity address as a spender in tokenVault
    await this.tokenVault.addSpender(this.liquidity.address, {
      from: multiSigPlaceHolder,
    });

    //Whitelist accountA and AccountB
    let flags = 3; // KYC|AML
    let maxWallets = 10;
    await this.whiteList.addNewWallet(accountA, flags, maxWallets, {
      from: systemAddress,
    });
    await this.whiteList.addNewWallet(accountB, flags, maxWallets, {
      from: systemAddress,
    });
  });
  it("Auction should be initialized correctly", async function () {
    // console.log(await this.auction.lastAuctionStart());
    //90% goes to DownsideProtection
    expect(
      await this.auction.dayWiseDownSideProtectionRatio(1)
    ).to.be.bignumber.equal(downSideProtectioRatio);
    //90% of remaining 10% i.e. 9% goes to comapanyWallet
    expect(await this.auction.fundWalletRatio()).to.be.bignumber.equal(
      fundWalletRatio
    );
    // //To make sure everybody has everybody's address
    // console.log(await this.protection.auctionAddress());
    // console.log(await this.protection.auctionAddress());
    // console.log(this.auction.address);
  });
  it("should contribute with ether correclty", async function () {
    let contributionAmount = one;

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
    // console.log(await web3.eth.getBalance(companyFundWallet));
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
    console.log(sideReserveRatio.toString());
    let sideReserveAmount = reserveAmount
      .mul(sideReserveRatio)
      .div(hundreadPercentage);

    expect(await liquidityEthTracker.delta()).to.be.bignumber.equal(
      sideReserveAmount
    );
    //for the remaining 0.1% gets converted into jntr with help of bancor and given to tokenVault
    //These tests are done already in the liquidity so choosing not to do it again
  });
  it("should contribute with tokens correctly", async function () {
    //I feel like here the getCurrencyPrices would be needed
    //First lets give our boy some jntr
    let contributionAmount = one;
    await this.jntrToken.transfer(accountA, contributionAmount, {
      from: accounts[0],
    });
    //Noe the contribution starts
    await this.jntrToken.approve(this.auction.address, contributionAmount, {
      from: accountA,
    });

    //Also we would need to allow the token becuse you cannot lock tokens in protection if token is not allowed
    await this.protection.allowToken(this.jntrToken.address, {
      from: systemAddress,
    });

    await this.auction.contributeWithToken(
      this.jntrToken.address,
      contributionAmount,
      {
        from: accountA,
      }
    );
    //I am being lazy and checking current balances of address to be equal to expected amount
    //Actually it should be the delta

    //90% of it goes to the downside protection
    //tokens gets locked
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

    // console.log((await this.jntrToken.balanceOf(companyFundWallet)).toString());
    // console.log(
    //   (await this.jntrToken.balanceOf(this.protection.address)).toString()
    // );
    // console.log(
    //   (await this.jntrToken.balanceOf(this.liquidity.address)).toString()
    // );
    expect(
      await this.jntrToken.balanceOf(this.protection.address)
    ).to.be.bignumber.equal(downSideAmount);
    expect(
      await this.jntrToken.balanceOf(companyFundWallet)
    ).to.be.bignumber.equal(companyFundWalletAmount);
    expect(
      await this.jntrToken.balanceOf(this.liquidity.address)
    ).to.be.bignumber.equal(reserveAmount);
  });

  //Next I need to check what happens when auction ends
  //Also after it is updated I need to check the bonus calculation
  //That includes two things "FundAdded" and distributeTokens
});
