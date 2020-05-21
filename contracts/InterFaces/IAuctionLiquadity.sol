pragma solidity ^0.5.9;
import "./IERC20Token.sol";


contract IAuctionLiquadity {
    function contributeWithEther() public payable returns (uint256);

    function auctionEnded(uint256 auctionDayId) public returns (bool);

    function contributeTowardMainReserve(uint256 _amount)
        public
        returns (uint256);

    function contributeWithToken(
        IERC20Token _token,
        address _from,
        uint256 _amount
    ) public returns (uint256);
}
