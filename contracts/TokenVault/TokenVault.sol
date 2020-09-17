pragma solidity ^0.5.9;

import "./TokenVaultStorage.sol";
import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../common/TokenTransfer.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/IAuctionProtection.sol";


interface InitializeInterface {
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registryaddress
    ) external;
}

contract TokenRegistery is ProxyOwnable,TokenVaultStorage, AuctionRegisteryContracts {
    
    
    function updateRegistery(address _address)
        external
        onlyAuthorized()
        notZeroAddress(_address)
        returns (bool)
    {
        
        contractsRegistry = IAuctionRegistery(_address);
        _updateAddresses();
        return true;
    }

    function getAddressOf(bytes32 _contractName)
        internal
        view
        returns (address payable)
    {
        return contractsRegistry.getAddressOf(_contractName);
    }
    
    /**@dev updates all the address from the registry contract
    this decision was made to save gas that occurs from calling an external view function */
    
    function _updateAddresses() internal {
        auctionProtectionAddress = getAddressOf(AUCTION_PROTECTION);
    }
    
    function updateAddresses() external returns (bool) {
        _updateAddresses();
    }
}

contract TokenSpenders is TokenRegistery,SafeMath {
    
    
    modifier onlySpender() {
        require(isSpender[msg.sender],ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }
    
    // once all spender from set give authority to govenranacne 
    function addSpender(address _which) external onlyOwner() returns(bool){
        require(isSpender[_which] == false,ERR_AUTHORIZED_ADDRESS_ONLY);
        isSpender[_which] = true;
        spenderIndex[_which] = spenders.length;
        spenders.push(_which);
        emit TokenSpenderAdded(_which);
        return true;
        
    }
    
    function removeSpender(address _which) external onlyAuthorized() returns(bool){
        require(isSpender[_which],ERR_AUTHORIZED_ADDRESS_ONLY);
        uint256 _spenderIndex = spenderIndex[_which];
        address _lastAdress = spenders[safeSub(spenders.length, 1)];
        spenders[_spenderIndex] = _lastAdress;
        spenderIndex[_lastAdress] = _spenderIndex;
        delete isSpender[_which];
        spenders.pop();
        emit TokenSpenderRemoved(_which);
        return true;
        
    }
}


contract TokenVault is
    Upgradeable,
    TokenSpenders,
    InitializeInterface,
    TokenTransfer
{   
    
  
    
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registryaddress
    ) public {
        super.initialize();
        contractsRegistry = IAuctionRegistery(_registryaddress);
        _updateAddresses();
        initializeOwner(
            _primaryOwner,
            _systemAddress,
            _authorityAddress
        );
       
    }
    
  
    function() external payable{
        emit FundDeposited(address(0), msg.sender, msg.value);
    }

    function depositeToken(IERC20Token _token, address _from, uint256 _amount)
        external
        returns (bool)
    {
        ensureTransferFrom(_token, _from, address(this), _amount);
        emit FundDeposited(address(_token), _from, _amount);
        return true;
    }
    
    
    function directTransfer(address _token,address _to,uint256 amount) external onlySpender() returns (bool){
        ensureTransferFrom(IERC20Token(_token),address(this),_to,amount);
        emit FundTransfer(msg.sender,_to,_token,amount);
        return true;
    }
    
    function transferEther(address payable _to,uint256 amount) external onlySpender() returns (bool){
        _to.transfer(amount);
        emit FundTransfer(msg.sender,_to,address(0),amount);
        return true;
    }
    
    
    // This method is auction protection methods called from here 
    // vault address set when contribution is 0
    function unLockTokens() external onlySystem() returns (bool){
        return IAuctionProtection(auctionProtectionAddress).unLockTokens();
    }
    
}
