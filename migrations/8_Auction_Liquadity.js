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

const LiquadityRegistery = artifacts.require("LiquadityRegistery");
const Liquadity = artifacts.require("Liquadity");

const SmartToken = TruffleContract(require("../test/bancorArtifacts/SmartToken.json"));
const BancorConverter = TruffleContract(require("../test/bancorArtifacts/BancorConverter.json"));

const {
    ownerWallet,
    whiteListSecondary,
    relayTokenAddress,
    baseTokenAddress,
    otherSecondary,
    governance,
    byPassCode,
    bancorCode,
    bancorConverterAddress,
    ethBaseTokenRelayAddress,
    etherTokenAddress,
    bancorNetworkAddress,
    ethRelayTokenAddress,
    ethTokenAddress,
    baseLinePrice
} = require("../constant");

const liquadityCode = "0x4c49515541444954590000000000000000000000000000000000000000000000";

module.exports = async function (deployer) {

    currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    currentdata = JSON.parse(currentdata);

    auctionRegistery = currentdata.AuctionRegistery;
    whiteList = currentdata.WhiteList;
    mainToken = currentdata.MainToken;

    whiteListInstance = await WhiteList.at(whiteList);
    auctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);

    await BancorConverter.setProvider(web3.currentProvider);
    converterInstance = await BancorConverter.at(bancorConverterAddress);
    
    await SmartToken.setProvider(web3.currentProvider);
    relayTokenInstance = await SmartToken.at(relayTokenAddress);

    txHash1 = await converterInstance.addConnector(mainToken, "500000", false, {
        from: ownerWallet
    });
    
    txHash6 = await whiteListInstance.addNewWallet(bancorNetworkAddress, bancorCode, 0, {
        from: whiteListSecondary,
    });

    txHash7 = await whiteListInstance.addNewWallet(bancorConverterAddress, bancorCode, 0, {
        from: whiteListSecondary,
    })

    MainTokenInstance = await MainToken.at(mainToken);

    txHash2 = await MainTokenInstance.transfer(bancorConverterAddress,"100000000000000000000000",{from:ownerWallet})

    txHash3 = await relayTokenInstance.transferOwnership(bancorConverterAddress ,{
        from: ownerWallet
    });

    txHash4 = await converterInstance.acceptTokenOwnership({
        from: ownerWallet
    })

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

    txHash8 = await LiquadityRegisteryInstance.addVersion(1, Liquadity.address);

    txHash9 = await LiquadityRegisteryInstance.createProxy(
        1,
        bancorConverterAddress,
        baseTokenAddress,
        mainToken,
        relayTokenAddress,
        etherTokenAddress,
        ethRelayTokenAddress
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

    txHash10 = await whiteListInstance.addNewWallet(LiquadityProxyAddress, byPassCode, 0, {
        from: whiteListSecondary,
    });

    txHash11 = await auctionRegistyInstance.registerContractAddress(
        liquadityCode,
        LiquadityProxyAddress, {
            from: otherSecondary
        }
    );

    ethToMainToken = [
        ethTokenAddress,
        ethBaseTokenRelayAddress,
        baseTokenAddress,
        relayTokenAddress,
        mainToken,
    ];

    baseTokenToMainToken = [
        baseTokenAddress,
        relayTokenAddress,
        mainToken,
    ];

    mainTokenTobaseToken = [
        mainToken,
        relayTokenAddress,
        baseTokenAddress,
    ];

    ethToBaseToken = [
        ethTokenAddress,
        ethBaseTokenRelayAddress,
        baseTokenAddress,
    ];

    baseTokenToEth = [
        baseTokenAddress,
        ethBaseTokenRelayAddress,
        ethTokenAddress,
    ];

    txHash12 = await LiquadityInstance.setAllPath(
      ethToMainToken,
      baseTokenToMainToken,
      mainTokenTobaseToken,
      ethToBaseToken,
      baseTokenToEth,
      {
        from: ownerWallet,
      }
    );

    currentdata["LiquadityRegistery"] = LiquadityRegistery.address;
    currentdata["Liquadity"] = LiquadityProxyAddress;
    await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata, undefined, 2));

    
  
}