pragma solidity ^0.5.9;
import './IERC20Token.sol';

contract IAuctionTagAlong {
    function depositeEther() external payable;
    function depositeToken(IERC20Token _token,address _from,uint256 _amount) external;
}