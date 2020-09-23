
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
    
    
    whiteList  = currentdata.WhiteList;
    mainToken = currentdata.MainToken;
    currencyPrice = currentdata.CurrencyPrices;
    tokenVault = currentdata.TokenVault;
    tagAlong = currentdata.TagAlong;
    liquadity = currentdata.Liquadity;
    auction = currentdata.Auction;
    
    currencyPricesInstnace = await CurrencyPrices.at(currencyPrice);
    whiteListInstance = await WhiteList.at(whiteList);
    maintTokenInstance = await MainToken.at(mainToken);
    tokenVaultInstance = await TokenVault.at(tokenVault);
    tagAlongInstance = await TagAlong.at(tagAlong);
    liquadityInstance = await Liquadity.at(liquadity);
    auctionInstance = await Auction.at(auction);

    await currencyPricesInstnace.setCurrencyPriceContract(mainToken,liquadity,{
        from: otherSecondary
    });

    await tokenVault.addSpender(liquadity,{
        from: ownerWallet
    });

    await whiteListInstance.updateAddresses({from: ownerWallet})
    await maintTokenInstance.updateAddresses({from: ownerWallet})
    await tokenVaultInstance.updateAddresses({from: ownerWallet})
    await tagAlongInstance.updateAddresses({from: ownerWallet})
    await liquadityInstance.updateAddresses({from: ownerWallet})
    await auctionInstance.updateAddresses({from: ownerWallet})

    // no need to update auciton protection as we deploy it last it has alredy latest address

   
}

