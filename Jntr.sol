pragma solidity 0.5.9;
import './ERC20.sol';
import './JntrUtils.sol';


contract WhiteList{
    function isWhiteListed(address _who) public view returns(bool);
    function canSentToken(address _which)public view returns (bool);
    function canReciveToken(address _which)public view returns (bool);
    function isTransferAllowed(address _who)public view returns(bool);

}

contract Token {
    function swapForToken(uint256 _tokenPrice,address _to,uint256 _value) public returns (bool);
}


contract Jntr is ERC20,JntrUtils{

    string public constant name = "Jointer Token";

    string public constant symbol = "JNTR";

    uint public totalSupply = 0 ;

    uint public constant decimals = 18;


    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;


    constructor(uint256 reserveSupply,
                uint256 holdBackSupply,
                address _secondaryOwner,
                address _systemAddress,
                address _tokenHolderWallet,
                address _whiteList) public JntrUtils(_secondaryOwner,_systemAddress){

        reserveSupply = reserveSupply * 10 ** uint256(decimals);
        holdBackSupply = holdBackSupply * 10 ** uint256(decimals);
        _mint(address(this),reserveSupply);
        _mint(_tokenHolderWallet,holdBackSupply);
        tokenHolderWallet = _tokenHolderWallet;
        whiteListAddress = _whiteList;
        tokenSaleStartDate = now;
    }


    function _transfer(address _from,address _to, uint _value) internal returns (bool) {
        uint256 senderBalance = balances[_from];
        require(senderBalance >= _value,"BALANCE_ERR");
        senderBalance = safeSub(senderBalance, _value);
        balances[_from] = senderBalance;
        balances[_to] = safeAdd(balances[_to],_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function _burn(address _from,uint _value) internal returns (bool){
        uint256 senderBalance = balances[_from];
        require(senderBalance >= _value,"BALANCE_ERR");
        senderBalance = safeSub(senderBalance, _value);
        balances[_from] = senderBalance;
        totalSupply = safeSub(totalSupply, _value);
        emit Transfer(_from, address(0), _value);
        return true;
    }

    function _mint(address _to,uint _value) internal returns(bool){
        balances[_to] = safeAdd(balances[_to],_value);
        totalSupply = safeAdd(totalSupply, _value);
        emit Transfer(address(0),_to, _value);
        return true;
    }

    function balanceOf(address _who) public view returns (uint256) {
        return balances[_who];
    }

    function transfer(address _to, uint256 _value) public returns (bool ok) {

        WhiteList whiteList = WhiteList(whiteListAddress);
        require(whiteList.isWhiteListed(msg.sender) || whiteList.canSentToken(msg.sender),"SENDER_ERROR");

        if(_to == jntrEAddress || _to == jntrXAddress){
            require(tokenSwap,"TokenSwap Error");
            Token token = Token(_to);
            _transfer(msg.sender,address(this),_value);
            return token.swapForToken(tokenPrice,msg.sender,_value);
        }else{

            require(whiteList.isWhiteListed(_to) || whiteList.canReciveToken(_to),"RECIVER_ERROR");

            if(msg.sender == smartSwapAddress ||  msg.sender == liquidityProvider || msg.sender == downsideProtection){
                return _transfer(msg.sender,_to,_value);
            }

            require(whiteList.isTransferAllowed(_to) || isHoldBackPeriodOver(),"T_NOT_ALLOED");
            return _transfer(msg.sender,_to,_value);
        }
    }


    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function approve(address _spender, uint _value) public returns (bool) {
        if(isHoldBackPeriodOver() || _spender == smartSwapAddress||  _spender == liquidityProvider || _spender == downsideProtection){
            allowed[msg.sender][_spender] = _value;
            emit Approval(msg.sender, _spender, _value);
            return true;
        }
        return false;
    }


    function transferFrom(address _from, address _to, uint256 _value) public returns (bool ok) {
        require(allowed[_from][msg.sender] >= _value && balances[_from] >= _value);
        WhiteList whiteList = WhiteList(whiteListAddress);
        require(whiteList.isWhiteListed(_to),"RECIVER_ERROR");
        require(whiteList.isTransferAllowed(_to),"T_NOT_ALLOED");
        bool is_transferd = _transfer(_from,_to,_value);
        require(is_transferd);
        allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender],_value);
        return true;
    }


    function assignToken(address _to,uint256 _value) public onlySystem returns (bool){
        if(balances[address(this)] >= _value){
           return _transfer(address(this),_to,_value);
        }else{
            uint256 _remaningToken = safeSub(_value,balances[address(this)]);
            _transfer(address(this),_to,balances[address(this)]);
            return _mint(_to,_remaningToken);
        }
    }

    function mint(address _to,uint256 _value) public onlySystem returns (bool){
        if(preAuction){
           uint256 mintingFee = safeDiv(safeMul(_value,mintingFeesPercent),100);
            _mint(_to,_value);
            return _mint(tokenHolderWallet,mintingFee);
        }else{
            return _mint(_to,_value);
        }

    }

    function burn(uint256 _value) public onlySystem returns (bool){
        return _burn(address(this),_value);
    }


    function swapForToken(uint256 _tokenPrice,address _to,uint256 _value) public returns (bool){
        require(msg.sender == jntrXAddress || msg.sender == jntrEAddress ,"sender is not valid");
        uint256 _assignToken = safeDiv(safeMul(_value,_tokenPrice),tokenPrice);
        if(balances[address(this)] >= _assignToken){
          return _transfer(address(this),_to,_assignToken);
        }else{
            uint256 _remaningToken = safeSub(_assignToken,balances[address(this)]);
            _transfer(address(this),_to,balances[address(this)]);
            return _mint(_to,_remaningToken);
        }

    }



    function () external payable{
       revert();
    }



}
