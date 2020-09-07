
const fs  = require("fs");
const { promisify } = require('util')
const readFileAsync = promisify(fs.readFile);
const writeFileAsync = promisify(fs.writeFile);
var path = require('path');
const WhiteListRegistery = artifacts.require("WhiteListRegistery");
const WhiteList = artifacts.require("WhiteList");
const AuctionRegistery = artifacts.require("AuctionRegistery");
const {
  ownerWallet,
  whiteListSecondary,
  otherSecondary,
  governance,
  mainTokenHoldBack,
  etnTokenHoldBack,
  stockTokenHoldBack,
  mainMaturityDays,
  etnMaturityDays,
  stockMaturityDays,
  byPassCode,
  escrow,
} = require("../constant");


const WhiteListCode =
  "0x57484954455f4c49535400000000000000000000000000000000000000000000";

module.exports = async function (deployer) {
  
    currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    currentdata = JSON.parse(currentdata);
    auctionRegistery  = currentdata.AuctionRegistery;


    
    await deployer.deploy(WhiteListRegistery, whiteListSecondary, governance, {
      from: ownerWallet,
    });

    whiteListRegisteryInstance = await WhiteListRegistery.deployed();

    await deployer.deploy(WhiteList, {
      from: ownerWallet,
    });

    txHash1 = await whiteListRegisteryInstance.addVersion(1, WhiteList.address, {
      from: ownerWallet,
    });

    txHash2 = await whiteListRegisteryInstance.createProxy(
      1,
      ownerWallet,
      whiteListSecondary,
      governance,
      mainTokenHoldBack,
      etnTokenHoldBack,
      stockTokenHoldBack,
      mainMaturityDays,
      etnMaturityDays,
      stockMaturityDays,
      auctionRegistery,
      {
        from: ownerWallet,
      }
    );

    whiteListProxyAdress = await whiteListRegisteryInstance.proxyAddress();
    whiteListInstance = await WhiteList.at(whiteListProxyAdress);
    
    AuctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);
    
    txHash3 = await whiteListInstance.addNewWallet(ownerWallet,byPassCode, 10, {
      from: whiteListSecondary,
    });

    txHash3 = await whiteListInstance.addNewWallet(escrow,byPassCode, 10, {
      from: whiteListSecondary,
    });

    txHash4 = await AuctionRegistyInstance.registerContractAddress(
      WhiteListCode,
      whiteListProxyAdress, {
        from: otherSecondary
      }
    );

    currentdata["WhiteListRegistery"] = WhiteListRegistery.address;
    currentdata["WhiteList"] = whiteListProxyAdress;
    await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata,undefined,2));

};
