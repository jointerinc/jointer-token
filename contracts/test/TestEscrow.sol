pragma solidity ^0.5.9;

//the auctionTests.js itself

import "../common/TokenTransfer.sol";
import "../InterFaces/IERC20Token.sol";

contract TestEscrow is TokenTransfer{

    IERC20Token mainToken ;
    constructor(IERC20Token _mainToken) public {
        mainToken = _mainToken;
    }

    function depositFee(uint256 value) external returns(bool){
        ensureTransferFrom(mainToken,msg.sender,address(this),value);
        return true;
    }


}