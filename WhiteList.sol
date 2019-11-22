pragma solidity 0.5.9;

import './Ownable.sol';
import './SafeMath.sol';

contract WhiteList is Ownable,SafeMath{


    constructor(address _secondaryOwner,address _systemAddress) public Ownable(_secondaryOwner,_systemAddress){
        whiteListAccount(msg.sender,0);
        whiteListAccount(_secondaryOwner,0);
        whiteListAccount(_systemAddress,0);
        allowedInPrimary[0] = true;
        allowedInSecondary[0] = true;
    }

    event AccountWhiteListed(address indexed which ,uint walletType);
    event WalletAdded(address indexed from,address indexed which);

    struct UserDetails{
        string  email;
        string name;
        string phone;
    }

    uint thresholdKycRenewale = 0;
    uint thresholdTransctions = 0;

    mapping (address => bool) public is_whiteListed;
    mapping (address => uint) public whitelist_type;
    mapping (address => address) public address_belongs;
    mapping (address => UserDetails) public user_details;
    mapping (address => bool) public recive_block;
    mapping (address => bool) public sent_block;
    mapping (uint => bool) public allowedInPrimary;
    mapping (uint => bool) public allowedInSecondary;


    function whiteListAccount(address _address,uint _whiteListType) internal returns (bool){
        is_whiteListed[_address] = true;
        whitelist_type[_address] = _whiteListType;
        address_belongs[_address] = _address;
        emit AccountWhiteListed(_address,_whiteListType);
        return true;
    }


    function addNewWallet(address _address,uint _whiteListType) public onlySystem returns(bool){
        require(address_belongs[_address] == address(0));
        return whiteListAccount(_address,_whiteListType);
    }

    function addMoreWallets(address _which) public returns (bool){
        require(address_belongs[_which] == address(0));
        address sender = msg.sender;
        address primaryAddress = address_belongs[sender];
        require(is_whiteListed[primaryAddress]);
        address_belongs[_which] = primaryAddress;
        emit WalletAdded(primaryAddress,_which);
        return true;
    }


    function setThresholdTransctions(uint _thresholdTransctions) public onlySystem returns (bool){
        thresholdTransctions = _thresholdTransctions;
        return true;
    }

    function setCanRecive(address _which,bool recive)public onlySystem returns (bool){
        recive_block[_which] = recive;
        return true;
    }

    function canSentToken(address _which)public view returns (bool){
        address primaryAddress = address_belongs[_which];
        return !sent_block[primaryAddress];

    }

    function canReciveToken(address _which)public view returns (bool){
        address primaryAddress = address_belongs[_which];
        return !recive_block[primaryAddress];
    }


    function setCansent(address _which,bool sent)public onlySystem returns (bool){
        recive_block[_which] = sent;
        return true;
    }

    function setThresholdKycRenewal(uint _thresholdKycRenewale) public onlySystem returns (bool){
        thresholdKycRenewale = _thresholdKycRenewale;
        return true;
    }

    function isWhiteListed(address _who) public view returns(bool){
        address primaryAddress = address_belongs[_who];
        return is_whiteListed[primaryAddress];
    }

    function isTransferAllowed(address _who) public view returns(bool){
        address primaryAddress = address_belongs[_who];
        uint accountType = whitelist_type[primaryAddress];
        return allowedInSecondary[accountType];
    }

    function changeAllowInPrimary(uint[] memory _whiteListType , bool[] memory isAlloweded) public onlySystem returns (bool){
        require( _whiteListType.length == isAlloweded.length);
        for(uint temp_x = 0 ; temp_x < _whiteListType.length ; temp_x ++){
            allowedInPrimary[_whiteListType[temp_x]] = isAlloweded[temp_x];
        }
        return true;

    }

    function changeAllowInSecondary(uint[] memory _whiteListType , bool[] memory isAlloweded) public onlySystem returns (bool){
        require( _whiteListType.length == isAlloweded.length);
        for(uint temp_x = 0 ; temp_x < _whiteListType.length ; temp_x ++){
            allowedInSecondary[_whiteListType[temp_x]] = isAlloweded[temp_x];
        }
        return true;

    }


}
