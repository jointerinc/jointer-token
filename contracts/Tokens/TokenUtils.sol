pragma solidity ^0.5.9;

import "./StandardToken.sol";
import "../common/SafeMath.sol";
import "../common/Ownable.sol";
import "../InterFaces/IAuctionRegistery.sol";


/**@dev keeps track of registry contract at which all the addresses of the wholes system's contracts are stored */
contract AuctionRegistery is AuctionRegisteryContracts, Ownable {
    IAuctionRegistery public contractsRegistry;

    address public whiteListAddress;
    address public smartSwapAddress;
    address public currencyPricesAddress;
    address public vaultAddress;
    address public auctionAddress;

    /**@dev sets the initial registry address */
    constructor(address _registeryAddress)
        public
        notZeroAddress(_registeryAddress)
    {
        contractsRegistry = IAuctionRegistery(_registeryAddress);
        _updateAddresses();
    }

    /**@dev updates the address of the registry, called only by the system */
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

    /**@dev returns address of the asked contract got from registry contract at the registryAddress
    @param _contractName name of the contract  */
    function getAddressOf(bytes32 _contractName)
        internal
        view
        returns (address)
    {
        return contractsRegistry.getAddressOf(_contractName);
    }

    /**@dev updates all the address from the registry contract
    this decision was made to save gas that occurs from calling an external view function */
    function _updateAddresses() internal {
        whiteListAddress = getAddressOf(WHITE_LIST);
        smartSwapAddress = getAddressOf(SMART_SWAP);
        currencyPricesAddress = getAddressOf(CURRENCY);
        vaultAddress = getAddressOf(VAULT);
        auctionAddress = getAddressOf(AUCTION);
    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
        return true;
    }
}


/**@dev Also is a standard ERC20 token*/
contract TokenUtils is StandardToken, AuctionRegistery {
    /**
     *@dev contructs standard erc20 token and auction registry
     *@param _name name of the token
     *@param _symbol symbol of the token
     *@param _systemAddress address that acts as an admin of the system
     *@param _authorityAddress address that can change the systemAddress
     *@param _registeryAddress address of the registry contract the keeps track of all the contract Addresses
     **/
    constructor(
        string memory _name,
        string memory _symbol,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress
    )
        public
        StandardToken(_name, _symbol, _systemAddress, _authorityAddress)
        AuctionRegistery(_registeryAddress)
    {}
}
