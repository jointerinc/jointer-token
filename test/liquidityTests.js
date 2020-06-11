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

const TruffleContract = require("@truffle/contract");

const Liquidity = artifacts.require("Liquadity");
const AuctionTagAlong = artifacts.require("AuctionTagAlong");
const AuctionRegisty = artifacts.require("TestAuctionRegistery");
const TokenVault = artifacts.require("TokenVault");
const TokenVaultRegistry = artifacts.require("TokenVaultRegistery");

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
    //setting up bancor
    //deploy all the necessary contracts first
    bancorContracts.forEach((element) => {
      element.setProvider(web3.currentProvider);
    });
    var contractRegistry = await ContractRegistry.new({from: accounts[0]});
    var bancorFormula = await BancorFormula.new({from: accounts[0]});
    var contractFeatures = await ContractFeatures.new({from: accounts[0]});
    var bancorNetwork = await BancorNetwork.new(contractRegistry.address, {
      from: accounts[0],
    });
    var bancorNetworkPathFinder = await BancorNetworkPathFinder.new(
      contractRegistry.address,
      {from: accounts[0]}
    );
    var bancorConverterRegistry = await BancorConverterRegistry.new(
      contractRegistry.address,
      {from: accounts[0]}
    );
    var bancorConverterRegistryData = await BancorConverterRegistryData.new(
      contractRegistry.address,
      {from: accounts[0]}
    );
    var etherToken = await EtherToken.new("ETHTOKEN", "ETHTOKEN", {
      from: accounts[0],
    });
    var BNTToken = await SmartToken.new("Bancor Token", "BNT", 18, {
      from: accounts[0],
    });

    //register all the addresses to the contractRefistry
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("ContractRegistry"),
      contractRegistry.address,
      {from: accounts[0]}
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("ContractFeatures"),
      contractFeatures.address,
      {from: accounts[0]}
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BancorFormula"),
      bancorFormula.address,
      {from: accounts[0]}
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BancorNetwork"),
      bancorNetwork.address,
      {from: accounts[0]}
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BancorNetworkPathFinder"),
      bancorNetworkPathFinder.address,
      {from: accounts[0]}
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BancorConverterRegistry"),
      bancorConverterRegistry.address,
      {from: accounts[0]}
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BancorConverterRegistryData"),
      bancorConverterRegistryData.address,
      {from: accounts[0]}
    );
    await contractRegistry.registerAddress(
      web3.utils.asciiToHex("BNTToken"),
      BNTToken.address,
      {from: accounts[0]}
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
      {from: accounts[0]}
    );

    await converterEthBnt.addReserve(etherToken.address, 500000, {
      from: accounts[0],
    });
    await converterEthBnt.setConversionFee(1000, {from: accounts[0]});
    //fund the EthBnt Pool woth initial tokens
    //to do that first get those two tokens
    await BNTToken.issue(accounts[0], thousand, {
      from: accounts[0],
    });
    await etherToken.deposit({from: accounts[0], value: one});
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
    await etherToken.deposit({from: accounts[3], value: 10});
    await etherToken.approve(converterEthBnt.address, 10, {from: accounts[3]});

    await converterEthBnt.quickConvert2(
      [etherToken.address, smartTokenEthBnt.address, BNTToken.address],
      10,
      1,
      ZERO_ADDRESS,
      0,
      {from: accounts[3]}
    );

    // console.log(
    //   (
    //     await BNTToken.balanceOf(accounts[3], {
    //       from: accounts[0],
    //     })
    //   ).toString()
    // );
    // console.log("ether Token:\t" + etherToken.address);
    // console.log("BNT Token:\t" + BNTToken.address);

    // console.log("converter EthBNt Token:\t" + converterEthBnt.address);

    // console.log("smartToken EthBNt Token:\t" + smartTokenEthBnt.address);
    // var otherArr = [
    //   "BNTToken",
    //   "BancorConverterRegistryData",
    //   "BancorConverterRegistry",
    //   "BancorNetworkPathFinder",
    //   "BancorNetwork",
    //   "BancorFormula",
    //   "ContractRegistry",
    //   "ContractFeatures",
    // ];
    // for (let i = 0; i < otherArr.length; i++) {
    //   console.log(
    //     await contractRegistry.addressOf(web3.utils.asciiToHex(otherArr[i]))
    //   );
    // }
    // var arr = [
    //   contractRegistry,
    //   BNTToken,
    //   bancorConverterRegistryData,
    //   contractFeatures,
    //   bancorFormula,
    //   bancorNetwork,
    //   bancorNetworkPathFinder,
    //   bancorConverterRegistry,
    // ];
    // arr.forEach((element) => {
    //   console.log(element.address);
    // });

    // console.log(
    //   await bancorConverterRegistry.isConverterValid(converterEthBnt.address),
    //   {from: accounts[0]}
    // );
    //Add this converter to registry
    // await bancorConverterRegistry.addConverter(converterEthBnt.address, {
    //   from: accounts[0],
    // });

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
      {from: accounts[0]}
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

    //Add the converter to the registry

    // await bancorConverterRegistry.addConverter(this.converter.address, {
    //   from: accounts[0],
    // });
    //Trying it out

    await this.jntrToken.transfer(accounts[2], 10, {
      from: accounts[0],
    });
    await this.jntrToken.approve(this.converter.address, 10, {
      from: accounts[2],
    });
    await this.converter.quickConvert2(
      [this.jntrToken.address, this.smartToken.address, BNTToken.address],
      10,
      1,
      ZERO_ADDRESS,
      0,
      {from: accounts[2]}
    );
    // await etherToken.deposit({from: accounts[2], value: 10});

    // console.log(
    //   (await BNTToken.balanceOf(accounts[2]),
    //   {
    //     from: accounts[0],
    //   }).toString()
    // );

    //Let's see if all things are connected
    //Let's buy jntr from ethToken
    // console.log("ether Token:\t" + etherToken.address);
    // console.log("BNT Token:\t" + BNTToken.address);
    // console.log("JNTR Token:\t" + this.jntrToken.address);
    // console.log("converter EthBNt Token:\t" + converterEthBnt.address);
    // console.log("converter jntrBnt Token:\t" + this.converter.address);
    // console.log("smartToken EthBNt Token:\t" + smartTokenEthBnt.address);
    // console.log("smartToken jntrBnt Token:\t" + this.smartToken.address);

    // let path = await bancorNetworkPathFinder.generatePath(
    //   etherToken.address,
    //   this.jntrToken.address,
    //   {
    //     from: accounts[0],
    //   }
    // );
    // console.log("\n\npath\t" + path);

    await this.converter.quickConvert2(
      [
        etherToken.address,
        smartTokenEthBnt.address,
        BNTToken.address,
        this.smartToken.address,
        this.jntrToken.address,
      ],
      10,
      1,
      ZERO_ADDRESS,
      0,
      {
        from: accounts[4],
        value: 10,
      }
    );
    // console.log(
    //   (
    //     await this.jntrToken.balanceOf(accounts[4], {
    //       from: accounts[0],
    //     })
    //   ).toString()
    // );
    //base token is the BNT
    // the main token is the JNTR
    let ethToMainToken = [
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
    let baseLinePrice = 100000;
    //setup liquidity
    //auction registry
    this.auctionRegistry = await AuctionRegisty.new(
      systemAddress,
      multiSigPlaceHolder,
      {from: primaryOwner}
    );
    //tagAlong
    this.tagAlong = await AuctionTagAlong.new(
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      {from: primaryOwner}
    );
    //the TokenVault
    var tokenVaultRegistry = await TokenVaultRegistry.new(
      systemAddress,
      multiSigPlaceHolder,
      {from: primaryOwner}
    );
    let tempTokenVault = await TokenVault.new({from: primaryOwner});
    await tokenVaultRegistry.addVersion(1, tempTokenVault.address, {
      from: primaryOwner,
    });
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
    this.liquidity = await Liquidity.new(
      this.converter.address,
      BNTToken.address,
      this.jntrToken.address,
      this.smartToken.address,
      systemAddress,
      multiSigPlaceHolder,
      this.auctionRegistry.address,
      baseLinePrice,
      ethToMainToken,
      baseTokenToMainToken,
      mainTokenTobaseToken,
      ethToBaseToken,
      baseTokenToEth
    );
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
  });
  it("Bancor should setup correctly", async function () {});
  it("contributing with Eth should work correctly", async function () {
    await this.liquidity.contributeWithEther({
      from: auctionPlaceHolder,
      value: 10000,
    });
    let vaultBalanceJntr = await this.jntrToken.balanceOf(
      this.tokenVault.address
    );
    console.log(vaultBalanceJntr.toString());
  });
});
