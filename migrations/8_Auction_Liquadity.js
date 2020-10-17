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

const LiquadityRegistery = artifacts.require("LiquidityRegistery");
const Liquadity = artifacts.require("Liquidity");

const {
    ownerWallet,
    whiteListSecondary,
    baseTokenAddress,
    otherSecondary,
    governance,
    byPassCode,
    poolAddress,
    baseLinePrice,
    factoryAddress
} = require("../constant");

const liquadityCode = "0x4c49515549444954590000000000000000000000000000000000000000000000";

module.exports = async function (deployer) {

    currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    currentdata = JSON.parse(currentdata);

    auctionRegistery = currentdata.AuctionRegistery;
    whiteList = currentdata.WhiteList;
    mainToken = currentdata.MainToken;

    whiteListInstance = await WhiteList.at(whiteList);
    auctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);

    
    await deployer.deploy(
        LiquadityRegistery,
        otherSecondary,
        governance, {
            from: ownerWallet,
        }
    );

    
    LiquadityRegisteryInstance = await LiquadityRegistery.deployed();
    
    await deployer.deploy(Liquadity, {
        from: ownerWallet,
    });

    txHash8 = await LiquadityRegisteryInstance.addVersion(1, Liquadity.address, {
        from: ownerWallet,
    });

    txHash9 = await LiquadityRegisteryInstance.createProxy(
        1,
        poolAddress,
        factoryAddress,
        baseTokenAddress,
        mainToken,
        ownerWallet,
        otherSecondary,
        governance,
        auctionRegistery,
        baseLinePrice, {
            from: ownerWallet,
        }
    );

    LiquadityProxyAddress = await LiquadityRegisteryInstance.proxyAddress();

    LiquadityInstance = await Liquadity.at(LiquadityProxyAddress);

    await whiteListInstance.addNewWallet(LiquadityProxyAddress, byPassCode, 0, {
        from: whiteListSecondary,
    });

    txHash11 = await auctionRegistyInstance.registerContractAddress(
        liquadityCode,
        LiquadityProxyAddress, {
            from: otherSecondary
        }
    );

    await whiteListInstance.changeFlags(ownerWallet,0,{
        from: whiteListSecondary,
    });
    

    currentdata["LiquadityRegistery"] = LiquadityRegistery.address;
    currentdata["Liquadity"] = LiquadityProxyAddress;
    await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata, undefined, 2));

    
  
}