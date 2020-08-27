
const fs  = require("fs");
const { promisify } = require('util')
const readFileAsync = promisify(fs.readFile);
const writeFileAsync = promisify(fs.writeFile);
var path = require('path');
const CurrencyPrices = artifacts.require("CurrencyPrices");
const CurrencyPriceTicker = artifacts.require("CurrencyPriceTicker");
const AuctionRegistery = artifacts.require("AuctionRegistery");

const { ownerWallet , otherSecondary , governance , baseTokenAddress } = require('../constant');

const ethParameter = "QmTf9VbQLKZXE9bLkKkAJzV4qejgP1DjisE96TWdtPSUiB";
const btcParameter = "QmcKvmCWHhn9Kyfkt8PP9po2xcULiQQnYgSRnFfgJnYvxk";
const bntParameter = "QmdXwaPzneefSub9zm6DoX1kAadgMubhRhHpbaxZfvsSDq";

const ethCode = "0x0000000000000000000000000000000000000000";
const btcCode = "0x0000000000000000000000000000000000000001";

const currencyCode =
  "0x43555252454e4359000000000000000000000000000000000000000000000000";


module.exports = async function (deployer) {
    
    // currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    // currentdata = JSON.parse(currentdata);

    // auctionRegistery  = currentdata.AuctionRegistery;
    // AuctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);

    // await deployer.deploy(
    //     CurrencyPrices,
    //     otherSecondary,
    //     governance, {
    //       from: ownerWallet
    //     }
    // );

    // CurrencyPricesInstnace = await CurrencyPrices.deployed();

    // await deployer.deploy(
    //     CurrencyPriceTicker,
    //     "ETH",
    //     otherSecondary,
    //     governance,
    //     ethParameter,
    //     {
    //       from: ownerWallet
    //     }
    // );

    // ethPriceTracker = CurrencyPriceTicker.address;
    // ethPriceTrackerInstance = await CurrencyPriceTicker.deployed();
    // await web3.eth.sendTransaction({
    //   from: ownerWallet,
    //   to: ethPriceTracker,
    //   value: "15000000000000000",
    // });
    // await ethPriceTrackerInstance.update({from:otherSecondary});
    // await CurrencyPricesInstnace.setCurrencyPriceContract(ethCode,ethPriceTracker,{
    //   from: otherSecondary
    // });
    

    // await deployer.deploy(
    //     CurrencyPriceTicker,
    //     "BTC",
    //     otherSecondary,
    //     governance, 
    //     btcParameter,
    //     {
    //       from: ownerWallet
    //     }
    // );
    // btcPriceTracker = CurrencyPriceTicker.address;
    // btcPriceTrackerInstance = await CurrencyPriceTicker.deployed();
    // await web3.eth.sendTransaction({
    //   from: ownerWallet,
    //   to: btcPriceTracker,
    //   value: "15000000000000000",
    // });
    // await btcPriceTrackerInstance.update({from:otherSecondary});
    // await CurrencyPricesInstnace.setCurrencyPriceContract(btcCode,btcPriceTracker,{
    //   from: otherSecondary
    // });
    

    // await deployer.deploy(
    //     CurrencyPriceTicker,
    //     "BNT",
    //     otherSecondary,
    //     governance, 
    //     bntParameter,{
    //       from: ownerWallet
    //     }
    // );
    // bntPriceTracker = CurrencyPriceTicker.address;
    // bntPriceTrackerInstance = await CurrencyPriceTicker.deployed();
    // await web3.eth.sendTransaction({
    //   from: ownerWallet,
    //   to: bntPriceTracker,
    //   value: "15000000000000000",
    // });
    // await CurrencyPricesInstnace.setCurrencyPriceContract(baseTokenAddress,bntPriceTracker,{
    //     from: otherSecondary
    // });
    // await bntPriceTracker.update({from:otherSecondary});

    // await AuctionRegistyInstance.registerContractAddress(
    //     currencyCode,
    //     CurrencyPrices.address, {
    //     from: otherSecondary
    //     }
    // );

    // currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    // currentdata = JSON.parse(currentdata);
    // currentdata["CurrencyPrices"] = CurrencyPrices.address;
    // await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata,undefined,2));

    
    
}

