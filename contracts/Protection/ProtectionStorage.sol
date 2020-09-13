pragma solidity ^0.5.9;
import "../InterFaces/IAuctionRegistery.sol";

contract ProtectionStorage {
    
    IAuctionRegistery public contractsRegistry;

    address payable public vaultAddress;
    address payable public auctionAddress;
    address payable public triggerAddress;
    address payable public mainTokenAddress;
    address payable public companyFundWalletAddress;
    address payable public whiteListAddress;
    
    // timestamp for address where first lock happen
    mapping(address => uint256) public lockedOn;

    mapping(address => mapping(address => uint256)) public lockedFunds;

    mapping(address => mapping(uint256 => mapping(address => uint256))) public currentLockedFunds;

    mapping(address => uint256) public lockedTokens;
    
    
    event TokenUnLocked(address indexed _from, uint256 _tokenAmount);

    event InvestMentCancelled(address indexed _from, uint256 _tokenAmount);

    event FundLocked(address _token, address indexed _which, uint256 _amount);

    event FundTransfer(address indexed _to, address _token, uint256 _amount);
    
    // We track Token only transfer by auction or downside
    // Reason for tracking this bcz someone can send token direclty

    uint256 public constant PERCENT_NOMINATOR = 10**6;

    uint256 public constant DECIMAL_NOMINATOR = 10**18;

    uint256 public totalTokenAmount;

    uint256 public stackRoundId;

    mapping(uint256 => uint256) dayWiseRatio;

    mapping(address => uint256) lastRound;

    mapping(address => mapping(uint256 => uint256)) roundWiseToken;

    mapping(address => uint256) stackBalance;
    
    uint256 public tokenLockDuration;
    
    mapping(address => bool) public unLockBlock;

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