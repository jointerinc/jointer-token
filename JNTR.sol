pragma solidity ^0.4.18;
import './SafeMath.sol';
import './ERC20.sol';
import './ST20.sol';

contract JNTR is ST20,ERC20,SafeMath {
    
    string public constant name = "Jointer Token";
    string public constant symbol = "JNTR";
    uint public totalSupply = 1000000000 ether;
    uint public constant decimals = 18;
    uint256 public nonce = 0;
        
    mapping (uint256 => bool) usedNonces;
    //mapping of token balances
    mapping (address => uint256) balances;
    //mapping of allowed address for each address with tranfer limit
    mapping (address => mapping (address => uint256)) allowed;
    
    
    event Mint(address indexed _who,uint256 _value);
    event Burn(address indexed _who,uint256 _value);

  
    constructor() public{
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0),msg.sender,totalSupply);
    }
    
   
    // @param _who The address of the investor to check balance
    // @return balance tokens of investor address
    function balanceOf(address _who) public constant returns (uint) {
        return balances[_who];
    }
    
    
    function transfer(address _to, uint _value) public returns (bool ok) {
        
        require(_value > 0 && verifyAddress(msg.sender) && verifyAddress(_to));
        uint256 senderBalance = balances[msg.sender];
        //Check sender have enough balance
        require(senderBalance >= _value);
        senderBalance = safeSub(senderBalance, _value);
        balances[msg.sender] = senderBalance;
        balances[_to] = safeAdd(balances[_to],_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    
     function allowance(address _owner, address _spender)public constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
    
    // Transfer `value` Jointer tokens from sender 'from'
    // to provided account address `to`.
    // @param from The address of the sender
    // @param to The address of the recipient
    // @param value The number of Jointer to transfer
    // @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint _value) public returns (bool ok) {
        
        require(_value > 0 && verifyAddress(_from) && verifyAddress(_to));
        
        //Check amount is approved by the owner for spender to spent and owner have enough balances
        require(allowed[_from][msg.sender] >= _value && balances[_from] >= _value);
        balances[_from] = safeSub(balances[_from],_value);
        balances[_to] = safeAdd(balances[_to],_value);
        allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender],_value);
        emit Transfer(_from, _to, _value);
        return true;
    }
    
    // `msg.sender` approves `spender` to spend `value` tokens
    // @param spender The address of the account able to transfer the tokens
    // @param value The amount of wei to be approved for transfer
    // @return Whether the approval was successful or not
    function approve(address _spender, uint _value) public returns (bool) {
        require(_spender != 0);
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    

    //  Mint `amount` Jointer tokens
    // `msg.sender` to provided account and amount.
    // @param _value amount to mint token
    function mint(address _who,uint256 _value) public onlyOwner returns (bool){
        require(_value > 0);
        balances[_who] = safeAdd(balances[_who], _value);
        totalSupply = safeAdd(totalSupply,_value);
        emit Mint(_who,_value);
        emit Transfer(address(0),msg.sender,_value);
        return true;
    }
    
    //  Burn `amount` Jointer tokens
    // `msg.sender` to provided account and amount.
    // @param _value amount to burn token
    function burn (uint256 _value) public  returns (bool){
        uint256 senderBalance = balances[msg.sender];
        require(senderBalance >= _value && _value > 0);
        balances[msg.sender] = safeSub(balances[msg.sender], _value);
        totalSupply = safeSub(totalSupply,_value);
        emit Burn(msg.sender,_value);
        return true;
    }
    
    //incase there is in ether in contract 
    // @param _reciver amount in  wei
    // @param value amount in  wei
    function finaliaze(address _reciver,uint256 value) public onlyOwner returns (bool ok){
        require(address(this).balance >= value);
        _reciver.transfer(value);
        return true;
    }
    
    
  
    
   /**
   * @dev Allows reduce token from account by singed message
   * @dev this methdo called only when account sign message
   * @param _who address from token Burnt
   * @param _value uint256 token amount
   * @param _nonce uint256 check valid transctions
   * @param _msg bytes32 singed msg
   * @param _msgHash signed by account private key
   * @param v singed msg v
   * @param r singed msg r
   * @param s singed msg s
   */
    function reduceTokenByDelegateCall(address _who,
                        uint256 _value,
                        uint256 _nonce,
                        bytes32 _msg,
                        bytes32 _msgHash,
                        uint8 v, 
                        bytes32 r,
                        bytes32 s) public onlyOwner returns (bool){
        
        require(balances[_who] >= _value 
                && _nonce == nonce && 
                !usedNonces[_nonce]);
                
        usedNonces[_nonce] = true;
        nonce = safeAdd(nonce,1);
        bytes32 hashedParams =  keccak256(abi.encodePacked(address(this),_who,_value, _nonce));
        require(hashedParams == _msg);
        address from = ecrecover(_msgHash, v, r, s);
        require(_who == from);
        balances[from] = safeSub(balances[from], _value);
        totalSupply = safeSub(totalSupply,_value);
        emit Burn(_who,_value);
        emit Transfer(_who,address(0),_value);
        return true;
    }
    
    
    
    function transferTokenByDelegetCall(address _from,
                        address _to,
                        uint256 _value,
                        uint256 _nonce,
                        bytes32 _msg,
                        bytes32 _msgHash,
                        uint8 v, 
                        bytes32 r,
                        bytes32 s) public onlyOwner returns (bool){
                        
                        require(balances[_from] >= _value && 
                        _nonce == nonce && !usedNonces[_nonce] &&
                        verifyAddress(_from) && verifyAddress(_to));
                        
                        usedNonces[_nonce] = true;
                        nonce = safeAdd(nonce,1);
                        bytes32 hashedParams =  keccak256(abi.encodePacked(address(this),_from,_to,_value, _nonce));
                        require(hashedParams == _msg);
                        address from = ecrecover(_msgHash, v, r, s);
                        require(_from == from);
                        uint256 senderBalance = balances[_from];
                        senderBalance = safeSub(senderBalance, _value);
                        balances[_from] = senderBalance;
                        balances[_to] = safeAdd(balances[_to],_value);
                        emit Transfer(_from,_to,_value);
                        return true;
                    }
    
    
   
   /**
   * @dev fallback function revert if someone try to send ether
   */

    function () external payable{
       revert();
    }
    
  

    
}