const AuctionRegisty = artifacts.require("AuctionRegistery");
const MultiSigGovernance = artifacts.require("MultiSigGovernance");
const WhiteListRegistery = artifacts.require("WhiteListRegistery");
const WhiteList = artifacts.require("WhiteList");
const MainToken = artifacts.require("MainToken");
const TokenVaultRegistery = artifacts.require("TokenVaultRegistery");
const TokenVault = artifacts.require("TokenVault");

const TagAlongRegistry = artifacts.require("TagAlongRegistry");
const TagAlong = artifacts.require("AuctionTagAlong");


/* This all setting for ropsten */


// const ownerWallet = "0xEcF2659415FD22A46a83a1592558c63c00968C89";
// const WhiteListSecondary = "0xF30b7e1BB257F9D4C83f5fB18e47c6dcD60C54da";
// const auctionSecondary = "0x7F803ca9cD6721b7687767E1B6f1533e966BD524";
// const otherSecondary = "0x38e07d1C3b3e78F065dEC790a9d3b5553F602E14";


const ownerWallet = "0x153d9909f3131e6a09390b33f7a67d40418c0318";
const WhiteListSecondary = "0xf4c402bf860877183e46a19382a7847ca22b51d4";
const auctionSecondary = "0xef7f7c4b5205a91a358de8bd8beb4345c3038922";
const otherSecondary = "0x98452666814c73ebff150f3d55ba4230a6c73f77";

const curenncyContract = "0xf79bCD438Bb58A4C0A8B6fA1fAB79795BED545AD";

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
const vaultCode = "0x5641554c54000000000000000000000000000000000000000000000000000000";

const tagAlongCode = "0x5441475f414c4f4e470000000000000000000000000000000000000000000000";


const ByPassCode = 8195;

module.exports = async function (deployer) {
  // Multi Governance
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

  await deployer.deploy(
    WhiteList,
    WhiteListSecondary,
    MultiSigGovernance.address,
    {
      from: ownerWallet,
    }
  );

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
  await deployer.deploy(
    TokenVault,
    otherSecondary,
    MultiSigGovernance.address,
    {
      from: ownerWallet,
    }
  );
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
  await whiteListInstance.addNewWallet(TokenVault, ByPassCode, 0, {
    from: WhiteListSecondary,
  });

  await auctionRegistyInstance.registerContractAddress(
    vaultCode,
    tokenVaultProxyAdress,
    { from: otherSecondary }
  );

  await deployer.deploy(
    TagAlongRegistry,
    WhiteListSecondary,
    MultiSigGovernance.address,
    {
      from: ownerWallet,
    }
  );

  tagAlongRegistryInstance = TagAlongRegistry.deployed();


  

  //console.log(register_white);
};
