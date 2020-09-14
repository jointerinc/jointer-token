
// const ownerWallet = "0x153d9909f3131e6a09390b33f7a67d40418c0318";
// const otherSecondary = "0x98452666814c73ebff150f3d55ba4230a6c73f77";
// const whiteListSecondary = "0xf4c402bf860877183e46a19382a7847ca22b51d4";
// const auctionSecondary = "0xef7f7c4b5205a91a358de8bd8beb4345c3038922";


// have to chanage according 
const ownerWallet = "0xC3BdAF7a7740bF1cCA06eB5ed479EBFF1153773B";
const whiteListSecondary = "0x68bC87e4Ac145b33D917f6CEAB7AdcF398F90771";
const auctionSecondary = "0x58f06b0eA4F92750999e024e75D13dA7A06ab079";
const otherSecondary = "0xb511de8f9A4B1A66D1d63125089A55bD299f0c0a";

const governance = "0xd3411ca38F5256154d25E949a3F0E7E9646D4Eac"; // dynamic
const escrow = "0x0Cdb8BA7e9D0A6039d9FD8556957F979A35FFB11"; // dynamic 


// bancor address
const baseTokenAddress = "0x98474564a00d15989f16bfb7c162c782b0e2b336";// dynamic
const relayTokenAddress = "0x32d9a18826e76afcdc6c9df1ab79bd888ab40d2e";// dynamic
const ethTokenAddress = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"; // dynamic
const ethBaseTokenRelayAddress = "0x884058297ec1FfD6C8FA4F9F2d4f066057255a03";// dynamic
const bancorConverterAddress = "0x4eb0845ca823205D16135E64c184bd2B2D591169"; // dynamic
const bancorNetworkAddress = "0xE3042915EeaE7974bFe5a2653911d7fa05003eea";// dynamic




const baseLinePrice = "1162999999"; // dynamic
const mainTokenHoldBack = 0; // threre is no holdback days
const etnTokenHoldBack = 0; 
const stockTokenHoldBack = 0;
const mainMaturityDays = 0; // threre is no maturityDays
const etnMaturityDays = 0;
const stockMaturityDays = 0;

const mainTokenName = "Jointer";
const mainTokenSymbol = "JNTR";

const preMintAddress = [escrow,ownerWallet];
const preMintAmount = ["11740788397000000000000000000","100000000000000000000000000000"];

const byPassCode = 20483;
const bancorCode = 8195;

const starTime = 1600084800;
const minAuctionTime = 82800;
const intervalTime = 86400;
const mainTokenCheckDay = 11;

module.exports = {
    governance:governance,
    ownerWallet:ownerWallet,
    otherSecondary:otherSecondary,
    whiteListSecondary:whiteListSecondary,
    auctionSecondary:auctionSecondary,
    mainTokenHoldBack:mainTokenHoldBack,
    etnTokenHoldBack:etnTokenHoldBack,
    stockTokenHoldBack:stockTokenHoldBack,
    mainMaturityDays:mainMaturityDays,
    etnMaturityDays:etnMaturityDays,
    stockMaturityDays:stockMaturityDays,
    byPassCode:byPassCode,
    bancorCode:bancorCode,
    mainTokenName:mainTokenName,
    mainTokenSymbol:mainTokenSymbol,
    preMintAddress:preMintAddress,
    preMintAmount:preMintAmount,
    baseTokenAddress:baseTokenAddress,
    relayTokenAddress:relayTokenAddress,
    ethTokenAddress:ethTokenAddress,
    bancorConverterAddress:bancorConverterAddress,
    ethBaseTokenRelayAddress:ethBaseTokenRelayAddress,
    bancorNetworkAddress:bancorNetworkAddress,
    escrow:escrow,
    mainTokenCheckDay:mainTokenCheckDay,
    starTime : starTime,
    minAuctionTime:minAuctionTime,
    intervalTime:intervalTime,
    baseLinePrice:baseLinePrice
}