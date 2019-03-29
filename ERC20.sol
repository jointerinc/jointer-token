pragma solidity ^0.4.18;


// accepted from zeppelin-solidity https://github.com/OpenZeppelin/zeppelin-solidity
/*
 * ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
 
contract ERC20  {
    
  uint public totalSupply;
  
  function balanceOf(address _who) public constant returns (uint);
  
  function allowance(address _owner, address _spender) public constant returns (uint);

  function transfer(address _to, uint _value) public returns (bool ok);
  
  function transferFrom(address _from, address _to, uint _value) public returns (bool ok);
  
  function approve(address _spender, uint _value) public returns (bool ok);
  
  event Transfer(address indexed from, address indexed to, uint value);
  
  event Approval(address indexed owner, address indexed spender, uint value);

    
}