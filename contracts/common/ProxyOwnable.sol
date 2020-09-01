pragma solidity ^0.5.9;

import "./Constant.sol";


contract ProxyOwnable is Constant {
    
    address public primaryOwner;

    address public authorityAddress;

    address public newAuthorityAddress;

    address public systemAddress;
    
    bool public isOwnerInitialize = false;

    event OwnershipTransferred(
        string ownerType,
        address indexed previousOwner,
        address indexed newOwner
    );
    
    event AuthorityAddressChnageCall(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev The Ownable constructor sets the `primaryOwner` and `systemAddress` and '_multisigAddress'
     * account.
     */

    function initializeOwner(
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress
    ) internal notZeroAddress(_primaryOwner) notZeroAddress(_systemAddress) notZeroAddress(_authorityAddress) {
        
        require(!isOwnerInitialize,"ERR_OWNER_INTIALIZED_ALREADY");
        
        require(_primaryOwner != _systemAddress, ERR_SAME_ADDRESS);
        
        require(_systemAddress != _authorityAddress, ERR_SAME_ADDRESS);
        
        require(_primaryOwner != _authorityAddress, ERR_SAME_ADDRESS);
        
        primaryOwner = _primaryOwner;
        systemAddress = _systemAddress;
        authorityAddress = _authorityAddress;
        isOwnerInitialize = true;
    }

    modifier onlyOwner() {
        require(msg.sender == primaryOwner, ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    modifier onlySystem() {
        require(msg.sender == systemAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    modifier onlyOneOfOnwer() {
        require(
            msg.sender == primaryOwner || msg.sender == systemAddress,
            ERR_AUTHORIZED_ADDRESS_ONLY
        );
        _;
    }

    modifier onlyAuthorized() {
        require(msg.sender == authorityAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    /**
     * @dev change primary ownership governance 
     */
    function changePrimaryOwner()
        public
        onlyOwner()
        returns (bool)
    {
        emit OwnershipTransferred("PRIMARY_OWNER", primaryOwner, authorityAddress);
        primaryOwner = authorityAddress;
        return true;
    }

    /**
     * @dev change system address
     * @param _which The address to which is new system address
     */
    function changeSystemAddress(address _which)
        public
        onlyAuthorized()
        notThisAddress(_which)
        notZeroAddress(_which)
        returns (bool)
    {
        require(
            _which != systemAddress &&
                _which != authorityAddress &&
                _which != primaryOwner,
            ERR_SAME_ADDRESS
        );
        emit OwnershipTransferred("SYSTEM_ADDRESS", systemAddress, _which);
        systemAddress = _which;
        return true;
    }

    /**
     * @dev change system address
     * @param _which The address to which is new Authority address
     */
    function changeAuthorityAddress(address _which)
        public
        onlyAuthorized()
        notZeroAddress(_which)
        returns (bool)
    {
        require(
            _which != systemAddress &&
                _which != authorityAddress,
            ERR_SAME_ADDRESS
        );
        newAuthorityAddress = _which;
        return true;
    }

    function acceptAuthorityAddress() public returns (bool) {
        require(msg.sender == newAuthorityAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        emit OwnershipTransferred(
            "AUTHORITY_ADDRESS",
            authorityAddress,
            newAuthorityAddress
        );
        authorityAddress = newAuthorityAddress;
        newAuthorityAddress = address(0);
        return true;
    }
}
