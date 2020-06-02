pragma solidity ^0.5.9;


interface ICurrencyPrices {
    function getCurrencyPrice(address _which) external view returns (uint256);
}
