pragma solidity ^0.5.9;
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/IAuctionRegistery.sol";

contract LiquadityStorage {
    bytes32 internal constant BANCOR_FORMULA = "BancorFormula";
    bytes32 internal constant BANCOR_NETWORK = "BancorNetwork";
    uint256 public constant BIG_NOMINATOR = 10**24;
    uint256 public constant DECIMAL_NOMINATOR = 10**18;
    uint256 public constant PRICE_NOMINATOR = 10**9;

    address public converter;

    address public bancorNetwork;

    address public baseToken; // basetoken

    address public mainToken; // maintoken

    address public relayToken; // relayToken

    address public etherToken; // etherToken

    address public ethRelayToken; // ether to baseToken RelayToken

    // registery of all contacrt
    IAuctionRegistery public contractsRegistry;

    address payable public whiteListAddress;
    address payable public vaultAddress;
    address payable public auctionAddress;
    address payable public tagAlongAddress;
    address payable public currencyPricesAddress;
    address payable public escrowAddress;

    // _path = 0 ether to maint token conversion path
    address[] public ethToMainToken;
    // _path = 1 basetoken to mainToken conversion path
    address[] public baseTokenToMainToken;
    // _path = 2 mainToken to basetoken conversion path
    address[] public mainTokenTobaseToken;
    // _path = 3 ether to baseToken conversion path
    address[] public ethToBaseToken;
    // _path = 4  basetoken to ether conversion path
    address[] public baseTokenToEth;

    IERC20Token[] public relayPath;

    uint256[] public returnAmountRelay;

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

    uint256 public relayPercent;

    // mapping for where user last reddeem
    mapping(address => uint256) public lastReedeemDay;

    event Contribution(address _token, uint256 _amount, uint256 returnAmount);
    event RecoverPrice(uint256 _oldPrice, uint256 _newPrice);
    event Redemption(address _token, uint256 _amount, uint256 returnAmount);
    event FundDeposited(address _token, address indexed _from, uint256 _amount);
}
