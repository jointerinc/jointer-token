const TruffleContract = require("@truffle/contract");
const fs = require("fs");
const {
    promisify
} = require('util')
const readFileAsync = promisify(fs.readFile);
const writeFileAsync = promisify(fs.writeFile);
var path = require('path');

const AuctionRegistery = artifacts.require("AuctionRegistery");
const WhiteList = artifacts.require("WhiteList");

const MainToken = artifacts.require("MainToken");

const AuctionProxyRegistry = artifacts.require("AuctionProxyRegistry");
const Auction = artifacts.require("Auction");

const {
    ownerWallet,
    auctionSecondary,
    whiteListSecondary,
    otherSecondary,
    governance,
    byPassCode,
    starTime,
    minAuctionTime,
    mainTokenCheckDay,
    intervalTime

} = require("../constant");

const auctionCode = "0x41554354494f4e00000000000000000000000000000000000000000000000000";

module.exports = async function (deployer) {

    currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    currentdata = JSON.parse(currentdata);

    auctionRegistery = currentdata.AuctionRegistery;
    whiteList = currentdata.WhiteList;
    mainToken = currentdata.MainToken;

    whiteListInstance = await WhiteList.at(whiteList);
    auctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);
   
    await deployer.deploy(
        AuctionProxyRegistry,
        auctionSecondary,
        governance, {
        from: ownerWallet,
        }
    );

    AuctionProxyRegistryInstance = await AuctionProxyRegistry.deployed();

    await deployer.deploy(Auction, {
        from: ownerWallet,
    });

    await AuctionProxyRegistryInstance.addVersion(1, Auction.address, {
        from: ownerWallet,
    });

    await AuctionProxyRegistryInstance.createProxy(
        1,
        starTime,
        minAuctionTime,
        intervalTime,
        mainTokenCheckDay,
        ownerWallet,
        auctionSecondary,
        governance,
        auctionRegistery,
        {
            from: ownerWallet,
        }
    );
    auctionProxyAddress = await AuctionProxyRegistryInstance.proxyAddress();
  
    auctionInstance = Auction.at(auctionProxyAddress);

    await whiteListInstance.addNewWallet(auctionProxyAddress, byPassCode, 0, {
        from: whiteListSecondary,
    });

    await auctionRegistyInstance.registerContractAddress(
        auctionCode,
        auctionProxyAddress, {
            from: otherSecondary
        }
    );

    currentdata["AuctionProxyRegistry"] = AuctionProxyRegistry.address;
    currentdata["Auction"] = auctionProxyAddress;
    await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata, undefined, 2));

}