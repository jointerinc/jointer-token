pragma solidity ^0.5.9;
import "../InterFaces/IAuctionRegistery.sol";

contract TokenVaultStorage {
    IAuctionRegistery public contractsRegistry;

    address payable public auctionProtectionAddress;

    mapping(address => bool) public isSpender;

    mapping(address => uint256) public spenderIndex;

    address[] public spenders;

    event TokenSpenderAdded(address indexed _which);

    event TokenSpenderRemoved(address indexed _which);

    event FundTransfer(
        address indexed _by,
        address _to,
        address _token,
        uint256 amount
    );

    event FundDeposited(address _token, address _from, uint256 _amount);
}
