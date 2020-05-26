pragma solidity ^0.5.9;

import "./IERC20Token.sol";


contract IAuctionTagAlong {
    function depositeEther() external payable;

    function depositeToken(
        IERC20Token _token,
        address _from,
        uint256 _amount
    ) public;

    function contributeTowardLiquadity(uint256 _amount)
        public
        returns (uint256);

    function transferTokenLiquadity(
        IERC20Token _token,
        address _reciver,
        uint256 _amount
    ) external returns (bool);
}
