pragma solidity ^0.5.9;

contract IWhiteList {
    
    function isWhiteListed(address _who) public view returns (bool);

    function checkBeforeTransfer(address _from, address _to)
        public
        view
        returns (bool);

    function isAddressByPassed(address _which) public view returns (bool);
    
    
}