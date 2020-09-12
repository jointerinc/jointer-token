pragma solidity ^0.5.9;

import "../common/SafeMath.sol";
import "../common/ProxyOwnable.sol";
import "../Proxy/Upgradeable.sol";
import "../common/TokenTransfer.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/IAuctionLiquidity.sol";
import "../InterFaces/IAuction.sol";
import "../InterFaces/ITokenVault.sol";

interface ContributionTriggerInitializeInterface {
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _multisigAdress,
        address _registryaddress
    ) external;
}

contract RegisteryContributionTrigger is ProxyOwnable, AuctionRegisteryContracts {
    IAuctionRegistery public contractsRegistry;
    address payable public liquidityAddress;

    event FundDeposited(address _token, address _from, uint256 _amount);

    function initilizeRegistry(
        address _primaryOwner,
        address _systemAddress,
        address _multisigAdress,
        address _registryaddress
    ) internal {
        initializeOwner(_primaryOwner, _systemAddress, _multisigAdress);
        contractsRegistry = IAuctionRegistery(_registryaddress);
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
        liquidityAddress = getAddressOf(LIQUIDITY);
    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
        return true;
    }
}

contract ContributionTrigger is
    Upgradeable,
    RegisteryContributionTrigger,
    TokenTransfer,
    ContributionTriggerInitializeInterface
{
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _multisigAdress,
        address _registryaddress
    ) external {
        super.initialize();
        initilizeRegistry(
            _primaryOwner,
            _systemAddress,
            _multisigAdress,
            _registryaddress
        );
    }

    function contributeTowardLiquidity(uint256 _amount)
        external
        returns (uint256)
    {
        require(msg.sender == liquidityAddress, "ERR_ONLY_Liquidity_ALLOWED");

        if (_amount > address(this).balance) {
            uint256 _newamount = address(this).balance;
            msg.sender.transfer(_newamount);
            return _newamount;
        }
        msg.sender.transfer(_amount);
        return _amount;
    }

    // relay token and bnt token
    function transferTokenLiquidity(
        IERC20Token _token,
        address _reciver,
        uint256 _amount
    ) external returns (bool) {
        require(msg.sender == liquidityAddress, "ERR_ONLY_Liquidity_ALLOWED");
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
