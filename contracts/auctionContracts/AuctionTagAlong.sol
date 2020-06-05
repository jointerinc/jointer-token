pragma solidity ^0.5.9;

import "../common/SafeMath.sol";
import "../common/Ownable.sol";
import "../common/TokenTransfer.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IAuctionProtection.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/IAuctionLiquadity.sol";
import "../InterFaces/IAuction.sol";
import "../InterFaces/ITokenVault.sol";


contract AuctionRegistery is Ownable, AuctionRegisteryContracts {
    IAuctionRegistery public contractsRegistry;

    address payable public liquadityAddress;

    constructor(
        address _systemAddress,
        address _multisigAdress,
        address _registeryAddress
    ) public Ownable(_systemAddress, _multisigAdress) {
        contractsRegistry = IAuctionRegistery(_registeryAddress);
        _updateAddresses();
    }

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
        liquadityAddress = getAddressOf(LIQUADITY);
    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
    }
}


contract Utils is AuctionRegistery, SafeMath {
    uint256 public liquadityRatio = 100;

    uint256 public contributionRatio = 100;

    constructor(
        address _systemAddress,
        address _multisigAdress,
        address _registeryAddress
    )
        public
        AuctionRegistery(_systemAddress, _multisigAdress, _registeryAddress)
    {}

    function setLiquadityRatio(uint256 _ratio)
        external
        onlySystem()
        returns (bool)
    {
        liquadityRatio = _ratio;
        return true;
    }

    function setcContributionRatio(uint256 _ratio)
        external
        onlySystem()
        returns (bool)
    {
        contributionRatio = _ratio;
        return true;
    }
}


contract AuctionTagAlong is Utils, TokenTransfer {
    constructor(
        address _systemAddress,
        address _multisigAdress,
        address _registeryAddress
    ) public Utils(_systemAddress, _multisigAdress, _registeryAddress) {}

    event FundDeposited(address _token, address _from, uint256 _amount);

    function contributeTowardLiquadity(uint256 _amount)
        external
        returns (uint256)
    {
        require(msg.sender == liquadityAddress, "ERR_ONLY_LIQUADITY_ALLWOED");

        if (_amount > address(this).balance) {
            uint256 _newamount = address(this).balance;
            msg.sender.transfer(_newamount);
            return _newamount;
        }
        msg.sender.transfer(_amount);
        return _amount;
    }

    // relay token and bnt token
    function transferTokenLiquadity(
        IERC20Token _token,
        address _reciver,
        uint256 _amount
    ) external returns (bool) {
        require(msg.sender == liquadityAddress, "ERR_ONLY_LIQUADITY_ALLWOED");
        ensureTransferFrom(_token, address(this), _reciver, _amount);
        return true;
    }

    //return token and ether from here
    function returnFund(
        IERC20Token _token,
        uint256 _value,
        address payable _which
    ) external onlyOwner() returns (bool) {
        if (address(_token) == address(0)) {
            _which.transfer(_value);
        } else {
            ensureTransferFrom(_token, address(this), _which, _value);
        }
        return true;
    }

    function depositeToken(
        IERC20Token _token,
        address _from,
        uint256 _amount
    ) external returns (bool) {
        ensureTransferFrom(_token, _from, address(this), _amount);
        emit FundDeposited(address(0), _from, _amount);
        return true;
    }

    function() external payable {
        emit FundDeposited(address(0), msg.sender, msg.value);
    }
}
