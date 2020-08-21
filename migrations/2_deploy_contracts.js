const TruffleContract = require("@truffle/contract");

const AuctionRegisty = artifacts.require("AuctionRegistery");
const MultiSigGovernance = artifacts.require("MultiSigGovernance");
const WhiteListRegistery = artifacts.require("WhiteListRegistery");
const WhiteList = artifacts.require("WhiteList");
const MainToken = artifacts.require("MainToken");
const TokenVaultRegistery = artifacts.require("TokenVaultRegistery");
const TokenVault = artifacts.require("TokenVault");

const TagAlongRegistry = artifacts.require("TagAlongRegistry");
const TagAlong = artifacts.require("AuctionTagAlong");

const ProtectionRegistry = artifacts.require("ProtectionRegistry");
const AuctionProtection = artifacts.require("AuctionProtection");


const SmartToken = TruffleContract(require("../test/bancorArtifacts/SmartToken.json"));
const BancorConverter = TruffleContract(require("../test/bancorArtifacts/BancorConverter.json"));

/* This all setting for ropsten */

// const ownerWallet = "0xEcF2659415FD22A46a83a1592558c63c00968C89";
// const WhiteListSecondary = "0xF30b7e1BB257F9D4C83f5fB18e47c6dcD60C54da";
// const auctionSecondary = "0x7F803ca9cD6721b7687767E1B6f1533e966BD524";
// const otherSecondary = "0x38e07d1C3b3e78F065dEC790a9d3b5553F602E14";

const ownerWallet = "0x153d9909f3131e6a09390b33f7a67d40418c0318";
const WhiteListSecondary = "0xf4c402bf860877183e46a19382a7847ca22b51d4";
const auctionSecondary = "0xef7f7c4b5205a91a358de8bd8beb4345c3038922";
const otherSecondary = "0x98452666814c73ebff150f3d55ba4230a6c73f77";

/* currency contarct */
const curenncyContract = "0xf79bCD438Bb58A4C0A8B6fA1fAB79795BED545AD"; // change according
const bancorNetwork = "0x9A33CCE338acF6E57282aCB314c60e2d66B7DDFC"; //chnage according
const smartToken = "0x9A33CCE338acF6E57282aCB314c60e2d66B7DDFC"; // change according
const bancorConverter = "0x738dA66CE008313cC0594DaCbc5c7EA36DA3E572"; // change according 

const MainTokenHoldBack = 0;
const EtnTokenHoldBack = 0;
const StockTokenHoldBack = 0;
const MainMaturityDays = 0;
const EtnMaturityDays = 0;
const StockMaturityDays = 0;

const mainPreMintAddress = [ownerWallet];
const mainPreMintAmount = [web3.utils.toWei("10000000")];

const mainTokenName = "Jointer Token";
const mainTokenSymbol = "JNTR";

const whiteListCode =
  "0x57484954455f4c49535400000000000000000000000000000000000000000000";

const mainTokenCode =
  "0x4d41494e5f544f4b454e00000000000000000000000000000000000000000000";

const currencyCode =
  "0x43555252454e4359000000000000000000000000000000000000000000000000";

const vaultCode =
  "0x5641554c54000000000000000000000000000000000000000000000000000000";

const tagAlongCode =
  "0x5441475f414c4f4e470000000000000000000000000000000000000000000000";

const protectionCode =
  "0x41554354494f4e5f50524f54454354494f4e0000000000000000000000000000";

const ByPassCode = 8195;
const bancorCode = 16384;

