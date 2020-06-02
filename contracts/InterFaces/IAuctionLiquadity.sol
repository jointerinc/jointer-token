pragma solidity ^0.5.9;
import "./IERC20Token.sol";


interface IAuctionLiquadity {
    function contributeWithEther() external payable returns (uint256);

    function auctionEnded() external returns (bool);

    function contributeTowardMainReserve() external returns (uint256);

    function contributeWithToken(
        IERC20Token _token,
        address _from,
        uint256 _amount
    ) external returns (uint256);
}
