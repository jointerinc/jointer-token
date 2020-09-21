

const ownerWallet = "0xC3BdAF7a7740bF1cCA06eB5ed479EBFF1153773B"; // wallet #1
const auctionSecondary = "0x58f06b0eA4F92750999e024e75D13dA7A06ab079"; // wallet #2
const otherSecondary = "0xb511de8f9A4B1A66D1d63125089A55bD299f0c0a"; // wallet #3
const whiteListSecondary = "0x68bC87e4Ac145b33D917f6CEAB7AdcF398F90771"; // white list wallet



// // have to chanage according 
// const ownerWallet = "0xD99634a54e2295f23d4DBD5B004f73D4ed0474F5"; // wallet #1
// const auctionSecondary = "0xc56975a27B5cBfbc31eDAcbf0ffd9d0c9b3A77c4"; // wallet #2
// const otherSecondary = "0x04a88313d287ABfd1ef62C8561dDFde09510b9Ca"; // wallet #3
// const whiteListSecondary = "0x82c2935d9b3F800fb80A167070C38aA835041B98"; // white list wallet

const realEstate =  "0xa54D503914E9f6Da63333F62625B0eD6dE49A68d";

const governance = "0x3AED1defBD95F7c9476823f6348A88953507a7c5"; // GovernanceProxy address is here dynamic
const escrow = "0x79F760C4259F7a5a8E0e7FEbce293c1263318Afa"; // dynamic 
const gateWay = "0xEcC65C496bAb375d7be0A63C2788016ceB86494B"; // dynamic 

// pool address
const baseTokenAddress = "0x0000000000000000000000000000000000000000";// dynamic
const poolAddress = "0x2FcdaDEAE31f3D9Da0FC47560197014E1d86842E";// dynamic



const baseLinePrice = "23970000000"; // dynamic
const mainTokenHoldBack = 0; // threre is no holdback days
const etnTokenHoldBack = 0; 
const stockTokenHoldBack = 0;
const mainMaturityDays = 0; // threre is no maturityDays
const etnMaturityDays = 0;
const stockMaturityDays = 0;

const mainTokenName = "Jointer";
const mainTokenSymbol = "JNTR";

const preMintAddress = [escrow,ownerWallet];

const preMintAmount = ["5870394198500000000000000000","5870394198500000000000000000"]; // testAmount

//const preMintAmount = ["11740788397000000000000000000","100000000000000000000000"];

const byPassCode = 20483;
const poolCode = 8195;

const starTime = 1600084800;
const minAuctionTime = 60;
const intervalTime = 60;
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
    poolCode:poolCode,
    mainTokenName:mainTokenName,
    mainTokenSymbol:mainTokenSymbol,
    preMintAddress:preMintAddress,
    preMintAmount:preMintAmount,
    baseTokenAddress:baseTokenAddress,
    poolAddress:poolAddress,
    escrow:escrow,
    mainTokenCheckDay:mainTokenCheckDay,
    starTime : starTime,
    minAuctionTime:minAuctionTime,
    intervalTime:intervalTime,
    baseLinePrice:baseLinePrice,
    realEstate:realEstate,
    gateWay:gateWay
}