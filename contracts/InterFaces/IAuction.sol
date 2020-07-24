pragma solidity ^0.5.9;

interface IAuction {
    function dayWiseMarketPrice(uint256 dayId) external view returns (uint256);

    function dayWiseContribution(uint256 dayId) external view returns (uint256);

    function auctionDay() external returns (uint256);
}
