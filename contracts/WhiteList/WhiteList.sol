pragma solidity ^0.5.9;

import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IERC20Token.sol";


contract WhiteListStorage {
    struct UserDetails {
        uint64 investorType;
        uint64 flags; // bitmap, where each bit correspondent to restriction flag
        uint256 maxWallets;
        address[] wallets;
    }
    uint8 counter;

    mapping(address => address) public address_belongs;
    mapping(address => UserDetails) public user_details;

    //@dev These are the bits representing a number
    uint8 public constant BYPASSED = 1 << 0; //0x01
    uint8 public constant KYC = 1 << 1; //0x02
    uint8 public constant AML = 1 << 2; //0x04

    uint8 public constant CANRECEIVE = KYC | AML;

    //investor Type(one of these three)

    //Restrictions on who to trade with
    uint8 public constant IS_ALLOWED_ACCREDIATED_INVESTOR = 1 << 3;
    uint8 public constant IS_ALLOWED_QUALIFIED_INVESTOR = 1 << 4;
    uint16 public constant IS_ALLOWED_RETAIL_INVESTOR = 1 << 5;

    uint16 public constant IS_ALLOWED_SMARTSWAP = 1 << 6;
    uint16 public constant IS_ALLOWED_BUYBACK = 1 << 7;
    uint16 public constant IS_ALLOWED_ETN = 1 << 8;
    uint16 public constant IS_ALLOWED_STOCK = 1 << 9;

    mapping(address => uint64) public isAllowedAddressConstant;

    mapping(uint64 => address) public investorTypeAddress;

    bytes32[] public types;

    address public smartSwapAddress;
    address public buyBackAddress;
    address public etnTokenAddress;
    address public stockTokenAddress;
}


