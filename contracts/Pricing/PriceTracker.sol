pragma solidity ^0.5.9;
pragma experimental ABIEncoderV2;


interface IStdReference {
    /// A structure returned whenever someone requests for standard reference data.
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }

    /// Returns the price data for the given base/quote pair. Revert if not available.
    function getReferenceData(string calldata _base, string calldata _quote)
        external
        view
        returns (ReferenceData memory);

}

contract CurrencyPriceTicker {
    
    IStdReference public ref;

    string public baseCurrency;
    
    string public vsCurrency;
    
    uint256 public constant PRICE_NOMINATOR = 10**9;
    
    constructor(IStdReference _ref,string memory _baseCurrency,string memory _vsCurrency) public {
        baseCurrency = _baseCurrency;
        vsCurrency = _vsCurrency;
        ref = _ref;
    }

    
    function getCurrencyPrice() external view returns (uint256){
        IStdReference.ReferenceData memory data = ref.getReferenceData(baseCurrency,vsCurrency);
        return data.rate/PRICE_NOMINATOR;
    }
    

}