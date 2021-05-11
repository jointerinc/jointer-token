pragma solidity ^0.5.9;
import "../InterFaces/IBEP20Token.sol";
import "../InterFaces/IAuctionRegistery.sol";

contract LiquidityStorage {
    bytes32 internal constant BANCOR_FORMULA = "BancorFormula";
    bytes32 internal constant BANCOR_NETWORK = "BancorNetwork";
    uint256 public constant BIG_NOMINATOR = 10**24;
    uint256 public constant DECIMAL_NOMINATOR = 10**18;
    uint256 public constant PRICE_NOMINATOR = 10**9;

    address payable public converter;
    address payable public factory;

    address public baseToken; // basetoken

    address public mainToken; // maintoken

  
    // registery of all contacrt
    IAuctionRegistery public contractsRegistry;

    address payable public whiteListAddress;
    address payable public vaultAddress;
    address payable public auctionAddress;
    address payable public triggerAddress;
    address payable public currencyPricesAddress;
    address payable public escrowAddress;

   

    // side reserve ratio split between bancor and side reserve
    uint256 public sideReseverRatio;

    // 1:1 investment ratio
    uint256 public tagAlongRatio;

    // token price increase from yesterday limit 120%
    uint256 public appreciationLimit;

    // token price increase in decimal place
    uint256 public appreciationLimitWithDecimal;

    // contribution reduction start day
    uint256 public reductionStartDay;

    // basetoken price change ratio
    uint256 public baseTokenVolatiltyRatio;

    // reduction limit
    uint256 public virtualReserverDivisor;

    // previous day contribution in bancor
    uint256 public previousMainReserveContribution;

    // current day contribution in bancor
    uint256 public todayMainReserveContribution;

    // auction end day price of token
    uint256 public tokenAuctionEndPrice;

    // last reserve balance in bancor
    uint256 public lastReserveBalance;

    // basetoken starting price
    uint256 public baseLinePrice;

    // maxIteration for finding root
    uint256 public maxIteration;

    // check if today token price reach certain level
    bool public isAppreciationLimitReached;

    bool public isBuyBackOpen;

    uint256 public relayPercent;

    // mapping for where user last reddeem
    mapping(address => uint256) public lastReedeemDay;

    event Contribution(address _token, uint256 _amount, uint256 returnAmount);
    event RecoverPrice(uint256 _oldPrice, uint256 _newPrice);
    event Redemption(address _token, uint256 _amount, uint256 returnAmount);
    event FundDeposited(address _token, address indexed _from, uint256 _amount);

    uint256 public redemptionDayRelay;
}
