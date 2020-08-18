pragma solidity ^0.5.9;

interface IToken {
    function mintTokens(uint256 _amount) external returns (bool);

    function buyTokens(address _fromToken, uint256 _amount)
        external
        returns (uint256);

    function burn(uint256 _value) external returns (bool);

    function lockToken(
        address _which,
        uint256 _amount,
        uint256 _locktime
    ) external returns (bool);
}
