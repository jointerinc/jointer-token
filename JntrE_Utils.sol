pragma solidity 0.5.9;
import './JntrX_Utils.sol';
import './Ownable.sol';




contract JntrE_Utils is Ownable,SafeMath {


    // $1 = 100
    uint256  public tokenPrice = 10000;

    address public jntrAddress = address(0);

    uint256 public tokenMaturityDays = 3652;

    address public jntrXAddress = address(0);

    address public smartSwapAddress = address(0);

    address public liquidityProvider = address(0);

    address public downsideProtection = address(0);

    bool public tokenSwap = true;

    address public whiteListAddress = address(0);


    uint256 public tokenSaleStartDate = 0;

    uint256 public holdBackDays = 90;

    uint256 public epochTime = 86400;

    constructor(address _secondaryOwner,address _systemAddress) public Ownable(_secondaryOwner,_systemAddress){

    }

    function setTokenPrice(uint _tokenPrice) public onlySystem returns(bool){
        tokenPrice = _tokenPrice;
        return true;
    }


    function setLiquidityProtectionSmartSwap(address _liquidityProvider,address _downsideProtection,address _smartSwapAddress) public onlySystem returns(bool){
        liquidityProvider = _liquidityProvider;
        downsideProtection = _downsideProtection;
        smartSwapAddress = _smartSwapAddress;
        return true;
    }


    function setJntr_JntrX(address _jntrAddress,address _jntrXAddress) public onlySystem returns(bool){
        jntrXAddress = _jntrXAddress;
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

    function setTokenMaturityDays(uint _tokenMaturityDays) public onlySystem returns(bool){
        tokenMaturityDays = _tokenMaturityDays;
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
        uint256 tempDay = safeMul(epochTime,holdBackDays);
        uint256 holdBackDaysEndDay = safeAdd(tempDay,tokenSaleStartDate);
        if(now >= holdBackDaysEndDay){
            return true;
        }
        return false;
    }

}
