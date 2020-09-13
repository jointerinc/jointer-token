pragma solidity ^0.5.9;

import "./IERC20Token.sol";

interface IAuctionProtection {
    function lockEther(uint256 _auctionDay,address _which)
        external
        payable
        returns (bool);
    
    function stackFund(uint256 _amount)
        external
        returns (bool);
        
    function depositToken(
        uint256 _auctionDay,
        address _which,
        uint256 _amount
    ) external returns (bool);
    
    function unLockTokens() external returns (bool);
}