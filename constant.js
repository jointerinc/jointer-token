

const ownerWallet = "0xC3BdAF7a7740bF1cCA06eB5ed479EBFF1153773B"; // wallet #1
const auctionSecondary = "0x58f06b0eA4F92750999e024e75D13dA7A06ab079"; // wallet #2
const otherSecondary = "0xb511de8f9A4B1A66D1d63125089A55bD299f0c0a"; // wallet #3
const whiteListSecondary = "0x68bC87e4Ac145b33D917f6CEAB7AdcF398F90771"; // white list wallet

// // have to chanage according 
// const ownerWallet = "0xD99634a54e2295f23d4DBD5B004f73D4ed0474F5"; // wallet #1
// const auctionSecondary = "0xc56975a27B5cBfbc31eDAcbf0ffd9d0c9b3A77c4"; // wallet #2
// const otherSecondary = "0x04a88313d287ABfd1ef62C8561dDFde09510b9Ca"; // wallet #3
// const whiteListSecondary = "0x82c2935d9b3F800fb80A167070C38aA835041B98"; // white list wallet

const realEstate =  "0xb151bDa7D286d7aE60916900342BD6BBFB72732F";

const governance = "0x649B355a5a4cC6c995690E95Df7a881D7CAc5887"; // GovernanceProxy address is here dynamic
const escrow = "0xE275aBE9A256E834Ff823F2150E9F495291A91a4"; // dynamic 
const gateWay = "0x7E4A19E5DC938c3c1383B54C4c4ECF47C50109A4"; // dynamic 

// pool address
const baseTokenAddress = "0x0000000000000000000000000000000000000000";// dynamic
const relayTokenAddress = "0x866e95a0058f55e47806f9de6c6a1ccbbfc55af6";// dynamic



const baseLinePrice = "1167500000"; // dynamic
const mainTokenHoldBack = 0; // threre is no holdback days
const etnTokenHoldBack = 0; 
const stockTokenHoldBack = 0;
const mainMaturityDays = 0; // threre is no maturityDays
const etnMaturityDays = 0;
const stockMaturityDays = 0;

const mainTokenName = "Jointer";
const mainTokenSymbol = "JNTR";

const preMintAddress = [escrow,ownerWallet];
const preMintAmount = ["11740788397000000000000000000","100000000000000000000000"];

const byPassCode = 20483;
const bancorCode = 8195;

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
    bancorCode:bancorCode,
    mainTokenName:mainTokenName,
    mainTokenSymbol:mainTokenSymbol,
    preMintAddress:preMintAddress,
    preMintAmount:preMintAmount,
    baseTokenAddress:baseTokenAddress,
    relayTokenAddress:relayTokenAddress,
    escrow:escrow,
    mainTokenCheckDay:mainTokenCheckDay,
    starTime : starTime,
    minAuctionTime:minAuctionTime,
    intervalTime:intervalTime,
    baseLinePrice:baseLinePrice,
    realEstate:realEstate,
    gateWay:gateWay,
    bancorNetworkAddress:bancorNetworkAddress
}