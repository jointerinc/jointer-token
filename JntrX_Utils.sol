pragma solidity 0.5.9;
import './SafeMath.sol';
import './Ownable.sol';




contract JntrX_Utils is Ownable,SafeMath {


    // $1 = 100
    uint256  public tokenPrice = 100;

    //100% = 1000;
    uint public levarage = 0;


    uint256 public tokenMaturityDays = 3652;


    uint256 public tokenSaleStartDate = 0;

    //100% = 1000;
    uint public tokenCarry = 100;

    address public smartSwap = address(0);

    address public jntrAddress = address(0);

    address public jntrEAddress = address(0);

    address public whiteListAddress = address(0);

    bool public tokenSwap = true;

    address public smartSwapAddress = address(0);

    address public liquidityProvider = address(0);

    address public downsideProtection = address(0);

     uint256 public holdBackDays = 90;


    constructor(address _secondaryOwner,address _systemAddress) public Ownable(_secondaryOwner,_systemAddress){

    }

    function setTokenPrice(uint _tokenPrice) public onlySystem returns(bool){
        tokenPrice = _tokenPrice;
        return true;
    }


    function setTokenCarry(uint _tokenCarry) public onlySystem returns(bool){
        tokenCarry = _tokenCarry;
        return true;
    }

    function setTokenMaturityDays(uint _tokenMaturityDays) public onlySystem returns(bool){
        tokenMaturityDays = _tokenMaturityDays;
        return true;
    }

    function setLiquidityProtectionSmartSwap(address _liquidityProvider,address _downsideProtection,address _smartSwapAddress) public onlySystem returns(bool){
        liquidityProvider = _liquidityProvider;
        downsideProtection = _downsideProtection;
        smartSwapAddress = _smartSwapAddress;
        return true;
    }


    function setJntrE_Jntr(address _jntrEAddress,address _jntrAddress) public onlySystem returns(bool){
        jntrEAddress = _jntrEAddress;
        jntrAddress = _jntrAddress;
        return true;
    }

    function setTokenSwap(bool _tokenSwap) public onlySystem returns(bool){
        tokenSwap = _tokenSwap;
        return true;
    }

    function setWhiteListAddress(address _which) public onlySystem returns(bool){
        whiteListAddress = _which;
        return true;
    }

    function setLevarge(uint _levarage) public onlySystem returns(bool){
        levarage = _levarage;
        return true;
    }

    function setHoldBackDays(uint256 _holdBackDays) public onlySystem returns(bool){
        holdBackDays = _holdBackDays;
        return true;
    }


    function getIsTokenMaturityDate() public view returns(bool){
        uint256 tempDay = safeMul(86400,tokenMaturityDays);
        uint256 isMaturityDate = safeAdd(tempDay,tokenSaleStartDate);
        if(now >= isMaturityDate){
            return true;
        }
        return false;
    }

     function isHoldBackPeriodOver() public  view returns(bool){
        uint256 tempDay = safeMul(86400,holdBackDays);
        uint256 holdBackDaysEndDay = safeAdd(tempDay,tokenSaleStartDate);
        if(now >= holdBackDaysEndDay){
            return true;
        }
        return false;
    }


}
