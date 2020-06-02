pragma solidity ^0.5.9;


interface IIndividualBonus {
    function calucalteBonus(uint256 _userIndex, uint256 returnAmount)
        external
        view
        returns (uint256);
}
