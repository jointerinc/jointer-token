pragma solidity ^0.5.9;

interface IEscrow {
    function depositFee(uint256 value) external returns (bool);
}
