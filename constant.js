
// const ownerWallet = "0x153d9909f3131e6a09390b33f7a67d40418c0318";
// const otherSecondary = "0x98452666814c73ebff150f3d55ba4230a6c73f77";
// const whiteListSecondary = "0xf4c402bf860877183e46a19382a7847ca22b51d4";
// const auctionSecondary = "0xef7f7c4b5205a91a358de8bd8beb4345c3038922";

const ownerWallet = "0xC3BdAF7a7740bF1cCA06eB5ed479EBFF1153773B";
const whiteListSecondary = "0x68bC87e4Ac145b33D917f6CEAB7AdcF398F90771";
const auctionSecondary = "0x58f06b0eA4F92750999e024e75D13dA7A06ab079";
const otherSecondary = "0xb511de8f9A4B1A66D1d63125089A55bD299f0c0a";

const governance = "0xd3411ca38F5256154d25E949a3F0E7E9646D4Eac";
const escrow = "0x0Cdb8BA7e9D0A6039d9FD8556957F979A35FFB11";


// bancor address
const baseTokenAddress = "0x62bd9D98d4E188e281D7B78e29334969bbE1053c";
const relayTokenAddress = "0x8162Ff5FCF66f0B138539202D37b8B4D23C3B882";

const ethTokenAddress = "0xD368b98d03855835E2923Dc000b3f9c2EBF1b27b";
const ethBaseTokenRelayAddress = "0xDD78D22F53441b6B6216cE69E6dCAe6F7c9252b6";

const bancorConverterAddress = "0xFf15fD50bC2571f496108293B306729cbE88808e";
const bancorNetworkAddress = "0xE3042915EeaE7974bFe5a2653911d7fa05003eea";




const baseLinePrice = "1814000000";
const mainTokenHoldBack = 0;
const etnTokenHoldBack = 0;
const stockTokenHoldBack = 0;
const mainMaturityDays = 0;
const etnMaturityDays = 0;
const stockMaturityDays = 0;

const mainTokenName = "Jointer";
const mainTokenSymbol = "JNTR";

const preMintAddress = [ownerWallet,escrow];
const preMintAmount = ["100000000000000000000000","100000000000000000000000000000"];

const byPassCode = 8195;
const bancorCode = 16384;

const starTime = 1598032158;
const minAuctionTime = 60;
const intervalTime = 60;
const mainTokenCheckDay = 300;

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