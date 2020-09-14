
// have to chanage according 
const ownerWallet = "0xD99634a54e2295f23d4DBD5B004f73D4ed0474F5"; // wallet #1
const auctionSecondary = "0xc56975a27B5cBfbc31eDAcbf0ffd9d0c9b3A77c4"; // wallet #2
const otherSecondary = "0x04a88313d287ABfd1ef62C8561dDFde09510b9Ca"; // wallet #3
const whiteListSecondary = "0x82c2935d9b3F800fb80A167070C38aA835041B98"; // white list wallet

const realEstate =  "0xA41A44e6084833f82E73a5edda6Caaf4C206AcC9";

const governance = "0xAb7594A440e3354AFe1f0B9792EFb76Dd90fF71d"; // GovernanceProxy address is here dynamic
const escrow = "0x352e2708aC8f671a2FE46e244D8255dcd17D7d35"; // dynamic 


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
const preMintAmount = ["11740788397000000000000000000","100000000000000000000000"];

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
    baseLinePrice:baseLinePrice,
    realEstate:realEstate
}