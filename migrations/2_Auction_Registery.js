
const fs  = require("fs");
const { promisify } = require('util')
const readFileAsync = promisify(fs.readFile);
const writeFileAsync = promisify(fs.writeFile);
var path = require('path');

const AuctionRegistery = artifacts.require("AuctionRegistery");

const { ownerWallet , otherSecondary , governance } = require('../constant');


module.exports = async function (deployer) {
    
    await deployer.deploy(
        AuctionRegistery,
        otherSecondary,
        governance, {
        from: ownerWallet
        }
    );

    currentdata = await readFileAsync(path.resolve(__dirname, '../latestContract.json'));
    currentdata = JSON.parse(currentdata);
    currentdata["AuctionRegistery"] = AuctionRegistery.address;
    await writeFileAsync(path.resolve(__dirname, '../latestContract.json'), JSON.stringify(currentdata,undefined,2));

}

