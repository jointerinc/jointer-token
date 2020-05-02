pragma solidity ^0.5.9;

contract IAuction {
    
    function tokenAuctionEndPrice() public returns (uint256);
    function dayWiseMarketPrice(uint256 dayId) public returns(uint256);
    
}
