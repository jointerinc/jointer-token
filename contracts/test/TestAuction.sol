pragma solidity ^0.5.9;

//This contract is made to just test the redemption functionality in liquity and protection
//All the other functionlity that requires auction in Liquidity contract is done with the original auction in
//the auctionTests.js itself

import "../InterFaces/IAuctionProtection.sol";
import "../InterFaces/IERC20Token.sol";

contract TestAuction {
    uint256 public auctionDay = 1;

    address protectionAddress;

    constructor(address _protectionAddress) public {
        protectionAddress = _protectionAddress;
    }

    function changeAuctionDay(uint256 _auctionDay) public {
        auctionDay = _auctionDay;
    }

    function depositToken(
        address _from,
        address _which,
        uint256 _amount
    ) external returns (bool) {
        return
            IAuctionProtection(protectionAddress).depositToken(
                _from,
                _which,
                _amount
            );
    }

    function lockEther(address _which) external payable returns (bool) {
        return
            IAuctionProtection(protectionAddress).lockEther.value(msg.value)(
                _which
            );
    }

    function lockTokens(
        IERC20Token _token,
        address _from,
        address _which,
        uint256 _amount
    ) external returns (bool) {
        return
            IAuctionProtection(protectionAddress).lockTokens(
                _token,
                _from,
                _which,
                _amount
            );
    }

    function stackFund(uint256 _amount) external returns (bool) {
        return IAuctionProtection(protectionAddress).stackFund(_amount);
    }

    //ERC20 stuff
    function approve(
        IERC20Token _token,
        address _spender,
        uint256 _value
    ) external returns (bool) {
        return _token.approve(_spender, _value);
    }

    function() external payable {}
}
