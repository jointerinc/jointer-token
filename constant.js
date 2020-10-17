
//tesnet Adderss
// const ownerWallet = "0xC3BdAF7a7740bF1cCA06eB5ed479EBFF1153773B"; // wallet #1
// const auctionSecondary = "0x58f06b0eA4F92750999e024e75D13dA7A06ab079"; // wallet #2
// const otherSecondary = "0xb511de8f9A4B1A66D1d63125089A55bD299f0c0a"; // wallet #3
// const whiteListSecondary = "0x68bC87e4Ac145b33D917f6CEAB7AdcF398F90771"; // white list wallet



 //have to chanage according 
const ownerWallet = "0xD99634a54e2295f23d4DBD5B004f73D4ed0474F5"; // wallet #1
const auctionSecondary = "0x58f06b0eA4F92750999e024e75D13dA7A06ab079"; // wallet #2
const otherSecondary = "0xb511de8f9A4B1A66D1d63125089A55bD299f0c0a"; // wallet #3
const whiteListSecondary = "0x68bC87e4Ac145b33D917f6CEAB7AdcF398F90771"; // white list wallet

// for bep20
const mainTokenOwner = "0x154A7eD86F3CceECfb54fD03034b3311D102399e";


// {
//     "Escrow": "0x72dC50F76c5982004e311086F44f80d9f325C5A1",
//     "EscrowedGovernance": "0x338a0dC9A3693D5d007db1CBbDadEE88828fc2F8",
//     "EscrowedGovernanceProxy": "0x2662Bb4cF85B0be7e151072ee404033DAcBbc746",
//     "Governance": "0xD4618DF62d8e1a179385cD68fB13214e4251835d",
//     "GovernanceProxy": "0x756D25558130dcaAaD42e4e73F91A4Ed9ed30bb8",
//     "Gateway": "0x7AD320b5EFe4e5287c84e5b46ba66b0Fbf77B7d4",
//     "RealEstate": "0xfB3497CD9ef268e1364593D7496f67B7B1e06B7c"
//   }
const realEstate =  "0xfB3497CD9ef268e1364593D7496f67B7B1e06B7c";
const governance = "0x756D25558130dcaAaD42e4e73F91A4Ed9ed30bb8"; // GovernanceProxy address is here dynamic
const escrow = "0x72dC50F76c5982004e311086F44f80d9f325C5A1"; // dynamic 
const gateWay = "0x7AD320b5EFe4e5287c84e5b46ba66b0Fbf77B7d4"; // dynamic 

// pool address
const factoryAddress = "0x0Ff8C7a97A2ec6cCfb472Cf6F13271512C1d791E";
const baseTokenAddress = "0x0000000000000000000000000000000000000001";// dynamic
const poolAddress = "0x65C29F0C82Ab7e3b30c819c86eD1f00Cd42b201D";// dynamic

//0x3fD4D76105E03851328Df84918cF6eF916F88f6A factory


const baseLinePrice = "28400000000"; // dynamic
const mainTokenHoldBack = 0; // threre is no holdback days
const etnTokenHoldBack = 0; 
const stockTokenHoldBack = 0;
const mainMaturityDays = 0; // threre is no maturityDays
const etnMaturityDays = 0;
const stockMaturityDays = 0;

const mainTokenName = "Jointer";
const mainTokenSymbol = "JNTR";

const preMintAddress = [escrow,ownerWallet];

const preMintAmount = ["11927121908469559000000000000","100000000000000000000000"];

const byPassCode = 20483;
const poolCode = 8195;

const starTime = 1602936000;
const minAuctionTime = 82800;
const intervalTime = 86400;
const mainTokenCheckDay = 58;

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
    gateWay:gateWay,
    mainTokenOwner:mainTokenOwner,
    factoryAddress:factoryAddress
}