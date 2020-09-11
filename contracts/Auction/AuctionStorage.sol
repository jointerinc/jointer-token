pragma solidity ^0.5.9;
import "../InterFaces/IAuctionRegistery.sol";

contract AuctionStorage {
    IAuctionRegistery public contractsRegistry;

    address payable public whiteListAddress;
    address payable public smartSwapAddress;
    address payable public currencyPricesAddress;
    address payable public vaultAddress;
    address payable public mainTokenAddress;
    address payable public LiquidityAddress;
    address payable public companyFundWalletAddress;
    address payable public escrowAddress;

    uint256 public constant PRICE_NOMINATOR = 10**9;

    uint256 public constant DECIMAL_NOMINATOR = 10**18;
    
    uint256 public constant PERCENT_NOMINATOR = 10**6;

    // allowed contarct limit the contribution
    uint256 public maxContributionAllowed;
    // managment fee to run auction cut from basesupply
    uint256 public managementFee;
    // staking percentage
    uint256 public staking;
    // fund that will be locked in contacrt
    uint256 public downSideProtectionRatio;
    // Fund goes to companyWallet
    uint256 public fundWalletRatio;
    // if contribution reach above yesterdayContribution groupBonus multiplyer
    uint256 public groupBonusRatio;
    // user neeed this amount of mainToken to contribute
    uint256 public mainTokenRatio;

    //from which day mainTokenCheck start
    uint256 public mainTokencheckDay;
    // current auctionday
    uint256 public auctionDay;
    // current totalContribution
    uint256 public totalContribution;
    // today total contributiton
    uint256 public todayContribution;
    // yesterday's contribution
    uint256 public yesterdayContribution;
    // allowed max contribution in a day
    uint256 public allowMaxContribution;
    // yesterday token Supply
    uint256 public yesterdaySupply;
    // today token supply
    uint256 public todaySupply;

    uint256 public averageDay;

    // address how much invested by them in auciton till date
    mapping(address => uint256) public userTotalFund;

    // how much token recived by address in auciton till date
    mapping(address => uint256) public userTotalReturnToken;

    // day wise supply (groupBounus+coreSupply)
    mapping(uint256 => uint256) public dayWiseSupply;

    // day wise  coreSupply
    mapping(uint256 => uint256) public dayWiseSupplyCore;

    // day wise bonusSupply
    mapping(uint256 => uint256) public dayWiseSupplyBonus;

    // daywise contribution
    mapping(uint256 => uint256) public dayWiseContribution;

    // daywise markertPrice
    mapping(uint256 => uint256) public dayWiseMarketPrice;

    // dayWise downsideProtection Ratio
    mapping(uint256 => uint256) public dayWiseDownSideProtectionRatio;

    // address wise contribution each day
    mapping(uint256 => mapping(address => uint256))
        public walletDayWiseContribution;

    // daywise contribution
    mapping(uint256 => mapping(address => uint256))
        public mainTokenCheckDayWise;

    // return index of user for bonus
    mapping(uint256 => uint256) public indexReturn;

    // day wiser five top contributor
    mapping(uint256 => mapping(uint256 => address)) public topFiveContributor;

    //contributor Index
    mapping(uint256 => mapping(address => uint256)) public topContributorIndex;

    // check if daywise token disturbuted
    mapping(uint256 => mapping(address => bool)) public returnToken;

    uint256 public MIN_AUCTION_END_TIME; //epoch

    uint256 public LAST_AUCTION_START;

    uint256 public INTERVAL;
    
    uint256 public currentMarketPrice;
    
    event FundAdded(
        uint256 indexed _auctionDayId,
        uint256 _todayContribution,
        address indexed _fundBy,
        address indexed _fundToken,
        uint256 _fundAmount,
        uint256 _fundValue,
        uint256 _totalFund,
        uint256 _marketPrice
    );

    event FundAddedBehalf(address indexed _caller, address indexed _recipient);

    event AuctionEnded(
        uint256 indexed _auctionDayId,
        uint256 _todaySupply,
        uint256 _yesterdaySupply,
        uint256 _todayContribution,
        uint256 _yesterdayContribution,
        uint256 _totalContribution,
        uint256 _maxContributionAllowed,
        uint256 _tokenPrice,
        uint256 _tokenMarketPrice
    );

    event FundDeposited(address _token, address indexed _from, uint256 _amount);

    event TokenDistrubuted(
        address indexed _whom,
        uint256 indexed dayId,
        uint256 _totalToken,
        uint256 lockedToken,
        uint256 _userToken
    );
    
    // downside protection storage goes from here 
    // timestamp for address where first lock happen
    mapping(address => uint256) public lockedOn;

    mapping(address => mapping(address => uint256)) public lockedFunds;

    mapping(address => mapping(uint256 => mapping(address => uint256))) public currentLockedFunds;

    mapping(address => uint256) public lockedTokens;
    
    event TokenUnLocked(address indexed _from, uint256 _tokenAmount);

    event InvestMentCancelled(address indexed _from, uint256 _tokenAmount);

    event FundLocked(address _token, address indexed _which, uint256 _amount);

    event FundTransfer(address indexed _to, address _token, uint256 _amount);
    
    uint256 public totalTokenAmount;

    mapping(uint256 => uint256) dayWiseRatio;

    mapping(address => uint256) lastRound;

    mapping(address => mapping(uint256 => uint256)) roundWiseToken;

    mapping(address => uint256) stackBalance;
    
    uint256 public tokenLockDuration;

    mapping(address => bool) public unLockBlock;
    
    mapping (address => uint256) totalLocked;

    uint256 public vaultRatio;
    
    event StackAdded(
        uint256 indexed _roundId,
        address indexed _whom,
        uint256 _amount
    );

    event StackRemoved(
        uint256 indexed _roundId,
        address indexed _whom,
        uint256 _amount
    );
}