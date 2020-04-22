pragma solidity ^0.5.9;

import "../Proxy/Upgradeable.sol";
import "../InterFaces/IWhiteList.sol";
import "./SuperTokenUtils.sol";

interface InitializeInterface {
    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _tokenPrice,
        uint256 _tokenMaturityDays,
        uint256 _tokenHoldBackDays
    ) external;
    
    function premint(address[] calldata _which,uint256[] calldata _amount) external;
}



contract SuperToken is Upgradeable, SuperTokenUtils, InitializeInterface {
    
    bool public preminted;
    
     function initialize(
        string memory _name,
        string memory _symbol,
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _tokenPrice,
        uint256 _tokenMaturityDays,
        uint256 _tokenHoldBackDays
        ) public 
        notZeroValue(bytes(_name).length) 
        notZeroValue(bytes(_symbol).length)
        notZeroValue(_tokenPrice)
        notZeroAddress(_registeryAddress)
        {
        
            super.initialize();
            ProxyOwnable.initializeOwner(_primaryOwner,_systemAddress,_authorityAddress);
            registry = IAuctionRegistery(_registeryAddress);
            tokenPrice = _tokenPrice;
            tokenSaleStartDate = now;
            tokenMaturityDays = _tokenMaturityDays;
            tokenHoldBackDays = _tokenHoldBackDays;
        
        }
    
    function premint(address[] calldata _which,uint256[] calldata _amount) external{
        require(_which.length == _amount.length,"ERR_NOT_SAME_LENGHT");
        require(preminted == false,"ERR_ALREADY_PREMINTED");
        for(uint256 tempX=0 ; tempX < _which.length ; tempX++){
            _mint(_which[tempX],_amount[tempX]);
        }
        preminted = true;
    }
    
    
    function checkBeforeTransfer(address _from, address _to)
        internal
        view
        returns (bool)
    {
        
        address whiteListAddress = getAddressOf(WHITE_LIST);
        if (IWhiteList(whiteListAddress).isAddressByPassed(msg.sender) == false) {
            require(IWhiteList(whiteListAddress).checkBeforeTransfer(_from, _to),"ERR_TRANSFER_CHECK_WHITELIST");
            require(!isTokenMature() && isHoldbackDaysOver(),"ERR_ACTION_NOT_ALLOWED");
        }
        return true;
    
    }
    
    function transfer(address _to, uint256 _value) public returns (bool ok) {
        require(checkBeforeTransfer(msg.sender, _to));
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value)
        public
        returns (bool)
    {
        require(checkBeforeTransfer(_from, _to));
        return super.transferFrom(_from, _to, _value);
    }
    
    function() external payable {
        revert();
    }
    
}