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


const LiquadityRegistery = artifacts.require("LiquadityRegistery");
const Liquadity = artifacts.require("Liquadity");

const AuctionProxyRegistry = artifacts.require("AuctionProxyRegistry");
const Auction = artifacts.require("Auction");


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
const bancorNetwork =    "0xE3042915EeaE7974bFe5a2653911d7fa05003eea"; //chnage according
const smartToken =       "0x71cec6E58f12c28a9f1Fb96Ee64DA8328dD9F23C"; // change according
const bancorConverter =  "0xddCE9B829f527Fc4a4d622B1cb4dD5c009d04764"; // change according 
const baseToken =        "0xD368b98d03855835E2923Dc000b3f9c2EBF1b27b";

const MainTokenHoldBack = 0;
const EtnTokenHoldBack = 0;
const StockTokenHoldBack = 0;
const MainMaturityDays = 0;
const EtnMaturityDays = 0;
const StockMaturityDays = 0;

const mainPreMintAddress = [ownerWallet, bancorConverter];
const mainPreMintAmount = [web3.utils.toWei("10000000"), web3.utils.toWei("100000")];
const relayTokenAmount = web3.utils.toWei("1000");
const mainTokenName = "Jointer Token";
const mainTokenSymbol = "JNTR";

const baseLinePrice = 226210000000;
const baseTokenAmout =  "4420671057866584147";

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

const liquadityCode = "0x4c49515541444954590000000000000000000000000000000000000000000000";

const auctionCode = "0x41554354494f4e00000000000000000000000000000000000000000000000000";

const ByPassCode = 8195;
const bancorCode = 16384;


// ["0xD368b98d03855835E2923Dc000b3f9c2EBF1b27b","0x71cec6E58f12c28a9f1Fb96Ee64DA8328dD9F23C","0xC6e100530C7344631F22eEd05ef66f8AE9ddD68D"]

// ["0xC6e100530C7344631F22eEd05ef66f8AE9ddD68D","0x71cec6E58f12c28a9f1Fb96Ee64DA8328dD9F23C","0xD368b98d03855835E2923Dc000b3f9c2EBF1b27b"]

// ["0xD368b98d03855835E2923Dc000b3f9c2EBF1b27b","0x71cec6E58f12c28a9f1Fb96Ee64DA8328dD9F23C","0xC6e100530C7344631F22eEd05ef66f8AE9ddD68D","0x71cec6E58f12c28a9f1Fb96Ee64DA8328dD9F23C","0xD368b98d03855835E2923Dc000b3f9c2EBF1b27b"]

