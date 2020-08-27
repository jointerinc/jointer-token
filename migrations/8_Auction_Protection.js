const fs  = require("fs");
const { promisify } = require('util')
const readFileAsync = promisify(fs.readFile);
const writeFileAsync = promisify(fs.writeFile);
var path = require('path');

const AuctionRegistery = artifacts.require("AuctionRegistery");
const WhiteList = artifacts.require("WhiteList");


const ProtectionRegistry = artifacts.require("ProtectionRegistry");
const AuctionProtection = artifacts.require("AuctionProtection");

const {
  ownerWallet,
  whiteListSecondary,
  otherSecondary,
  governance,
  byPassCode,
} = require("../constant");

const protectionCode =
  "0x41554354494f4e5f50524f54454354494f4e0000000000000000000000000000";

module.exports = async function (deployer) {

    // currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    // currentdata = JSON.parse(currentdata);
    
    // auctionRegistery  = currentdata.AuctionRegistery;
    // whiteList  = currentdata.WhiteList;

    // whiteListInstance = await WhiteList.at(whiteList);
    // auctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);

    // await deployer.deploy(
    //     ProtectionRegistry,
    //     otherSecondary,
    //     governance,{
    //        from: ownerWallet,
    //     }
    // );

    // protectionRegistryInstance = await ProtectionRegistry.deployed();

    // await deployer.deploy(AuctionProtection, {
    //     from: ownerWallet,
    // });

    // txHash1 = await protectionRegistryInstance.addVersion(1, AuctionProtection.address);

    // txHash2 = await protectionRegistryInstance.createProxy(
    //     1,
    //     ownerWallet,
    //     otherSecondary,
    //     governance,
    //     auctionRegistery, {
    //     from: ownerWallet,
    //     }
    // );
    
    // protectionProxyAddress = await protectionRegistryInstance.proxyAddress();

    // protectionInstance = await AuctionProtection.at(protectionProxyAddress);

    // txHash3 = await whiteListInstance.addNewWallet(protectionProxyAddress, byPassCode, 0, {
    //     from: whiteListSecondary,
    // });
    
    // txHash4 =  await auctionRegistyInstance.registerContractAddress(
    //     protectionCode,
    //     protectionProxyAddress, {
    //     from: otherSecondary
    //     }
    // );

    // currentdata["ProtectionRegistry"] = ProtectionRegistry.address;
    // currentdata["AuctionProtection"] = protectionProxyAddress;
    // await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata,undefined,2));
  
   

}   

