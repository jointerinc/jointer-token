pragma solidity ^0.5.9;

import "./StandardToken.sol";
import "../common/SafeMath.sol";
import "../common/Ownable.sol";
import "../InterFaces/IAuctionRegistery.sol";


contract AuctionRegistery is AuctionRegisteryContracts, Ownable {
    IAuctionRegistery public contractsRegistry;

    constructor(address _registeryAddress)
        public
        notZeroAddress(_registeryAddress)
    {
        contractsRegistry = IAuctionRegistery(_registeryAddress);
    }

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


contract TokenUtils is StandardToken, AuctionRegistery {
    address public whiteListAddress;
    address public smartSwapAddress;
    address public currencyPricesAddress;
    address public vaultAddress;
    address public auctionAddress;

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

    function updateAdresses() external {
        whiteListAddress = getAddressOf(WHITE_LIST);
        smartSwapAddress = getAddressOf(SMART_SWAP);
        currencyPricesAddress = getAddressOf(CURRENCY);
        vaultAddress = getAddressOf(VAULT);
        auctionAddress = getAddressOf(AUCTION);
    }
}
