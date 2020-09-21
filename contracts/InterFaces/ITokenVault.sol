pragma solidity ^0.5.9;

import "./IBEP20Token.sol";

interface ITokenVault {
    function depositeToken(
        IBEP20Token _token,
        address _from,
        uint256 _amount
    ) external returns (bool);

    function directTransfer(
        address _token,
        address _to,
        uint256 amount
    ) external returns (bool);

    function transferEther(address payable _to, uint256 amount)
        external
        returns (bool);
}
