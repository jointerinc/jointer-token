pragma solidity ^0.5.9;

import "../common/SafeMath.sol";
import "../common/ProxyOwnable.sol";
import "../Proxy/Upgradeable.sol";
import "../common/TokenTransfer.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/IAuctionLiquadity.sol";
import "../InterFaces/IAuction.sol";
import "../InterFaces/ITokenVault.sol";

interface TagAlongInitializeInterface {
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _multisigAdress,
        address _registeryAddress
    ) external;
}

contract RegisteryTagAlong is ProxyOwnable, AuctionRegisteryContracts {
    IAuctionRegistery public contractsRegistry;
    address payable public liquadityAddress;

    event FundDeposited(address _token, address _from, uint256 _amount);

    function initilizeRegistry(
        address _primaryOwner,
        address _systemAddress,
        address _multisigAdress,
        address _registeryAddress
    ) internal {
        initializeOwner(_primaryOwner, _systemAddress, _multisigAdress);
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
        return true;
    }
}

contract AuctionTagAlong is
    Upgradeable,
    RegisteryTagAlong,
    TokenTransfer,
    TagAlongInitializeInterface
{
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _multisigAdress,
        address _registeryAddress
    ) external {
        super.initialize();
        initilizeRegistry(
            _primaryOwner,
            _systemAddress,
            _multisigAdress,
            _registeryAddress
        );
    }

    function contributeTowardLiquadity(uint256 _amount)
        external
        returns (uint256)
    {
        require(msg.sender == liquadityAddress, "ERR_ONLY_LIQUADITY_ALLOWED");

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
        require(msg.sender == liquadityAddress, "ERR_ONLY_LIQUADITY_ALLOWED");
        ensureTransferFrom(_token, address(this), _reciver, _amount);
        return true;
    }

    function depositeToken(
        IERC20Token _token,
        address _from,
        uint256 _amount
    ) external returns (bool) {
        ensureTransferFrom(_token, _from, address(this), _amount);
        emit FundDeposited(address(_token), _from, _amount);
        return true;
    }

    function() external payable {}
}
