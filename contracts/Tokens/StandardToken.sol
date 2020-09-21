pragma solidity ^0.5.9;

import "./IBEP20.sol";
import "../common/SafeMath.sol";
import "../common/Ownable.sol";


contract StandardToken is IBEP20, SafeMath, Ownable {
    
    uint256 public totalSupply;
    
    string public name;

    string public symbol;
 
    uint256 public constant decimals = 18;

    mapping(address => uint256) balances;

    mapping(address => mapping(address => uint256)) allowed;
    
    constructor(string memory _name,
                string memory _symbol,
                address _systemAddress,
                address _authorityAddress) public Ownable(_systemAddress,_authorityAddress)  {
                    
        require(bytes(_name).length > 0 && bytes(_symbol).length > 0);
        name = _name;
        symbol = _symbol;
    }

    event Mint(address indexed _to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event TransferFrom(
        address indexed spender,
        address indexed _from,
        address indexed _to
    );
    
    
    /**
     * @dev transfer token for a specified address
     * @param _from The address from token transfer.
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     */
    function _transfer(address _from, address _to, uint256 _value)
        internal
        returns (bool)
    {
        uint256 senderBalance = balances[_from];
        require(senderBalance >= _value, "ERR_NOT_ENOUGH_BALANCE");
        senderBalance = safeSub(senderBalance, _value);
        balances[_from] = senderBalance;
        balances[_to] = safeAdd(balances[_to], _value);
        emit Transfer(_from, _to, _value);
        return true;
    }
    
     /**
     * @dev Transfer tokens from one address to another
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer tokens
     * @param _value uint256 the amount of tokens to be transferred
     */
    function _transferFrom(address _from, address _to, uint256 _value)
        internal
        notThisAddress(_to)
        notZeroAddress(_to)
        returns (bool)
    {
        require(allowed[_from][msg.sender] >= _value, "ERR_NOT_ENOUGH_BALANCE");
        require(_transfer(_from, _to, _value));
        allowed[_from][msg.sender] = safeSub(
            allowed[_from][msg.sender],
            _value
        );
        emit TransferFrom(msg.sender, _from, _to);
        return true;
    }
    
    function _approve(address owner, address spender, uint256 amount) internal notZeroAddress(spender) {
        
        allowed[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function _burn(address _from, uint256 _value) internal returns (bool) {
        uint256 senderBalance = balances[_from];
        require(senderBalance >= _value, "ERR_NOT_ENOUGH_BALANCE");
        senderBalance = safeSub(senderBalance, _value);
        balances[_from] = senderBalance;
        totalSupply = safeSub(totalSupply, _value);
        emit Burn(_from, _value);
        emit Transfer(_from, address(0), _value);
        return true;
    }
    
    function _mint(address _to, uint256 _value) internal returns (bool) {
        balances[_to] = safeAdd(balances[_to], _value);
        totalSupply = safeAdd(totalSupply, _value);
        emit Mint(_to, _value);
        emit Transfer(address(0), _to, _value);
        return true;
    }
    
    
    
    /**
     * @dev Gets the balance of the specified address.
     * @param _who The address to query the the balance of.
     * @return balance An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address _who) public view returns (uint256 balance) {
        return balances[_who];
    }
    
 
    /**
     * @dev `msg.sender` approves `spender` to spend `value` tokens
     * @param _spender The address of the account able to transfer the tokens
     * @param _value The amount of wei to be approved for transfer
     * @return ok Whether the approval was successful or not
     */
    function approve(address _spender, uint256 _value)
        external
        notZeroAddress(_spender)
        returns (bool ok)
    {
        _approve(msg.sender, _spender, _value);
        return true;
    }
    
     /**
     * @dev `msg.sender` approves `spender` to increase spend `value` tokens
     * @param _spender The address of the account able to transfer the tokens
     * @param _value The amount of wei to be approved for transfer
     * @return Whether the approval was successful or not
     */
    function increaseAllowance(address _spender, uint256 _value) external  returns (bool) {
        uint256 currentAllowed = allowed[msg.sender][_spender];
        _approve(msg.sender, _spender, safeAdd(currentAllowed,_value));
        return true;
        
    }
    
     /**
     * @dev `msg.sender` approves `spender` to decrease spend `value` tokens
     * @param _spender The address of the account able to transfer the tokens
     * @param _value The amount of wei to be approved for transfer
     * @return Whether the approval was successful or not
     */
    function decreaseAllowance(address _spender, uint256 _value) external  returns (bool) {
        uint256 currentAllowed = allowed[msg.sender][_spender];
        require(currentAllowed >= _value,"ERR_ALLOWENCE");
        _approve(msg.sender, _spender, safeSub(currentAllowed,_value));
        return true;
    }


    
    /**
     * @dev to check allowed token for transferFrom
     * @param _owner The address of the account owning tokens
     * @param _spender The address of the account able to transfer the tokens
     * @return Amount of remaining tokens allowed to spent
     */
    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256)
    {
        return allowed[_owner][_spender];
    }

   

    /**
     * @dev burn token from this address
     * @param _value uint256 the amount of tokens to be burned
     */
    function burn(uint256 _value) external returns (bool) {
        return _burn(msg.sender, _value);
    }
    
    /**
    * @dev Returns the bep token owner.
    */
    function getOwner() external view returns (address) {
        return systemAddress;
    }

}