pragma solidity ^0.5.9;

import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IERC20Token.sol";


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

    mapping(uint8 => uint256) tokenToHoldBackDaysTimeStamp;
    mapping(uint8 => uint256) tokenToMaturityDaysTimeStamp;
}


contract WhiteList is Upgradeable, ProxyOwnable, SafeMath, WhiteListStorage {
    event AccountWhiteListed(address indexed which, uint256 walletType);
    event WalletAdded(address indexed from, address indexed which);
    event WalletRemoved(address indexed from, address indexed which);

    //for testing only
    constructor() public {
        registry = IRegistry(msg.sender);
        systemAddress = msg.sender;
    }

    //@dev converts _days into unix timestamp _days from now
    function convertDaysToTimeStamp(uint256 _days)
        internal
        view
        returns (uint256)
    {
        uint256 duration = safeMul(86400, _days);
        return safeAdd(now, duration);
    }

    //@dev since its a proxy contract this is what will work as a constructor
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        uint256 _mainHoldBackDays,
        uint256 _etnHoldBackDays,
        uint256 _stockHoldBackDays,
        uint256 _mainMaturityDays,
        uint256 _etnMaturityDays,
        uint256 _stockMaturityDays
    ) public {
        super.initialize();
        ProxyOwnable.initializeOwner(
            _primaryOwner,
            _systemAddress,
            _authorityAddress
        );
        tokenToMaturityDaysTimeStamp[0] = convertDaysToTimeStamp(
            _mainMaturityDays
        );
        tokenToMaturityDaysTimeStamp[1] = convertDaysToTimeStamp(
            _etnMaturityDays
        );
        tokenToMaturityDaysTimeStamp[2] = convertDaysToTimeStamp(
            _stockMaturityDays
        );

        tokenToHoldBackDaysTimeStamp[0] = convertDaysToTimeStamp(
            _mainHoldBackDays
        );
        tokenToHoldBackDaysTimeStamp[1] = convertDaysToTimeStamp(
            _etnHoldBackDays
        );
        tokenToHoldBackDaysTimeStamp[2] = convertDaysToTimeStamp(
            _stockHoldBackDays
        );
    }

    //@dev whitelists an address
    function whiteListAccount(
        address _which,
        uint64 _flags,
        uint256 _maxWallets
    ) internal returns (bool) {
        UserDetails storage details = user_details[_which];
        details.flags = _flags;
        details.maxWallets = _maxWallets;
        address_belongs[_which] = _which;
        return true;
    }

    //@dev returns if address is whitelisted
    function isWhiteListed(address _which) public view returns (bool) {
        if (address_belongs[_which] == address(0)) return false;
        return true;
    }

    //@dev checks if address is bypassed
    function isAddressByPassed(address _which) public view returns (bool) {
        address primaryAddress = address_belongs[_which];
        uint256 flags = user_details[primaryAddress].flags;
        return checkRule(flags, IS_BYPASSED, IS_BYPASSED);
    }

    //@dev whitelists an address
    function addNewWallet(
        address _which,
        uint64 _flags,
        uint256 _maxWallets
    ) public onlySystem() notZeroAddress(_which) returns (bool) {
        require(!isWhiteListed(_which), "ERR_ACTION_NOT_ALLOWED");
        return whiteListAccount(_which, _flags, _maxWallets);
    }

    //@dev updates the maximum wallets allowed for a primary whitelisted address
    function updateMaxWallet(address _which, uint256 _maxWallets)
        public
        onlyOwner
        returns (bool)
    {
        require(isWhiteListed(_which), ERR_AUTHORIZED_ADDRESS_ONLY);
        UserDetails storage details = user_details[_which];
        details.maxWallets = _maxWallets;
        return true;
    }

    //@dev allows primary whitelisted address to add wallet address controlled by them(reverts if maximum wallets is reached)
    function addMoreWallets(address _which)
        public
        notZeroAddress(_which)
        returns (bool)
    {
        require(
            address_belongs[_which] == address(0),
            ERR_AUTHORIZED_ADDRESS_ONLY
        );

        address sender = msg.sender;

        address primaryAddress = address_belongs[sender];

        require(
            isWhiteListed(primaryAddress) && sender == primaryAddress,
            ERR_AUTHORIZED_ADDRESS_ONLY
        );

        UserDetails storage details = user_details[primaryAddress];

        require(
            details.maxWallets > details.wallets.length,
            "ERR_MAXIMUM_WALLET_LIMIT"
        );

        address_belongs[_which] = primaryAddress;

        details.wallets.push(_which);

        emit WalletAdded(primaryAddress, _which);

        return true;
    }

    //@dev allows system to chage flags associated with an address
    function changeFlags(address _which, uint64 _flags)
        public
        onlySystem()
        notZeroAddress(_which)
        returns (bool)
    {
        require(isWhiteListed(_which), "ERR_ACTION_NOT_ALLOWED");
        address primaryAddress = address_belongs[_which];
        user_details[primaryAddress].flags = _flags;
        return true;
    }

    //@dev checks condition
    //@param _flags on which conditions are being checked on
    //@param _mask the bits we care about in a conditions
    //@param _condition the pattern of bits which should be exactly same in _flags to be true
    function checkRule(
        uint256 _flags,
        uint256 _mask,
        uint256 _condition
    ) internal pure returns (bool) {
        uint256 flags = _flags & _mask;
        flags = flags ^ _condition;
        if (flags == 0) return true;
        return false;
    }

    //@dev adds ReceivingRule of the token
    function _addReceivingRule(
        uint256 _mask,
        uint256 _condition,
        uint8 _token
    ) internal {
        tokenToReceivingRule[_token] = ReceivingRule(_mask, _condition);
    }

    //@dev adds transferring rule
    //if from has from_conditions bits set(i.e. is from usa) and to has to_condition bits set(i.e. is from china) then we don't allow
    function _addTransferringRule(
        uint256 from_mask,
        uint256 from_condition,
        uint256 to_mask,
        uint256 to_condition,
        uint8 token
    ) internal {
        tokenToTransferringRuleArray[token].push(
            TransferringRule(from_mask, from_condition, to_mask, to_condition)
        );
    }

    function _removeTransferingRule(uint256 _index, uint8 _token) internal {

            TransferringRule[] storage transferringRules
         = tokenToTransferringRuleArray[_token];

        require(_index < transferringRules.length, "CHECK_ARRAY_INDEX");

        transferringRules[_index] = transferringRules[safeSub(
            transferringRules.length,
            1
        )]; //replace with last element
        delete (transferringRules[safeSub(transferringRules.length, 1)]); //delete the last element
        transferringRules.length = safeSub(transferringRules.length, 1);
    }

    // @dev Check, if receiver is whitelisted (has all necessary flags). Require to pass all rules in the set.
    function _isReceiveAllowed(address user, uint8 token)
        internal
        view
        returns (bool)
    {
        address investor = address_belongs[user];
        require(investor != address(0), "ERR_ACTION_NOT_ALLOWED");
        uint256 flags = user_details[investor].flags;
        bool result;
        result = checkRule(
            flags,
            tokenToReceivingRule[token].mask,
            tokenToReceivingRule[token].condition
        );
        if (!result) return false; // if rule don't passed - receiving token disallowed.
        return true;
    }

    //@dev checks if transfer is allowed with according transferringRules of a token
    function _isTransferAllowed(
        address _from,
        address _to,
        uint8 token
    ) internal view returns (bool) {
        bool result = _isReceiveAllowed(_to, token); // Check receiver at first
        if (!result) return false; // if receiver disallowed the transfer disallowed too.
        address from = address_belongs[_from];
        address to = address_belongs[_to];
        require(from != address(0), "ERR_ACTION_NOT_ALLOWED");
        uint256 from_flags = user_details[from].flags;
        uint256 to_flags = user_details[to].flags;

        //makes sure that token is not mature
        if (tokenToMaturityDaysTimeStamp[token] != 0)
            require(
                now < tokenToMaturityDaysTimeStamp[token],
                "ERR_TOKEN_MATURED"
            );
        //makes sure that holdback days are over
        if (tokenToHoldBackDaysTimeStamp[token] != 0)
            require(
                now >= tokenToHoldBackDaysTimeStamp[0],
                "ERR_TOKEN_HOLDBACK_NOT_OVER"
            );

        for (
            uint256 i = 0;
            i < tokenToTransferringRuleArray[token].length;
            i++
        ) {
            // check the sender for restriction.
            result = checkRule(
                from_flags,
                tokenToTransferringRuleArray[token][i].from_mask,
                tokenToTransferringRuleArray[token][i].from_condition
            );
            // check receiver only in case when sender has restriction.
            if (result) {
                result = checkRule(
                    to_flags,
                    tokenToTransferringRuleArray[token][i].to_mask,
                    tokenToTransferringRuleArray[token][i].to_condition
                );
                if (result) return false; // if receiver is restricted, the transfer disallowed.
            }
        }
        return true;
    }

    //@dev adds ReceivingRule for main token
    function addMainRecivingRule(uint256 mask, uint256 condition)
        public
        onlySystem()
    {
        _addReceivingRule(mask, condition, 0);
    }

    //@dev removes a specific rule from transferringRules for main token
    function removeMainTransferingRules(uint256 _index) public onlySystem() {
        _removeTransferingRule(_index, 0);
    }

    //@dev add transferringRule for main token
    function addMainTransferringRule(
        uint256 from_mask,
        uint256 from_condition,
        uint256 to_mask,
        uint256 to_condition
    ) public onlySystem() {
        _addTransferringRule(
            from_mask,
            from_condition,
            to_mask,
            to_condition,
            0
        );
    }

    //@dev checks if address is allowed to recieve main token
    function main_isReceiveAllowed(address user) public view returns (bool) {
        return _isReceiveAllowed(user, 0);
    }

    //@dev check if transferring is allowed for main
    function main_isTransferAllowed(address _from, address _to)
        public
        view
        returns (bool)
    {
        return _isTransferAllowed(_from, _to, 0);
    }

    //@dev check if transferring is allowed for etn
    function etn_isTransferAllowed(address _from, address _to)
        public
        view
        returns (bool)
    {
        return _isTransferAllowed(_from, _to, 1);
    }

    //@dev checks if address is allowed to recieve etn token
    function etn_isReceiveAllowed(address user) public view returns (bool) {
        return _isReceiveAllowed(user, 1);
    }

    //@dev adds ReceivingRule for etn token
    function addEtnTransferringRule(
        uint256 from_mask,
        uint256 from_condition,
        uint256 to_mask,
        uint256 to_condition
    ) public onlySystem() {
        _addTransferringRule(
            from_mask,
            from_condition,
            to_mask,
            to_condition,
            1
        );
    }

    //@dev removes a specific rule from transferringRules for etn token
    function removeEtnTransferingRules(uint256 _index) public onlySystem() {
        _removeTransferingRule(_index, 1);
    }

    //@dev adds ReceivingRule for etn token
    function addEtnRecivingRule(uint256 mask, uint256 condition)
        public
        onlySystem()
    {
        _addReceivingRule(mask, condition, 1);
    }

    //@dev check if transferring is allowed for stock
    function stock_isTransferAllowed(address _from, address _to)
        public
        view
        returns (bool)
    {
        return _isTransferAllowed(_from, _to, 2);
    }

    //@dev checks if address is allowed to recieve stock token
    function stock_isReceiveAllowed(address user) public view returns (bool) {
        return _isReceiveAllowed(user, 2);
    }

    //@dev add transferringRule for stock token
    function addStockTransferringRule(
        uint256 from_mask,
        uint256 from_condition,
        uint256 to_mask,
        uint256 to_condition
    ) public onlySystem() {
        _addTransferringRule(
            from_mask,
            from_condition,
            to_mask,
            to_condition,
            2
        );
    }

    //@dev removes a specific rule from transferringRules for stock token
    function removeStockTransferingRules(uint256 _index) public onlySystem() {
        _removeTransferingRule(_index, 2);
    }

    //@dev adds ReceivingRule for stock token
    function addStockRecivingRule(uint256 mask, uint256 condition)
        public
        onlySystem()
    {
        _addReceivingRule(mask, condition, 2);
    }
}
