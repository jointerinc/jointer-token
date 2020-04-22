pragma solidity ^0.5.9;

import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../Proxy/Upgradeable.sol";

contract WhiteListStorage {
    
    //whiteList type here show which kind of wallet is this 
    // this is dynmic type field 
    
    struct UserDetails {
        uint256 whiteListType;
        uint256 maxWallets;
        bool canRecive;
        address[] wallets;
        mapping(address => uint256) walletIndex;
        mapping(bytes32 => bytes32) moreDetails;
    }
    
    mapping(address => bool) public is_whiteListed;

    mapping(address => address) public address_belongs;

    mapping(address => UserDetails) public user_details;

    mapping(uint256 => bool) public allowed_in_primary;

    mapping(uint256 => bool) public allowed_in_secondary;

    mapping(address => bool) by_passed_address;
    
}

contract WhiteList is Upgradeable, ProxyOwnable, SafeMath, WhiteListStorage {

    event AccountWhiteListed(address indexed which, uint256 walletType);
    event WalletAdded(address indexed from, address indexed which);
    event WalletRemoved(address indexed from, address indexed which);

    function initialize(address _primaryOwner,address _systemAddress,address _authorityAddress) public {
        super.initialize();
        ProxyOwnable.initializeOwner(_primaryOwner,_systemAddress,_authorityAddress);
        whiteListAccount(msg.sender, 0, 10);
        whiteListAccount(_systemAddress, 0, 10);
        by_passed_address[msg.sender] = true;
        by_passed_address[_systemAddress] = true;
        allowed_in_primary[0] = true;
        allowed_in_secondary[0] = true;
    }

    function whiteListAccount(
        address _which,
        uint256 _whiteListType,
        uint256 _maxWallets
    ) internal returns (bool) {
        
        is_whiteListed[_which] = true;
        
        UserDetails storage details = user_details[_which];
        
        details.whiteListType = _whiteListType;
        
        details.maxWallets = _maxWallets;
        
        details.canRecive = true;
        
        address_belongs[_which] = _which;
        
        emit AccountWhiteListed(_which, _whiteListType);
        
        return true;
    }

    //by passed address dont need to pass anything
    function setByPassedAddress(address _which, bool _isPassed)
        public
        onlySystem()
        notZeroAddress(_which)
        returns (bool)
    {
        by_passed_address[_which] = _isPassed;
        return true;
    }

    function isAddressByPassed(address _which) public view returns (bool) {
        return by_passed_address[_which];
    }

    /**
     * @dev add new whitelisted account
     * @param _which The address which was whitelisted.
     * @param _whiteListType account type
     * @param _maxWallets user can whitelist limted wallets
     * @return true if transcation success
     */
    function addNewWallet(
        address _which,
        uint256 _whiteListType,
        uint256 _maxWallets
    ) public onlySystem() notZeroAddress(_which) returns (bool) {
        require(address_belongs[_which] == address(0));
        return whiteListAccount(_which, _whiteListType, _maxWallets);
    }

    /**
     * @dev update how many wallet one user can have
     * @param _which The address which was whitelisted.
     * @param _maxWallets user can whitelist limted wallets
     * @return true if transcation success
     */
    function updateMaxWallet(address _which, uint256 _maxWallets)
        public
        onlyOwner
        returns (bool)
    {
        require(is_whiteListed[_which],ERR_AUTHORIZED_ADDRESS_ONLY);
        UserDetails storage details = user_details[_which];
        details.maxWallets = _maxWallets;
        return true;
    }

    /**
     * @dev once user whiltelisted they can add more address itself
     * @param _which The address which was whitelisted.
     * @return true if transcation success
     */
    function addMoreWallets(address _which)
        public
        notZeroAddress(_which)
        returns (bool)
    {
        require(address_belongs[_which] == address(0), ERR_AUTHORIZED_ADDRESS_ONLY);
        
        address sender = msg.sender;
        
        address primaryAddress = address_belongs[sender];
        
        require(
            is_whiteListed[primaryAddress] && sender == primaryAddress,
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

    function getUserWallets(address _whom)
        public
        view
        returns (address[] memory)
    {
        UserDetails storage details = user_details[_whom];
        return details.wallets;
    }

    // when user kyc or Aml expire
    function walletExpires(address _which) public onlySystem() returns (bool) {
        require(is_whiteListed[_which], "ERR_ACTION_NOT_ALLOWED");
        address primaryAddress = address_belongs[_which];
        UserDetails storage details = user_details[primaryAddress];
        details.canRecive = false;
        return true;
    }

    function walletRenewed(address _which) public onlySystem() returns (bool) {
        require(is_whiteListed[_which], "ERR_ACTION_NOT_ALLOWED");
        address primaryAddress = address_belongs[_which];
        UserDetails storage details = user_details[primaryAddress];
        details.canRecive = true;
        return true;
    }

    /**
     * @dev function to check if user can recive token or not
     * @param _which The address which was blocked or unblocked.
     */
    function canReciveToken(address _which) public view returns (bool) {
        address primaryAddress = address_belongs[_which];
        return user_details[primaryAddress].canRecive;
    }

    /**
     * @dev function to check if address whitelisted or not
     * @param _which The address which was whitelisted.
     */
    function isWhiteListed(address _which) public view returns (bool) {
        address primaryAddress = address_belongs[_which];
        return is_whiteListed[primaryAddress];
    }

    /**
     * @dev function to check if transfer allowed between whitelist type
     * @param _which The address which was whitelisted.
     */
    function isTransferAllowed(address _which) public view returns (bool) {
        address primaryAddress = address_belongs[_which];
        return allowed_in_secondary[user_details[primaryAddress].whiteListType];
    }

    /**
     * @dev function to set primary whiteList type allowed
     * @param _whiteListType is array for type of account .
     * @param _isAlloweded is array for bool.
     */
    function changeAllowInPrimary(
        uint256[] memory _whiteListType,
        bool[] memory _isAlloweded
    ) public onlySystem() returns (bool) {
        require(_whiteListType.length == _isAlloweded.length);
        for (uint256 temp_x = 0; temp_x < _whiteListType.length; temp_x++) {
            allowed_in_primary[_whiteListType[temp_x]] = _isAlloweded[temp_x];
        }
        return true;
    }

    /**
     * @dev function to set primary whiteList type allowed
     * @param _whiteListType is array for type of account .
     * @param _isAlloweded is array for bool.
     */
    function changeAllowInSecondary(
        uint256[] memory _whiteListType,
        bool[] memory _isAlloweded
    ) public onlySystem() returns (bool) {
        require(_whiteListType.length == _isAlloweded.length);
        
        for (uint256 temp_x = 0; temp_x < _whiteListType.length; temp_x++) {
            allowed_in_secondary[_whiteListType[temp_x]] = _isAlloweded[temp_x];
        }
        return true;
    }

    // check before transfer
    function checkBeforeTransfer(address _from, address _to)
        public
        view
        returns (bool)
    {
        if (!isWhiteListed(_from)) return false;

        if (!isWhiteListed(_to)) return false;

        if (!canReciveToken(_to)) return false;

        if (!isTransferAllowed(_to)) return false;

        return true;
    }
}