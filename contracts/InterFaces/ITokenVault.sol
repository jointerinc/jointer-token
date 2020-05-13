pragma solidity ^0.5.9;

import "./IERC20Token.sol";


contract ITokenVault {
    function depositeToken(IERC20Token _token, address _from, uint256 _amount)
        public;

    function directTransfer(address _token, address _to, uint256 amount)
        public
        returns (bool);

    function depositeEther() external payable returns (bool);
}
