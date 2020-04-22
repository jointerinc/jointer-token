pragma solidity 0.5.9;
import "./StandardToken.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/ICurrencyPrices.sol";


contract AuctionRegistery is ProxyOwnable, AuctionRegisteryContracts {
    
    IAuctionRegistery public registry;
    IAuctionRegistery public prevRegistry;

    function updateRegistery(address _address)
        external
        onlyAuthorized()
        notZeroAddress(_address)
        returns (bool)
    {
        prevRegistry = registry;
        registry = IAuctionRegistery(_address);
        return true;
    }

    function getAddressOf(bytes32 _contractName)
        internal
        view
        returns (address)
    {
        return registry.getAddressOf(_contractName);
    }
}


contract TokenMinter is StandardToken,AuctionRegistery {
    
    mapping(address=>bool) tokenMinters;
    
    mapping(address => uint256) public minterIndex;
    
    address[] public minters;
   
    modifier onlyMinter() {
        require(tokenMinters[msg.sender],ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }
    
    function addMinter(address _which) external onlyAuthorized() returns(bool){
        require(!tokenMinters[_which],ERR_AUTHORIZED_ADDRESS_ONLY);
        tokenMinters[_which] = true;
        minterIndex[_which] = minters.length;
        minters.push(_which);
        return true;
        
    }
    
    function removeMinter(address _which) external onlyAuthorized() returns(bool){
        
        require(tokenMinters[_which],ERR_AUTHORIZED_ADDRESS_ONLY);
        
        uint256 _minterIndex = minterIndex[_which];
        address _lastAdress = minters[safeSub(minters.length, 1)];
        minters[_minterIndex] = _lastAdress;
        minterIndex[_lastAdress] = _minterIndex;
        delete tokenMinters[_which];
        delete minters[safeSub(minters.length, 1)];
        return true;
        
    }
    
    
    function mintTokens(uint256 _amount) external onlyMinter() returns(bool){
        return _mint(msg.sender, _amount);
    }
    
}




contract ForceSwap is StandardToken,AuctionRegistery {
    
    address public returnToken;
    
    function setReturnToken(address _which) external onlySystem() returns(bool){
        require(returnToken == address(0),"ERR_ACTION_NOT_ALLOWED");
        returnToken = _which;
    }
    
    function forceSwap(address _which,uint256 _amount) external onlySystem() returns(bool){
        require(returnToken != address(0),"ERR_ACTION_NOT_ALLOWED");
        _burn(_which,_amount);
        ICurrencyPrices currencyPrice = ICurrencyPrices(getAddressOf(CURRENCY));
        uint256 retunTokenPrice = currencyPrice.getCurrencyPrice(returnToken);
        uint256 currentTokenPrice = currencyPrice.getCurrencyPrice(address(this));
        uint256 _assignToken = safeDiv(safeMul(_amount,currentTokenPrice),retunTokenPrice);
        //
    }
    
}


contract SuperTokenUtils is TokenMinter {
    
    uint256 public tokenPrice;
    
    uint256 public tokenSaleStartDate ;

    uint256 public tokenMaturityDays ;

    uint256 public tokenHoldBackDays ;
    
    function isTokenMature() public view returns (bool) {
        if (tokenMaturityDays == 0) return false;
        uint256 tempDay = safeMul(86400, tokenMaturityDays);
        uint256 tempMature = safeAdd(tempDay, tokenSaleStartDate);
        if (now >= tempMature) {
            return true;
        }
        return false;
    }
    
    function isHoldbackDaysOver() public view returns (bool) {
        uint256 tempDay = safeMul(86400, tokenHoldBackDays);

        uint256 holdBackDaysEndDay = safeAdd(tempDay, tokenSaleStartDate);

        if (now >= holdBackDaysEndDay) {
            return true;
        }

        return false;
    }
    
    
}