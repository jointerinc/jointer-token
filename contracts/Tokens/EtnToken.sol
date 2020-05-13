pragma solidity ^0.5.9;

import "./Exchangeable.sol";
import "../InterFaces/IWhiteList.sol";


contract EtnToken is Exchangeable {
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _tokenMaturityDays,
        uint256 _tokenHoldBackDays,
        address _returnToken) public 
        TokenUtils(_name,_symbol,_systemAddress,_authorityAddress,_tokenMaturityDays,_tokenHoldBackDays,_registeryAddress)
        ForceSwap(_returnToken){
            
        }
    

    function() external payable {
        revert();
    }
    
}