pragma solidity ^0.5.9;

import "./IBEP20Token.sol";

interface IContributionTrigger {
    function depositeToken(
        IBEP20Token _token,
        address _from,
        uint256 _amount
    ) external returns (bool);

    function contributeTowardLiquidity(uint256 _amount)
        external
        returns (uint256);

    function transferTokenLiquidity(
        IBEP20Token _token,
        address _reciver,
        uint256 _amount
    ) external returns (bool);
}
