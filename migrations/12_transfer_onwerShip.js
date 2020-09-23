
const fs  = require("fs");
const { promisify } = require('util')
const readFileAsync = promisify(fs.readFile);
const writeFileAsync = promisify(fs.writeFile);
var path = require('path');

const AuctionRegistery = artifacts.require("AuctionRegistery");

const WhiteListRegistery = artifacts.require("WhiteListRegistery");
const WhiteList = artifacts.require("WhiteList");

const MainToken = artifacts.require("MainToken");
const CurrencyPrices = artifacts.require("CurrencyPrices");

const TokenVaultRegistery = artifacts.require("TokenVaultRegistery");
const TokenVault = artifacts.require("TokenVault");

const TagAlongRegistry = artifacts.require("ContributionTriggerRegistry");
const TagAlong = artifacts.require("ContributionTrigger");

const LiquadityRegistery = artifacts.require("LiquidityRegistery");
const Liquadity = artifacts.require("Liquidity");

const AuctionProxyRegistry = artifacts.require("AuctionProxyRegistry");
const Auction = artifacts.require("Auction");

const ProtectionRegistry = artifacts.require("ProtectionRegistry");
const AuctionProtection = artifacts.require("AuctionProtection");


const { ownerWallet , otherSecondary  } = require('../constant');
module.exports = async function (deployer) {

    currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    currentdata = JSON.parse(currentdata);
    
    auctionRegistery  = currentdata.AuctionRegistery;
    
    whiteList  = currentdata.WhiteList;
    whiteListRegistery  = currentdata.WhiteListRegistery;
    mainToken = currentdata.MainToken;
    currencyPrice = currentdata.CurrencyPrices;

    tokenVault = currentdata.TokenVault;
    tokenVaultRegistery = currentdata.TokenVaultRegistery;
    
    tagAlong = currentdata.TagAlong;
    tagAlongRegistry = currentdata.TagAlongRegistry;

    liquadity = currentdata.Liquadity;
    liquadityRegistery = currentdata.LiquadityRegistery;

    auction = currentdata.Auction;
    auctionProxyRegistry = currentdata.AuctionProxyRegistry;

    auctionProtection = currentdata.AuctionProtection;
    protectionRegistry = currentdata.ProtectionRegistry;
    

    auctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);
    currencyPricesInstnace = await CurrencyPrices.at(currencyPrice);
    maintTokenInstance = await MainToken.at(mainToken);

    whiteListInstance = await WhiteList.at(whiteList);
    whiteListRegisteryInstance = await WhiteListRegistery.at(whiteListRegistery);

    tokenVaultInstance = await TokenVault.at(tokenVault);
    tokenVaultRegisteryInstance = await TokenVaultRegistery.at(tokenVaultRegistery);

    tagAlongInstance = await TagAlong.at(tagAlong);
    tagAlongRegistryInstance = await TagAlongRegistry.at(tagAlongRegistry);

    liquadityInstance = await Liquadity.at(liquadity);
    liquadityRegisteryInstance = await LiquadityRegistery.at(liquadityRegistery);

    auctionInstance = await Auction.at(auction);
    auctionProxyRegistryInstance = await AuctionProxyRegistry.at(auctionProxyRegistry);

    protectionInstance = await AuctionProtection.at(auctionProtection);
    protectionInstanceInstance = await ProtectionRegistry.at(auctionProxyRegistry);
    
    await auctionRegistyInstance.changePrimaryOwner({from: ownerWallet});
    await whiteListInstance.changePrimaryOwner({from: ownerWallet});
    await maintTokenInstance.changePrimaryOwner({from: ownerWallet});
    await tokenVaultInstance.changePrimaryOwner({from: ownerWallet});
    await tagAlongInstance.changePrimaryOwner({from: ownerWallet});
    await liquadityInstance.changePrimaryOwner({from: ownerWallet});
    await auctionInstance.changePrimaryOwner({from: ownerWallet});

    await whiteListRegisteryInstance.changePrimaryOwner({from: ownerWallet});
    await tokenVaultRegisteryInstance.changePrimaryOwner({from: ownerWallet});
    await liquadityRegisteryInstance.changePrimaryOwner({from: ownerWallet});
    await auctionProxyRegistryInstance.changePrimaryOwner({from: ownerWallet});
    await protectionInstanceInstance.changePrimaryOwner({from: ownerWallet});

}