contract WhiteList is Upgradeable, ProxyOwnable, SafeMath, WhiteListStorage {
    event AccountWhiteListed(address indexed which, uint256 walletType);
    event WalletAdded(address indexed from, address indexed which);
    event WalletRemoved(address indexed from, address indexed which);

    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress
    ) public {
        super.initialize();
        ProxyOwnable.initializeOwner(
            _primaryOwner,
            _systemAddress,
            _authorityAddress
        );
        //calculated by setting every bit expect investor bits i.e. Decimal of (1111111111000111)
        uint64 flags = 4294967239;

        whiteListAccount(_primaryOwner, 1, flags, 10);
        whiteListAccount(_systemAddress, 1, flags, 10);
        address_belongs[_primaryOwner] = _primaryOwner;
        address_belongs[_systemAddress] = _systemAddress;

        _addNewInvestorType(2, address(2), IS_ALLOWED_ACCREDIATED_INVESTOR);
        _addNewInvestorType(3, address(3), IS_ALLOWED_QUALIFIED_INVESTOR);
        _addNewInvestorType(4, address(4), IS_ALLOWED_RETAIL_INVESTOR);

        counter = 9;
    }

    function whiteListAccount(
        address _which,
        uint64 _investorType,
        uint64 _flags,
        uint256 _maxWallets
    ) internal returns (bool) {
        UserDetails storage details = user_details[_which];
        details.investorType = _investorType;
        details.flags = _flags;
        details.maxWallets = _maxWallets;
        address_belongs[_which] = _which;
        return true;
    }

    function addNewWallet(
        address _which,
        uint64 _investorType,
        uint64 _flags,
        uint256 _maxWallets
    ) public onlySystem() notZeroAddress(_which) returns (bool) {
        require(!isWhiteListed(_which), "ERR_ACTION_NOT_ALLOWED");

        return whiteListAccount(_which, _investorType, _flags, _maxWallets);
    }

    function updateMaxWallet(address _which, uint256 _maxWallets)
        public
        onlySystem()
        returns (bool)
    {
        require(isWhiteListed(_which), ERR_AUTHORIZED_ADDRESS_ONLY);
        UserDetails storage details = user_details[_which];
        details.maxWallets = _maxWallets;
        return true;
    }

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

    function setSmartSwapAddress(address _smartSwapAddress)
        public
        onlySystem()
        notZeroAddress(_smartSwapAddress)
    {
        smartSwapAddress = _smartSwapAddress;
        _addRestrictedAddress(_smartSwapAddress, IS_ALLOWED_SMARTSWAP);
    }

    function setBuyBackAddress(address _buyBackAddress)
        public
        onlySystem()
        notZeroAddress(_buyBackAddress)
    {
        buyBackAddress = _buyBackAddress;
        _addRestrictedAddress(_buyBackAddress, IS_ALLOWED_BUYBACK);
    }

    function setEtnTokenAddress(address _etnTokenAddress)
        public
        onlySystem()
        notZeroAddress(_etnTokenAddress)
    {
        etnTokenAddress = _etnTokenAddress;
        _addRestrictedAddress(_etnTokenAddress, IS_ALLOWED_ETN);
    }

    function setStockTokenAddress(address _stockTokenAddress)
        public
        onlySystem()
        notZeroAddress(_stockTokenAddress)
    {
        stockTokenAddress = _stockTokenAddress;
        _addRestrictedAddress(_stockTokenAddress, IS_ALLOWED_STOCK);
    }

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

    function changeInvestorType(address _which, uint64 _investorType)
        public
        onlySystem()
        notZeroAddress(_which)
        returns (bool)
    {
        require(isWhiteListed(_which), "ERR_ACTION_NOT_ALLOWED");
        address primaryAddress = address_belongs[_which];
        user_details[primaryAddress].investorType = _investorType;
        return true;
    }

    function isByPassed(address _which) public view returns (bool) {
        uint64 flags = getFlags(_which);
        return isBitSet(flags, BYPASSED);
    }

    function setByPassedAddress(address _which, bool _isPassed)
        public
        onlySystem()
        notZeroAddress(_which)
        returns (bool)
    {
        require(isWhiteListed(_which), "ERR_ACTION_NOT_ALLOWED");
        uint64 flags = getFlags(_which);
        flags = setBit(flags, BYPASSED, _isPassed); //set BYPASSED
        changeFlags(_which, flags);
        return true;
    }

    function isWhiteListed(address _which) public view returns (bool) {
        if (address_belongs[_which] == address(0)) return false;
        return true;
    }

    function getUserWallets(address _whom)
        public
        view
        returns (address[] memory)
    {
        UserDetails storage details = user_details[_whom];
        return details.wallets;
    }

    function walletExpires(address _which) public onlySystem() returns (bool) {
        require(isWhiteListed(_which), "ERR_ACTION_NOT_ALLOWED");
        uint64 flags = getFlags(_which);
        flags = setBit(flags, CANRECEIVE, false); //reset CANRECEIVE
        changeFlags(_which, flags);
        return true;
    }

    function walletRenewed(address _which) public onlySystem() returns (bool) {
        require(isWhiteListed(_which), "ERR_ACTION_NOT_ALLOWED");
        uint64 flags = getFlags(_which);
        flags = setBit(flags, CANRECEIVE, true); //set CANRECEIVE
        changeFlags(_which, flags);
        return true;
    }

    function canReciveToken(address _which) public view returns (bool) {
        uint64 flags = getFlags(_which);
        return isBitSet(flags, CANRECEIVE);
    }

    function isBitSet(uint64 _flags, uint64 _whichBit)
        public
        pure
        returns (bool)
    {
        uint64 flags = _flags & _whichBit;
        flags = flags ^ _whichBit;
        if (flags == 0) return true;
        return false;
    }

    function setBit(uint64 _flags, uint64 _whichBit, bool _isWhat)
        internal
        pure
        returns (uint64 flags)
    {
        if (_isWhat)
            flags = _flags | _whichBit; //set if true
        else flags = _flags & ~(_whichBit); //unset if false
    }

    function getFlags(address _which) public view returns (uint64 flags) {
        address primaryAddress = address_belongs[_which];
        flags = user_details[primaryAddress].flags;
    }

    function getNextConstant() internal returns (uint64 nextConstant) {
        counter++;
        //assert that overflow does not occur
        nextConstant = uint64(1) << counter;
        assert(nextConstant < 4294967296);
    }

    // This function will allow us to restric trading with 55 more Restrictions
    function addRestrictedAddress(address _which, uint64 _associatedConstant)
        public
        onlySystem()
        notZeroAddress(_which)
        returns (bool)
    {
        isAllowedAddressConstant[_which] = _associatedConstant;
    }

    //This function will allow us to restric trading with 55 more Restrictions
    //We will keep this _constant to refer if some _from is allowed to trade with this address or not
    function addRestrictedAddress(address _which)
        public
        onlySystem()
        notZeroAddress(_which)
        returns (uint64 associatedConstant)
    {
        //Make it bypassed
        whiteListAccount(_which, 1, 1, 0);
        associatedConstant = getNextConstant();
        isAllowedAddressConstant[_which] = associatedConstant;
    }

    function _addRestrictedAddress(address _which, uint64 _constant) internal {
        whiteListAccount(_which, 1, 1, 0);
        isAllowedAddressConstant[_which] = _constant;
    }

    function addNewInvestorType(uint64 _investorType)
        public
        onlySystem()
        returns (uint64 associatedConstant)
    {
        associatedConstant = getNextConstant();
        address associatedAddress = address(associatedConstant);
        _addNewInvestorType(
            _investorType,
            associatedAddress,
            associatedConstant
        );
    }

    function _addNewInvestorType(
        uint64 _investorType,
        address _associatedAddress,
        uint64 _associatedConstant
    ) internal {
        investorTypeAddress[_investorType] = _associatedAddress;
        _addRestrictedAddress(_associatedAddress, _associatedConstant);
    }

    function getInvestorType(address _which)
        public
        view
        returns (uint64 investorType)
    {
        address primaryAddress = address_belongs[_which];
        investorType = user_details[primaryAddress].investorType;
    }

    function _hasPermission(address _from, address _to)
        internal
        view
        returns (bool)
    {
        uint64 fromFlags = getFlags(_from);
        if (isAllowedAddressConstant[_to] != 0) {
            uint64 addressBit = isAllowedAddressConstant[_to];
            if (!isBitSet(fromFlags, addressBit)) return false;
        }
        return true;
    }

    function hasPermission(address _from, address _to)
        public
        view
        returns (bool)
    {
        return _hasPermission(_from, _to);
    }

    function isAllowedWithType(address _from, address _to)
        public
        view
        returns (bool)
    {
        uint64 toInvestorType = getInvestorType(_to);

        if (toInvestorType == 1) {
            return _hasPermission(_from, _to);
        }

        address associatedAddress = investorTypeAddress[toInvestorType];
        return _hasPermission(_from, associatedAddress);
    }
}
