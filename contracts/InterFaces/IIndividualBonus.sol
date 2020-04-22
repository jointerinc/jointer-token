pragma solidity 0.5.9;

contract IIndividualBonus {
    function calucalteBonus(
        uint256 _tolalInvestMent,
        uint256 _userInvestMent,
        uint256 returnAmount
    ) public view returns (uint256);
}
