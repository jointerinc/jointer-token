pragma solidity ^0.5.9;


contract AuctionRegisteryContracts {
    bytes32 internal constant MAIN_TOKEN = "MAIN_TOKEN";

    bytes32 internal constant ETN_TOKEN = "ETN_TOKEN";

    bytes32 internal constant STOCK_TOKEN = "STOCK_TOKEN";

    bytes32 internal constant AUCTION_FORMULA = "AUCTION_FORMULA";

    bytes32 internal constant AUCTION_PROTECTION = "AUCTION_PROTECTION";

    bytes32 internal constant WHITE_LIST = "WHITE_LIST";

    bytes32 internal constant AUCTION = "AUCTION";

    bytes32 internal constant LIQUADITY = "LIQUADITY";

    bytes32 internal constant CURRENCY = "CURRENCY";

    bytes32 internal constant INDIDUAL_BONUS = "INDIDUAL_BONUS";

    bytes32 internal constant VAULT = "VAULT";

    bytes32 internal constant TAG_ALONG = "TAG_ALONG";

    bytes32 internal constant COMPANY_FUND_WALLET = "COMPANY_FUND_WALLET";

    bytes32 internal constant COMPANY_MAIN_TOKEN_WALLET = "COMPANY_MAIN_TOKEN_WALLET";
}


contract IAuctionRegistery {
    function getAddressOf(bytes32 _contractName)
        external
        view
        returns (address payable);
}
