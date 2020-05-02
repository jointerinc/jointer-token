pragma solidity ^0.5.9;
import './IERC20Token.sol';

contract IAuctionLiquadity {
    function getCurrentMarketPrice() public view returns(uint256);
    function contributeWithEther() public payable returns (uint256);
    function contributeWithToken(
        IERC20Token _token,
        address _from,
        uint256 _amount
    ) public returns (uint256);
}
