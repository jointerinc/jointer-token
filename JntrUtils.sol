pragma solidity 0.5.9;
import './SafeMath.sol';
import './Ownable.sol';




contract JntrUtils is Ownable,SafeMath {

    constructor(address _secondaryOwner,address _systemAddress) public Ownable(_secondaryOwner,_systemAddress){

    }


    // $1 = 100
    uint  public tokenPrice = 10;

    uint  public mintingFeesPercent = 2;

    uint public tokenMaturityYears = 10;

    uint256  public perEtherTokens = 10000;

    bool public preAuction = true;

    uint256 public tokenSaleStartDate = 0;

    uint256 public holdBackDays = 90;

    address public tokenHolderWallet = address(0);

    address public jntrEAddress = address(0);

    address public jntrXAddress = address(0);

    address public whiteListAddress = address(0);

    address public smartSwapAddress = address(0);

    address public liquidityProvider = address(0);

    address public downsideProtection = address(0);

    bool public tokenSwap = true;

    bool public systemStepIn = true;



    function setTokenPrice(uint _tokenPrice) public onlySystem   returns(bool){
        tokenPrice = _tokenPrice;
        return true;
    }

    function setMintingFees(uint _percent) public onlySystem   returns(bool){
        mintingFeesPercent=_percent;
        return true;
    }

    function setWhiteListAddress(address _which) public onlySystem returns(bool){
        whiteListAddress = _which;
        return true;
    }

    function setPerEtherTokens(uint256 _perEthToken) public onlySystem returns(bool){
        perEtherTokens=_perEthToken;
        return true;
    }


    function setHoldBackDays(uint256 _holdBackDays) public onlySystem returns(bool){
        holdBackDays = _holdBackDays;
        return true;
    }


    function setTokenMaturityYears(uint _tokenMaturityYears) public onlySystem returns(bool){
        tokenMaturityYears = _tokenMaturityYears;
        return true;
    }

    function setPreAuction(bool _isPreAuction) public onlySystem returns(bool){
        preAuction = _isPreAuction;
    }

    function setSystemStepIn(bool _systemStepIn)public onlySystem returns(bool){
        systemStepIn = _systemStepIn;
        return true;
    }


    function setTokenHolderWallet(address _who) public onlySystem returns(bool){
        tokenHolderWallet = _who;
        return true;
    }


    function setLiquidityProtectionSmartSwap(address _liquidityProvider,address _downsideProtection,address _smartSwapAddress) public onlySystem returns(bool){
        liquidityProvider = _liquidityProvider;
        downsideProtection = _downsideProtection;
        smartSwapAddress = _smartSwapAddress;
        return true;
    }


    function setJntrE_JntrX(address _jntrEAddress,address _jntrXAddress) public onlySystem returns(bool){
        jntrEAddress = _jntrEAddress;
        jntrXAddress = _jntrXAddress;
        return true;
    }


    function setTokenSwap(bool _tokenSwap) public onlySystem returns(bool){
        tokenSwap = _tokenSwap;
        return true;
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
