pragma solidity 0.5.9;
import './IERC20Token.sol';

contract IDownSideProtection {
    
    function lockEther(address _which) public payable returns (bool);

    function depositToken(address _from, address _which, uint256 _amount)
        public
        returns (bool);

    function lockTokens(
        IERC20Token _token,
        address _from,
        address _which,
        uint256 _amount
    ) public returns (bool);
    
}