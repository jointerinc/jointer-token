pragma solidity ^0.5.9;

import '../common/Ownable.sol';
import '../common/SafeMath.sol';

contract IndividualBonus is Ownable,SafeMath{
    
    
    uint256 public X_200 = 200;
    
    uint256 public X_175 = 175;
    
    uint256 public X_150 = 150;
    
    uint256 public X_125 = 125;
    
    uint256 public X_100 = 100;
    
    mapping(uint256 => uint256) public percentReturn;
    
    
    constructor(address _systemAddress,address _multisigAdress) public Ownable(_systemAddress,_multisigAdress){
        
       for(uint256 tempX=0;tempX<101;tempX++){
           
        if(tempX >= 95)
            percentReturn[tempX] = X_200;
        else if(tempX >= 75)
            percentReturn[tempX] = X_175;
        else if(tempX >= 50)
            percentReturn[tempX] = X_150;
        else if(tempX >= 25)
            percentReturn[tempX] = X_125;
        else
            percentReturn[tempX] = X_100;
        
       }
        
    }
    
    
    function updatePercentReturn(uint256 _from,uint256 _to,uint256 _percent) public onlySystem() returns ( bool ){
        for(uint256 tempX=_from ; tempX<_to ; tempX++)
            percentReturn[tempX] = _percent;
        return true;
    }
    
    
    function calucalteBonus(uint256 _tolalInvestMent,uint256 _userInvestMent,uint256 returnAmount) public view returns ( uint256 ){
        uint256 percent =  safeDiv(safeMul(_userInvestMent,100),_tolalInvestMent);
        
        returnAmount = safeDiv(safeMul(returnAmount,percentReturn[percent]),100);
        
        return returnAmount;
    }
    
    
    
    
}