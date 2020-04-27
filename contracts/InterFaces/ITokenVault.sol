pragma solidity ^0.5.9;


contract ITokenVault {
    function directTransfer(address _token, address _to, uint256 amount)
        public
        returns (bool);

    function depositeEther() external payable returns (bool);
}
