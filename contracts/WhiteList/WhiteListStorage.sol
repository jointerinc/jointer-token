pragma solidity ^0.5.9;


contract WhiteListStorage {
    
    struct UserDetails {
        uint256 flags; // bitmap, where each bit correspondent to some properties (additional flags can be added in future).
        uint256 maxWallets;
        address[] wallets;
    }

    // Whitelist rules
    struct ReceivingRule {
        uint256 mask; // bit-mask to select bits which will be checked by this rule
        uint256 condition; // bit-sets which indicate the require bit status.
        // for example, if rule require that the 1 and 4 bits should be '1' and 2 bit should be '0', then mask = 0x16 (10110 binary) and condition = 0x12 (10010 binary). I.e. '1' is set for bit which should be '1' and '0' - for bit which should be '0'
    }

    // Restriction rules
    struct TransferringRule {
        uint256 from_mask; // bit-mask to select bits which will be checked by this rule
        uint256 from_condition; // bit-sets which indicate the require bit status.
        uint256 to_mask; // bit-mask to select bits which will be checked by this rule
        uint256 to_condition; // bit-sets which indicate the require bit status.
        // if rule 'from' return 'true' and rule 'to' is true - the transfer disallowed.
        // if rule 'from' return 'false' then don't check rule 'to'.
    }

    mapping(address => address) public address_belongs;
    mapping(address => UserDetails) public user_details;

    //Made this decision so that we can reuse the code

    //0:main
    //1:etn
    //2:stock
    mapping(uint8 => ReceivingRule) public tokenToReceivingRule;
    mapping(uint8 => TransferringRule[]) public tokenToTransferringRuleArray;

    //timestamp when hold back days are over
    mapping(uint8 => uint256) public tokenToHoldBackDaysTimeStamp;
    //timestamp when token matures
    mapping(uint8 => uint256) public tokenToMaturityDaysTimeStamp;

    uint256 public constant KYC = 1 << 0; //0x01
    uint256 public constant AML = 1 << 1; //0x02
    uint256 public constant ACCREDIATED_INVESTOR = 1 << 2;
    uint256 public constant QUALIFIED_INVESTOR = 1 << 3;
    uint256 public constant RETAIL_INVESTOR = 1 << 4;
    uint256 public constant IS_ALLOWED_BUYBACK = 1 << 5;
    uint256 public constant DECENTRALIZE_EXCHANGE = 1 << 6; // wallet of decentralize exchanges
    uint256 public constant CENTRALIZE_EXCHANGE = 1 << 7; // wallet of centralize exchanges
    uint256 public constant IS_ALLOWED_ETN = 1 << 8;
    uint256 public constant IS_ALLOWED_STOCK = 1 << 9;
    uint256 public constant FROM_USA = 1 << 10;
    uint256 public constant FROM_CHINA = 1 << 11;
    uint256 public constant FROM_EU = 1 << 12;
    uint256 public constant IS_BYPASSED = 1 << 13;
    uint256 public constant BANCOR_ADDRESS = 1 << 14;
    uint256 public constant IS_ALLOWED_AUCTION = 1 << 15;
    
    event AccountWhiteListed(address indexed which, uint256 flags);
    event WalletAdded(address indexed from, address indexed which);
    event WalletRemoved(address indexed from, address indexed which);
    event FlagsChanged(address indexed which, uint256 flags);

    
    
}