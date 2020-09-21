const fs  = require("fs");
const { promisify } = require('util')
const readFileAsync = promisify(fs.readFile);
const writeFileAsync = promisify(fs.writeFile);
var path = require('path');

const AuctionRegistery = artifacts.require("AuctionRegistery");
const WhiteList = artifacts.require("WhiteList");


const TagAlongRegistry = artifacts.require("ContributionTriggerRegistry");
const TagAlong = artifacts.require("ContributionTrigger");

const {
  ownerWallet,
  whiteListSecondary,
  otherSecondary,
  governance,
  byPassCode,
} = require("../constant");

const tagAlongCode =
  "0x434f4e545249425554494f4e5f54524947474552000000000000000000000000";

module.exports = async function (deployer) {

    // currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    // currentdata = JSON.parse(currentdata);
    
    // auctionRegistery  = currentdata.AuctionRegistery;
    // whiteList  = currentdata.WhiteList;

    // whiteListInstance = await WhiteList.at(whiteList);
    // auctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);

    // await deployer.deploy(
    //     TagAlongRegistry,
    //     otherSecondary,
    //     governance,{
    //        from: ownerWallet,
    //     }
    // );

    // tagAlongRegistryInstance = await TagAlongRegistry.deployed();

    // await deployer.deploy(TagAlong, {
    //     from: ownerWallet,
    // });

    // txHash1 = await tagAlongRegistryInstance.addVersion(1, TagAlong.address, {
    //     from: ownerWallet,
    // });

    // txHash2 = await tagAlongRegistryInstance.createProxy(
    //     1,
    //     ownerWallet,
    //     otherSecondary,
    //     governance,
    //     auctionRegistery, {
    //     from: ownerWallet,
    //     }
    // );
    
    // tagAlongProxyAddress = await tagAlongRegistryInstance.proxyAddress();

    // tagAlongInstance = await TagAlong.at(tagAlongProxyAddress);

    // txHash3 = await whiteListInstance.addNewWallet(tagAlongProxyAddress, byPassCode,10, {
    //     from: whiteListSecondary,
    // });
    
    // txHash4 =  await auctionRegistyInstance.registerContractAddress(
    //     tagAlongCode,
    //     tagAlongProxyAddress, {
    //     from: otherSecondary
    //     }
    // );

    // currentdata["TagAlongRegistry"] = TagAlongRegistry.address;
    // currentdata["TagAlong"] = tagAlongProxyAddress;
    // await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata,undefined,2));

}   