module.exports = async function (deployer) {

  // await BancorConverter.setProvider(web3.currentProvider);
  // converterInstance = await BancorConverter.at(bancorConverter);
  // console.log(await converterInstance.bancorX());

  // await SmartToken.setProvider(web3.currentProvider);
  // relayTokenInstance = await SmartToken.at(smartToken);
  // await relayTokenInstance.issue(tagAlongProxyAddress,relayTokenAmount, {
  //   from: ownerWallet
  // });

  // await converterInstance.addConnector(MainToken.address, "500000", false, {
  //   from: ownerWallet
  // });

  // await deployer.deploy(
  //   MultiSigGovernance,
  //   [ownerWallet,WhiteListSecondary, otherSecondary, auctionSecondary],
  //   2,{
  //     from: ownerWallet,
  //   }
  // );

  // multiSigGovernanceInstance = await MultiSigGovernance.deployed();
  // console.log("MultiSigGovernance",MultiSigGovernance.address);

  // await deployer.deploy(
  //   AuctionRegisty,
  //   otherSecondary,
  //   MultiSigGovernance.address, {
  //     from: ownerWallet
  //   }
  // );

  
  // console.log("AuctionRegisty",AuctionRegisty.address);
  // auctionRegistyInstance = await AuctionRegisty.deployed();

  // await deployer.deploy(
  //   WhiteListRegistery,
  //   WhiteListSecondary,
  //   MultiSigGovernance.address, {
  //     from: ownerWallet,
  //   }
  // );

  // whiteListRegisteryInstance = await WhiteListRegistery.deployed();

  // await deployer.deploy(WhiteList, {
  //   from: ownerWallet,
  // });

  // await whiteListRegisteryInstance.addVersion(1, WhiteList.address, {
  //   from: ownerWallet,
  // });

  // await whiteListRegisteryInstance.createProxy(
  //   1,
  //   ownerWallet,
  //   WhiteListSecondary,
  //   MultiSigGovernance.address,
  //   MainTokenHoldBack,
  //   EtnTokenHoldBack,
  //   StockTokenHoldBack,
  //   MainMaturityDays,
  //   EtnMaturityDays,
  //   StockMaturityDays,
  //   AuctionRegisty.address, {
  //     from: ownerWallet,
  //   }
  // );

  // whiteListProxyAdress = await whiteListRegisteryInstance.proxyAddress();
  // whiteListInstance = await WhiteList.at(whiteListProxyAdress);
  // console.log("WhiteList",whiteListProxyAdress);
    
  // txHash = await whiteListInstance.addNewWallet(ownerWallet, ByPassCode, 10, {
  //   from: WhiteListSecondary,
  // });

  // await whiteListInstance.addNewWallet(bancorNetwork, bancorCode, 0, {
  //   from: WhiteListSecondary,
  // });
  // await whiteListInstance.addNewWallet(bancorConverter, bancorCode, 0, {
  //   from: WhiteListSecondary,
  // });

  // await auctionRegistyInstance.registerContractAddress(
  //   whiteListCode,
  //   whiteListProxyAdress, {
  //     from: otherSecondary
  //   }
  // );

  // await deployer.deploy(
  //   MainToken,
  //   mainTokenName,
  //   mainTokenSymbol,
  //   otherSecondary,
  //   MultiSigGovernance.address,
  //   AuctionRegisty.address,
  //   mainPreMintAddress,
  //   mainPreMintAmount, {
  //     from: ownerWallet,
  //   }
  // );

  // mainTokenInstance = await MainToken.deployed();
  // await auctionRegistyInstance.registerContractAddress(
  //   mainTokenCode,
  //   MainToken.address, {
  //     from: otherSecondary
  //   }
  // );
  // await auctionRegistyInstance.registerContractAddress(
  //   currencyCode,
  //   curenncyContract, {
  //     from: otherSecondary
  //   }
  // );

  // console.log("MainToken",MainToken.address);
  

  // await deployer.deploy(
  //   TokenVaultRegistery,
  //   otherSecondary,
  //   MultiSigGovernance.address, {
  //     from: ownerWallet,
  //   }
  // );

  // tokenVaultRegisteryInstance = await TokenVaultRegistery.deployed();

  // await deployer.deploy(TokenVault, {
  //   from: ownerWallet,
  // });
  // await tokenVaultRegisteryInstance.addVersion(1, TokenVault.address, {
  //   from: ownerWallet,
  // });
  // await tokenVaultRegisteryInstance.createProxy(
  //   1,
  //   ownerWallet,
  //   otherSecondary,
  //   MultiSigGovernance.address,
  //   AuctionRegisty.address, {
  //     from: ownerWallet,
  //   }
  // );

  // tokenVaultProxyAdress = await tokenVaultRegisteryInstance.proxyAddress();
  // tokenVaultInstance = await TokenVault.at(tokenVaultProxyAdress);

  // await whiteListInstance.addNewWallet(tokenVaultProxyAdress, ByPassCode, 0, {
  //   from: WhiteListSecondary,
  // });
  // console.log("tokenVaultProxyAdress",tokenVaultProxyAdress);
  
  // await auctionRegistyInstance.registerContractAddress(
  //   vaultCode,
  //   tokenVaultProxyAdress, {
  //     from: otherSecondary
  //   }
  // );

  // await deployer.deploy(
  //   TagAlongRegistry,
  //   otherSecondary,
  //   MultiSigGovernance.address, {
  //     from: ownerWallet,
  //   }
  // );

  // tagAlongRegistryInstance = await TagAlongRegistry.deployed();

  // await deployer.deploy(TagAlong, {
  //   from: ownerWallet,
  // });

  // await tagAlongRegistryInstance.addVersion(1, TagAlong.address);

  // await tagAlongRegistryInstance.createProxy(
  //   1,
  //   ownerWallet,
  //   otherSecondary,
  //   MultiSigGovernance.address,
  //   AuctionRegisty.address, {
  //     from: ownerWallet,
  //   }
  // );

  // tagAlongProxyAddress = await tagAlongRegistryInstance.proxyAddress();

  // tagAlongInstance = await TagAlong.at(tagAlongProxyAddress);

  // await whiteListInstance.addNewWallet(tagAlongProxyAddress, ByPassCode, 0, {
  //   from: WhiteListSecondary,
  // });

  // await auctionRegistyInstance.registerContractAddress(
  //   tagAlongCode,
  //   tagAlongProxyAddress, {
  //     from: otherSecondary
  //   }
  // );
  // console.log("tagAlongProxyAddress",tagAlongProxyAddress);

  // await deployer.deploy(
  //   ProtectionRegistry,
  //   otherSecondary,
  //   MultiSigGovernance.address, {
  //     from: ownerWallet,
  //   }
  // );

  // protectionRegisteryInstance = await ProtectionRegistry.deployed();

  // await deployer.deploy(AuctionProtection, {
  //   from: ownerWallet,
  // });

  // await protectionRegisteryInstance.addVersion(1, AuctionProtection.address);

  // await protectionRegisteryInstance.createProxy(
  //   1,
  //   ownerWallet,
  //   otherSecondary,
  //   MultiSigGovernance.address,
  //   AuctionRegisty.address, {
  //     from: ownerWallet,
  //   }
  // );

  // protectionProxyAddress = await protectionRegisteryInstance.proxyAddress();

  // protectionInstance = await AuctionProtection.at(protectionProxyAddress);

  // await whiteListInstance.addNewWallet(protectionProxyAddress, ByPassCode, 0, {
  //   from: WhiteListSecondary,
  // });

  // await auctionRegistyInstance.registerContractAddress(
  //   protectionCode,
  //   protectionProxyAddress, {
  //     from: otherSecondary
  //   }
  // );

  // console.log("protectionProxyAddress",protectionProxyAddress);
  // await SmartToken.setProvider(web3.currentProvider);
  // relayTokenInstance = await SmartToken.at(smartToken);
  // baseTokenInstance = await SmartToken.at(baseToken);

  // await baseTokenInstance.transfer(bancorConverter,baseTokenAmout, {
  //   from: ownerWallet
  // });

  // await relayTokenInstance.issue(tagAlongProxyAddress,relayTokenAmount, {
  //   from: ownerWallet
  // });

  

  
  // await BancorConverter.setProvider(web3.currentProvider);
  // converterInstance = await BancorConverter.at(bancorConverter);
  // await converterInstance.addConnector(MainToken.address, "500000", false, {
  //   from: ownerWallet
  // });

  // await relayTokenInstance.transferOwnership(bancorConverter ,{
  //   from: ownerWallet
  // });
  
  // await converterInstance.acceptTokenOwnership({
  //   from: ownerWallet
  // })

  // await deployer.deploy(
  //   LiquadityRegistery,
  //   otherSecondary,
  //   MultiSigGovernance.address, {
  //     from: ownerWallet,
  //   }
  // );

  // liquadityRegisteryInstance = await LiquadityRegistery.deployed();

  // await deployer.deploy(Liquadity, {
  //   from: ownerWallet,
  // });

  // await liquadityRegisteryInstance.addVersion(1, Liquadity.address, {
  //   from: ownerWallet,
  // });

  // await liquadityRegisteryInstance.createProxy(
  //   1,
  //   bancorConverter,
  //   baseToken,
  //   MainToken.address,
  //   smartToken,
  //   ownerWallet,
  //   otherSecondary,
  //   MultiSigGovernance.address,
  //   AuctionRegisty.address,
  //   baseLinePrice,
  //   {
  //     from: ownerWallet,
  //   }
  // );

  // liquadityProxyAddress = await liquadityRegisteryInstance.proxyAddress();

  // liquadityInstance = Liquadity.at(liquadityProxyAddress);

  // await whiteListInstance.addNewWallet(liquadityProxyAddress, ByPassCode, 0, {
  //   from: WhiteListSecondary,
  // });

  // await auctionRegistyInstance.registerContractAddress(
  //   liquadityCode,
  //   liquadityProxyAddress, {
  //     from: otherSecondary
  //   }
  // );

  // console.log("liquadity",liquadityProxyAddress);
  // await deployer.deploy(
  //   AuctionProxyRegistry,
  //   auctionSecondary,
  //   MultiSigGovernance.address, {
  //     from: ownerWallet,
  //   }
  // );

  // AuctionProxyRegistryInstance = await AuctionProxyRegistry.deployed();

  // await deployer.deploy(Auction, {
  //   from: ownerWallet,
  // });

  // await AuctionProxyRegistryInstance.addVersion(1, Auction.address, {
  //   from: ownerWallet,
  // });

  // await AuctionProxyRegistryInstance.createProxy(
  //   1,
  //   1598032158,
  //   40,
  //   60,
  //   21,
  //   ownerWallet,
  //   auctionSecondary,
  //   MultiSigGovernance.address,
  //   AuctionRegisty.address,

  //   {
  //     from: ownerWallet,
  //   }
  // );

  // auctionProxyAddress = await AuctionProxyRegistryInstance.proxyAddress();

  // auctionInstance = Auction.at(auctionProxyAddress);

  // await whiteListInstance.addNewWallet(auctionProxyAddress, ByPassCode, 0, {
  //   from: WhiteListSecondary,
  // });

  // await auctionRegistyInstance.registerContractAddress(
  //   auctionCode,
  //   auctionProxyAddress, {
  //     from: otherSecondary
  //   }
  // );

  
  //console.log(register_white);
};