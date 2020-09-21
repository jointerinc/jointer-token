const fs  = require("fs");
const { promisify } = require('util')
const readFileAsync = promisify(fs.readFile);
const writeFileAsync = promisify(fs.writeFile);
var path = require('path');
const AuctionRegistery = artifacts.require("AuctionRegistery");

const WhiteList = artifacts.require("WhiteList");

const MainToken = artifacts.require("MainToken");

const {
  ownerWallet,
  otherSecondary,
  governance,
  mainTokenName,
  mainTokenSymbol,
  preMintAddress,
  preMintAmount,
} = require("../constant");



const mainTokenCode =
  "0x4d41494e5f544f4b454e00000000000000000000000000000000000000000000";

module.exports = async function (deployer) {

    // currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    // currentdata = JSON.parse(currentdata);
    
    // auctionRegistery  = currentdata.AuctionRegistery;
    // whiteList  = currentdata.WhiteList;

    // whiteListInstance = await WhiteList.at(whiteList);
    // auctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);
    
    // await deployer.deploy(
    //     MainToken,
    //     mainTokenName,
    //     mainTokenSymbol,
    //     otherSecondary,
    //     governance,
    //     auctionRegistery,
    //     preMintAddress,
    //     preMintAmount, {
    //     from: ownerWallet,
    //     }
    // );
    
    // txHash1 = await auctionRegistyInstance.registerContractAddress(
    //     mainTokenCode,
    //     MainToken.address, {
    //     from: otherSecondary
    //     }
    // );
     
    // currentdata["MainToken"] = MainToken.address;
    // await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata,undefined,2));

    
}   

