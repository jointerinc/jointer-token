pragma solidity ^0.5.9;

contract IIndividualBonus {
    function calucalteBonus(
        uint256 _userIndex,
        uint256 returnAmount
    ) public view returns (uint256);
}
