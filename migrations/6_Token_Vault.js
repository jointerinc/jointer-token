const fs  = require("fs");
const { promisify } = require('util')
const readFileAsync = promisify(fs.readFile);
const writeFileAsync = promisify(fs.writeFile);
var path = require('path');

const AuctionRegistery = artifacts.require("AuctionRegistery");
const WhiteList = artifacts.require("WhiteList");

const TokenVaultRegistery = artifacts.require("TokenVaultRegistery");
const TokenVault = artifacts.require("TokenVault");

const {
  ownerWallet,
  whiteListSecondary,
  otherSecondary,
  governance,
  byPassCode,
} = require("../constant");

const vaultCode =
  "0x5641554c54000000000000000000000000000000000000000000000000000000";

module.exports = async function (deployer) {

    currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    currentdata = JSON.parse(currentdata);
    
    auctionRegistery  = currentdata.AuctionRegistery;
    whiteList  = currentdata.WhiteList;

    whiteListInstance = await WhiteList.at(whiteList);
    auctionRegistyInstance = await AuctionRegistery.at(auctionRegistery);
   
    await deployer.deploy(
        TokenVaultRegistery,
        otherSecondary,
        governance, {
        from: ownerWallet,
        }
    );

    tokenVaultRegisteryInstance = await TokenVaultRegistery.deployed();
    await deployer.deploy(TokenVault, {
        from: ownerWallet,
    });

    txHash1 = await tokenVaultRegisteryInstance.addVersion(1, TokenVault.address, {
        from: ownerWallet,
    });

    txHash2 = await tokenVaultRegisteryInstance.createProxy(
        1,
        ownerWallet,
        otherSecondary,
        governance,
        auctionRegistery, {
        from: ownerWallet,
        }
    );

    tokenVaultProxyAdress = await tokenVaultRegisteryInstance.proxyAddress();
    tokenVaultInstance = await TokenVault.at(tokenVaultProxyAdress);

    txHash3 = await whiteListInstance.addNewWallet(tokenVaultProxyAdress, byPassCode, 0, {
        from: whiteListSecondary,
    });
    
    txHash4 =  await auctionRegistyInstance.registerContractAddress(
        vaultCode,
        tokenVaultProxyAdress, {
        from: otherSecondary
        }
    );


    currentdata["TokenVaultRegistery"] = TokenVaultRegistery.address;
    currentdata["TokenVault"] = tokenVaultProxyAdress;
    await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata,undefined,2));

}   

