
const fs  = require("fs");
const { promisify } = require('util')
const readFileAsync = promisify(fs.readFile);
const writeFileAsync = promisify(fs.writeFile);
var path = require('path');
const CurrencyPrices = artifacts.require("CurrencyPrices");
const CurrencyPriceTicker = artifacts.require("CurrencyPriceTicker");
const AuctionRegistery = artifacts.require("AuctionRegistery");

const { ownerWallet , otherSecondary , governance , baseTokenAddress } = require('../constant');



const bandProtocol = "0xDA7a001b254CD22e46d3eAB04d937489c93174C3";

const currencyCode =
  "0x43555252454e4359000000000000000000000000000000000000000000000000";


module.exports = async function (deployer) {
    
    currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    currentdata = JSON.parse(currentdata);

    auctionRegistery  = currentdata.AuctionRegistery;
    AuctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);

    await deployer.deploy(
        CurrencyPrices,
        otherSecondary,
        governance, {
          from: ownerWallet
        }
    );

    CurrencyPricesInstnace = await CurrencyPrices.deployed();

    await deployer.deploy(
        CurrencyPriceTicker,
        bandProtocol,
        "BNB",
        "USD",
        {
          from: ownerWallet
        }
    );

    await CurrencyPricesInstnace.setCurrencyPriceContract(baseTokenAddress,CurrencyPriceTicker.address,{
      from: otherSecondary
    });

    await CurrencyPricesInstnace.setCurrencyPriceContract("0x0000000000000000000000000000000000000000",CurrencyPriceTicker.address,{
      from: otherSecondary
    });
    
    // await AuctionRegistyInstance.registerContractAddress(
    //     currencyCode,
    //     CurrencyPrices.address, {
    //     from: otherSecondary
    //     }
    // );

    // currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    // currentdata = JSON.parse(currentdata);
    // currentdata["CurrencyPrices"] =  CurrencyPrices.address;//CurrencyPrices.address;
    // await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata,undefined,2));

    
    
}

