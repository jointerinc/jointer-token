pragma solidity ^0.5.9;

contract IToken {
    
    function mintTokens(uint256 _amount) public returns(bool);
    
    function buyTokens(address _fromToken, uint256 _amount) public returns(uint256);
    
    function burn(uint256 _value) external returns (bool);
    
    function lockToken(address _which,uint256 _amount,uint256 _locktime) external returns(bool);
}