module.exports = async function (deployer) {


  await deployer.deploy(
    MultiSigGovernance,
    [ownerWallet, WhiteListSecondary, otherSecondary, auctionSecondary],
    2,
    {
      from: ownerWallet,
    }
  );

  multiSigGovernanceInstance = await MultiSigGovernance.deployed();

  await deployer.deploy(
    AuctionRegisty,
    otherSecondary,
    MultiSigGovernance.address,
    { from: ownerWallet }
  );

  auctionRegistyInstance = await AuctionRegisty.deployed();

  await deployer.deploy(
    WhiteListRegistery,
    WhiteListSecondary,
    MultiSigGovernance.address,
    {
      from: ownerWallet,
    }
  );

  whiteListRegisteryInstance = await WhiteListRegistery.deployed();

  await deployer.deploy(WhiteList, {
    from: ownerWallet,
  });

  await whiteListRegisteryInstance.addVersion(1, WhiteList.address, {
    from: ownerWallet,
  });

  await whiteListRegisteryInstance.createProxy(
    1,
    ownerWallet,
    WhiteListSecondary,
    MultiSigGovernance.address,
    MainTokenHoldBack,
    EtnTokenHoldBack,
    StockTokenHoldBack,
    MainMaturityDays,
    EtnMaturityDays,
    StockMaturityDays,
    AuctionRegisty.address,
    {
      from: ownerWallet,
    }
  );

  whiteListProxyAdress = await whiteListRegisteryInstance.proxyAddress();
  whiteListInstance = await WhiteList.at(whiteListProxyAdress);
  txHash = await whiteListInstance.addNewWallet(ownerWallet, ByPassCode, 10, {
    from: WhiteListSecondary,
  });

  await auctionRegistyInstance.registerContractAddress(
    whiteListCode,
    whiteListProxyAdress,
    { from: otherSecondary }
  );

  await deployer.deploy(
    MainToken,
    mainTokenName,
    mainTokenSymbol,
    otherSecondary,
    MultiSigGovernance.address,
    AuctionRegisty.address,
    mainPreMintAddress,
    mainPreMintAmount,
    {
      from: ownerWallet,
    }
  );

  mainTokenInstance = await MainToken.deployed();
  await auctionRegistyInstance.registerContractAddress(
    mainTokenCode,
    MainToken.address,
    { from: otherSecondary }
  );
  await auctionRegistyInstance.registerContractAddress(
    currencyCode,
    curenncyContract,
    { from: otherSecondary }
  );

  await deployer.deploy(
    TokenVaultRegistery,
    otherSecondary,
    MultiSigGovernance.address,
    {
      from: ownerWallet,
    }
  );

  tokenVaultRegisteryInstance = await TokenVaultRegistery.deployed();

  await deployer.deploy(TokenVault, {
    from: ownerWallet,
  });
  await tokenVaultRegisteryInstance.addVersion(1, TokenVault.address, {
    from: ownerWallet,
  });
  await tokenVaultRegisteryInstance.createProxy(
    1,
    ownerWallet,
    otherSecondary,
    MultiSigGovernance.address,
    AuctionRegisty.address,
    {
      from: ownerWallet,
    }
  );

  tokenVaultProxyAdress = await tokenVaultRegisteryInstance.proxyAddress();
  tokenVaultInstance = await TokenVault.at(tokenVaultProxyAdress);

  await whiteListInstance.addNewWallet(tokenVaultProxyAdress, ByPassCode, 0, {
    from: WhiteListSecondary,
  });

  await auctionRegistyInstance.registerContractAddress(
    vaultCode,
    tokenVaultProxyAdress,
    { from: otherSecondary }
  );

  await deployer.deploy(
    TagAlongRegistry,
    otherSecondary,
    MultiSigGovernance.address,
    {
      from: ownerWallet,
    }
  );

  tagAlongRegistryInstance = await TagAlongRegistry.deployed();

  await deployer.deploy(TagAlong, {
    from: ownerWallet,
  });

  await tagAlongRegistryInstance.addVersion(1, TagAlong.address);

  await tagAlongRegistryInstance.createProxy(
    1,
    ownerWallet,
    otherSecondary,
    MultiSigGovernance.address,
    AuctionRegisty.address,
    {
      from: ownerWallet,
    }
  );

  tagAlongProxyAddress = await tagAlongRegistryInstance.proxyAddress();

  tagAlongInstance = await TagAlong.at(tagAlongProxyAddress);

  await whiteListInstance.addNewWallet(tagAlongProxyAddress, ByPassCode, 0, {
    from: WhiteListSecondary,
  });

  await auctionRegistyInstance.registerContractAddress(
    tagAlongCode,
    tagAlongProxyAddress,
    { from: otherSecondary }
  );

  await deployer.deploy(
    ProtectionRegistry,
    otherSecondary,
    MultiSigGovernance.address,
    {
      from: ownerWallet,
    }
  );

  protectionRegisteryInstance = await ProtectionRegistry.deployed();

  await deployer.deploy(AuctionProtection, {
    from: ownerWallet,
  });

  await protectionRegisteryInstance.addVersion(1, AuctionProtection.address);

  await protectionRegisteryInstance.createProxy(
    1,
    ownerWallet,
    otherSecondary,
    MultiSigGovernance.address,
    AuctionRegisty.address,
    {
      from: ownerWallet,
    }
  );

  protectionProxyAddress = await protectionRegisteryInstance.proxyAddress();
  
  protectionInstance = await AuctionProtection.at(protectionProxyAddress);

  await whiteListInstance.addNewWallet(protectionProxyAddress, ByPassCode, 0, {
    from: WhiteListSecondary,
  });

  await auctionRegistyInstance.registerContractAddress(
    protectionCode,
    protectionProxyAddress,
    { from: otherSecondary }
  );

  relayTokenInstance = await SmartToken.at(smartToken); 
  await relayTokenInstance.issue(tagAlongProxyAddress,web3.utils.toWei(1000));
    
  await whiteListInstance.addNewWallet(bancorNetwork, bancorCode, 0, {
    from: WhiteListSecondary,
  });

  await whiteListInstance.addNewWallet(bancorConverter, bancorCode, 0, {
    from: WhiteListSecondary,
  });
  converterInsatnce = await BancorConverter.at(bancorConverter);
  await converterInsatnce.addconnector(Main);

  
//   console.log("MultiSigGovernance",MultiSigGovernance.address);
//   console.log("AuctionRegisty",AuctionRegisty.address);



  //console.log(register_white);
};
