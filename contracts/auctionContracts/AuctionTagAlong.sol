pragma solidity ^0.5.9;

import "../common/SafeMath.sol";
import "../common/Ownable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IAuctionProtection.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/IAuctionFormula.sol";
import "../InterFaces/IAuction.sol";
import "../InterFaces/ITokenVault.sol";



contract AuctionRegistery is Ownable, AuctionRegisteryContracts {
    
    IAuctionRegistery public contractsRegistry;
    
    function updateRegistery(address _address)
        external
        onlyAuthorized()
        notZeroAddress(_address)
        returns (bool)
    {
        
        contractsRegistry = IAuctionRegistery(_address);
        return true;
    }

    function getAddressOf(bytes32 _contractName)
        internal
        view
        returns (address)
    {
        return contractsRegistry.getAddressOf(_contractName);
    }
}

contract Utils is AuctionRegistery,SafeMath{
    
    uint256 public liquadityRatio = 100;
    
    uint256 public contributionRatio = 100;
    
    function setLiquadityRatio(uint256 _ratio) external onlySystem() returns(bool) {
        liquadityRatio = _ratio;
        return true;
    }
    
    function setcContributionRatio(uint256 _ratio) external onlySystem() returns(bool) {
        contributionRatio = _ratio;
        return true;
    }
    
}

contract AuctionTagAlong is Utils{
    
    
    constructor(address _systemAddress,
                address _multisigAdress
                ) public Ownable(_systemAddress,_multisigAdress){
     
    }
    
    event FundDeposited(
            address _token,
            address _from,
            uint256 _amount
        );
    
    
    
    
    function ensureTransferFrom(
                IERC20Token _token,
                address _from,
                address _to,
                uint256 _amount
            ) internal {
            
        uint256 prevBalance = _token.balanceOf(_to);
        if (_from == address(this))
            _token.transfer(_to, _amount);
        else
            _token.transferFrom(_from, _to, _amount);
        uint256 postBalance = _token.balanceOf(_to);
        require(postBalance > prevBalance);
    }
    
    function approveTransferFrom(
                IERC20Token _token,
                address _spender, 
                uint256 _amount
            ) internal {
        _token.approve(_spender, _amount);
    }
    
    
    //when we staring contrinution with token then we have to develop 
    //address and uint256 from token 
    function contributeTowardAuction(uint256 _amount) public  returns(uint256,address[] memory,uint256[] memory){
        require(msg.sender == getAddressOf(AUCTION),"ERR_ONLY_AUCTION_ALLWOED");
        uint256 _currencyPrices = ICurrencyPrices(getAddressOf(CURRENCY)).getCurrencyPrice(address(0));
        _amount = safeDiv(safeMul(_amount,contributionRatio),100);
        uint256 ethAmount = safeDiv(_amount,_currencyPrices);
        address[] memory a;
        uint256[] memory b;
        if(ethAmount > address(this).balance ){
            ethAmount = address(this).balance;
            msg.sender.transfer(ethAmount);
            return (ethAmount,a,b);
        }
        msg.sender.transfer(ethAmount);
        return (ethAmount,a,b);
        
    }
    
    function() external payable {
        emit FundDeposited(
            address(0),
            msg.sender,
            msg.value
        );
    }
    
    function cancelInvestment() public onlyOwner() returns (bool) {
        return IAuctionProtection(getAddressOf(AUCTION_PROTECTION)).cancelInvestment();
    }
    
    function unLockTokens() public onlyOwner() returns (bool) {
        return IAuctionProtection(getAddressOf(AUCTION_PROTECTION)).unLockTokens();
    }
    
    function returnTokens(IERC20Token _tokens, address _to, uint256 _value)
        external
        onlyOwner()
        returns (bool)
    {
        ensureTransferFrom(_tokens, address(this), _to, _value);
        return true;
    }

    function withDraw(uint256 _value) external onlyOwner() returns (bool) {
        msg.sender.transfer(_value);
        return true;
    }
    
}