pragma solidity ^0.4.18;

import './Ownable.sol';


contract ST20 is Ownable{
    
    bool public isPublic = false;
    
    uint256 public totalWhiteListAccounts = 0;
    
    uint256 public totalAllowedAccounts = 2000;
    
    mapping (address => bool) public allowedAccount;
    
    mapping (address => bool) public isBlackListed;
    
    
    event AddedAllowedAccount(address _who);
    event RemovedAllowedAccount(address _who);
    event TotalAllowedAccountsChanged(address _who,uint256 _old,uint256 _new);
    event AddedBlackListAccount(address _who);
    event RemovedBlackListAccount(address _who);
     
    function addBlackList(address _who) public onlyOwner {
        isBlackListed[_who] = true;
        emit AddedBlackListAccount(_who);
    }

    function removeBlackList(address _who) public onlyOwner {
        isBlackListed[_who] = false;
        emit RemovedBlackListAccount(_who);
    }
  
    function verifyAddress(address _who) internal view returns (bool){
        
        if(isPublic == false){
            require(allowedAccount[_who] == true,"account is not in whitelist");
        }
        
        require(isBlackListed[_who] == false);
        require(_who != address(this),"you can't transfer token to contract address");
        
        return true; 
    }
    
    
    function addAllowedAccount(address _who) public onlyOwner returns (bool){
        require(totalWhiteListAccounts  <= totalAllowedAccounts &&
        allowedAccount[_who] == false);
        
        allowedAccount[_who] = true;
        totalWhiteListAccounts += 1;
        emit AddedAllowedAccount(_who);
        return true;
    }
    
    
    function removeAllowedAccount(address _who) public onlyOwner returns (bool){
        require(allowedAccount[_who] == true);
        allowedAccount[_who] = false;
        totalWhiteListAccounts -= 1;
        emit RemovedAllowedAccount(_who);
        return true;
    }
    
    function setTotalAllowedAccounts(uint256 _number) public onlyOwner returns (bool){
        emit TotalAllowedAccountsChanged(msg.sender,totalAllowedAccounts,_number);
        totalAllowedAccounts = _number;
    }
   
    function openForpublic() public onlyOwner returns(bool){
        isPublic = true;
    }
    
    function closeForpublic() public onlyOwner returns(bool){
        isPublic = false;
    }
    
}