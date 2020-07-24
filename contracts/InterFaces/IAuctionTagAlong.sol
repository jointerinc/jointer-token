pragma solidity ^0.5.9;

import "./IERC20Token.sol";


interface IAuctionTagAlong {
    function depositeToken(
        IERC20Token _token,
        address _from,
        uint256 _amount
    ) external returns (bool);

    function contributeTowardLiquadity(uint256 _amount)
        external
        returns (uint256);

    function transferTokenLiquadity(
        IERC20Token _token,
        address _reciver,
        uint256 _amount
    ) external returns (bool);
}
