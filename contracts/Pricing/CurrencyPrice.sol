pragma solidity ^0.5.9;

import "../common/Ownable.sol";

interface IPrice {
    function getCurrencyPrice() external view returns (uint256);
}

contract CurrencyPrices is Ownable {
    mapping(address => address) public currencyContract;

    constructor(address _systemAddress, address _multisigAddress)
        public
        Ownable(_systemAddress, _multisigAddress)
    {}

    function setCurrencyPriceContract(address _currency, address _priceFeed)
        external
        onlySystem()
        returns (bool)
    {
        require(currencyContract[_currency] == address(0),"ERR_ADDRESS_IS_SET");
        currencyContract[_currency] = _priceFeed;
        return true;
    }

    function updateCurrencyPriceContract(address _currency, address _priceFeed)
        external
        onlyAuthorized()
        returns (bool)
    {
        currencyContract[_currency] = _priceFeed;
        return true;
    }

    function getCurrencyPrice(address _which) public view returns (uint256) {
        return IPrice(currencyContract[_which]).getCurrencyPrice();
    }
}