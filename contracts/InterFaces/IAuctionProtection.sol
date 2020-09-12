pragma solidity ^0.5.9;

import "./IERC20Token.sol";

interface IAuctionProtection {
    function stackFund(uint256 _amount) external returns (bool);

    function lockEther(address _which) external payable returns (bool);

    function depositToken(
        address _from,
        address _which,
        uint256 _amount
    ) external returns (bool);

    function unLockTokens() external returns (bool);

    function stackToken() external returns (bool);

    function cancelInvestment() external returns (bool);
}