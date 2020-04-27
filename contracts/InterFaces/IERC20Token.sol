pragma solidity ^0.5.9;

contract IERC20Token {
    function name() public view returns (string memory);

    function symbol() public view returns (string memory);

    function decimals() public view returns (uint8);

    function totalSupply() public view returns (uint256);

    function balanceOf(address _owner) public view returns (uint256);

    function allowance(address _owner, address _spender)
        public
        view
        returns (uint256);

    function transfer(address _to, uint256 _value) public returns (bool);

    function transferFrom(address _from, address _to, uint256 _value)
        public
        returns (bool);

    function approve(address _spender, uint256 _value) public returns (bool);
}