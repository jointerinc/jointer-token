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
        uint256 reserveSupply,
        uint256 _holdBackSupply
    ) external;
}



contract SuperToken is Upgradeable, SuperTokenUtils, InitializeInterface {
    
     function initialize(
        string memory _name,
        string memory _symbol,
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _tokenPrice,
        uint256 _tokenMaturityDays,
        uint256 _tokenHoldBackDays,
        uint256 reserveSupply,
        uint256 holdBackSupply) public 
        notZeroValue(bytes(_name).length) 
        notZeroValue(bytes(_symbol).length)
        notZeroValue(_tokenPrice)
        notZeroAddress(_registeryAddress){
        
        super.initialize();
        ProxyOwnable.initializeOwner(_primaryOwner,_systemAddress,_authorityAddress);
        registry = IAuctionRegistery(_registeryAddress);
        tokenPrice = _tokenPrice;
        tokenSaleStartDate = now;
        tokenMaturityDays = _tokenMaturityDays;
        tokenHoldBackDays = _tokenHoldBackDays;
        
        //if (reserveSupply > 0) _mint(address(this), reserveSupply);
        //if (holdBackSupply > 0) _mint(_tokenHolderWallet, holdBackSupply);
            
        }
    
}