pragma solidity ^0.5.9;
import "./IBEP20Token.sol";

interface IAuctionLiquidity {
    function contributeWithEther() external payable returns (uint256);

    function auctionEnded() external returns (bool);

    function contributeTowardMainReserve() external returns (uint256);
}
