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

    // currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    // currentdata = JSON.parse(currentdata);

    // auctionRegistery = currentdata.AuctionRegistery;
    // whiteList = currentdata.WhiteList;
    // mainToken = currentdata.MainToken;

    // whiteListInstance = await WhiteList.at(whiteList);
    // auctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);
    //governance = "0xd3411ca38F5256154d25E949a3F0E7E9646D4Eac";
    auctionRegistery = "0xc10A9d65fAe96Ae0F337cb17c38b4fc1F60E410E";

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