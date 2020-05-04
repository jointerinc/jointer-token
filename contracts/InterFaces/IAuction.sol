pragma solidity ^0.5.9;

contract IAuction {
    
    function tokenAuctionEndPrice() public returns (uint256);
    
    function dayWiseMarketPrice(uint256 dayId) public view returns(uint256);
    
    function dayWiseContribution(uint256 dayId) public view returns(uint256);
    
    
    function auctionDay() public returns(uint256);
    
}
