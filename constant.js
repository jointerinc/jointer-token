
// have to chanage according 
const ownerWallet = "0xD99634a54e2295f23d4DBD5B004f73D4ed0474F5"; // wallet #1
const auctionSecondary = "0xc56975a27B5cBfbc31eDAcbf0ffd9d0c9b3A77c4"; // wallet #2
const otherSecondary = "0x04a88313d287ABfd1ef62C8561dDFde09510b9Ca"; // wallet #3
const whiteListSecondary = "0x82c2935d9b3F800fb80A167070C38aA835041B98"; // white list wallet

const realEstate =  "0xA41A44e6084833f82E73a5edda6Caaf4C206AcC9";

const governance = "0x2071195F2071c066853a904F9459A8668f0B3e46"; // GovernanceProxy address is here dynamic
const escrow = "0x352e2708aC8f671a2FE46e244D8255dcd17D7d35"; // dynamic 
const gateWay = "0x7f1eAAE18E0CCdb9ECBA86e0bBe3ef76718245C7"; // dynamic 

// bancor address

const baseTokenAddress = "0x1f573d6fb3f13d689ff844b4ce37794d79a7ff1c";// dynamic
const ethTokenAddress = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"; // dynamic

const ethBaseTokenRelayAddress = "0xb1CD6e4153B2a390Cf00A6556b0fC1458C4A5533";// dynamic
const bancorNetworkAddress = "0x2F9EC37d6CcFFf1caB21733BdaDEdE11c823cCB0";// dynamic

// now this two varibale need to chnage after maintoken Deployed we deploy bancor reserve 
// and then we get this parameter  
const relayTokenAddress = "0x32d9a18826e76afcdc6c9df1ab79bd888ab40d2e";// dynamic
const bancorConverterAddress = "0x4eb0845ca823205D16135E64c184bd2B2D591169"; // dynamic

const baseLinePrice = "1162999999"; // dynamic
const mainTokenHoldBack = 0; // threre is no holdback days
const etnTokenHoldBack = 0; 
const stockTokenHoldBack = 0;
const mainMaturityDays = 0; // threre is no maturityDays
const etnMaturityDays = 0;
const stockMaturityDays = 0;

const mainTokenName = "Jointer";
const mainTokenSymbol = "JNTR";

]
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
    realEstate:realEstate,
    gateWay:gateWay,
    bancorNetworkAddress:bancorNetworkAddress
}