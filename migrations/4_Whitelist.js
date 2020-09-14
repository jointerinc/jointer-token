
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
  gateWay,
  realEstate,
  bancorCode,
  bancorNetworkAddress
} = require("../constant");


const WhiteListCode =
  "0x57484954455f4c49535400000000000000000000000000000000000000000000";

const escrowCode =
  "0x455343524f570000000000000000000000000000000000000000000000000000";

const realEstateCode = "0x434f4d50414e595f46554e445f57414c4c455400000000000000000000000000";

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
    
    await whiteListInstance.addNewWallet(ownerWallet,byPassCode, 10, {
      from: whiteListSecondary,
    });

    await whiteListInstance.addNewWallet(escrow,byPassCode, 10, {
      from: whiteListSecondary,
    });

    await whiteListInstance.addNewWallet(realEstate,byPassCode, 10, {
      from: whiteListSecondary,
    });

    await whiteListInstance.addNewWallet(gateWay,byPassCode, 10, {
      from: whiteListSecondary,
    });

    await whiteListInstance.addNewWallet(bancorNetworkAddress,bancorCode, 10, {
      from: whiteListSecondary,
    });

    await AuctionRegistyInstance.registerContractAddress(
      WhiteListCode,
      whiteListProxyAdress, {
        from: otherSecondary
      }
    );

     await AuctionRegistyInstance.registerContractAddress(
      escrowCode,
      escrow, {
        from: otherSecondary
      }
    );

    await AuctionRegistyInstance.registerContractAddress(
      realEstateCode,
      realEstate, {
        from: otherSecondary
      }
    );

    currentdata["WhiteListRegistery"] = WhiteListRegistery.address;
    currentdata["WhiteList"] = whiteListProxyAdress;
    await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata,undefined,2));

};
