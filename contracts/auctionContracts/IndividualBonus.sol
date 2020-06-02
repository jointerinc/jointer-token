pragma solidity ^0.5.9;

import "../common/Ownable.sol";
import "../common/SafeMath.sol";


contract IndividualBonus is Ownable, SafeMath {
    uint256 public X_0 = 100;

    uint256 public X_1 = 150;

    uint256 public X_2 = 140;

    uint256 public X_3 = 130;

    uint256 public X_4 = 120;

    uint256 public X_5 = 110;

    mapping(uint256 => uint256) public indexReturn;

    constructor(address _systemAddress, address _multisigAdress)
        public
        Ownable(_systemAddress, _multisigAdress)
    {
        for (uint256 tempX = 0; tempX <= 5; tempX++) {
            if (tempX == 0) indexReturn[tempX] = X_0;
            else if (tempX == 1) indexReturn[tempX] = X_1;
            else if (tempX == 2) indexReturn[tempX] = X_2;
            else if (tempX == 3) indexReturn[tempX] = X_3;
            else if (tempX == 4) indexReturn[tempX] = X_4;
            else if (tempX == 5) indexReturn[tempX] = X_5;
        }
    }

    function updatePercentReturn(
        uint256 _from,
        uint256 _to,
        uint256 _percent
    ) public onlySystem() returns (bool) {
        for (uint256 tempX = _from; tempX < _to; tempX++)
            indexReturn[tempX] = _percent;
        return true;
    }

    function calucalteBonus(uint256 _userIndex, uint256 _returnAmount)
        public
        view
        returns (uint256)
    {
        uint256 returnAmount = safeDiv(
            safeMul(_returnAmount, indexReturn[_userIndex]),
            100
        );
        return returnAmount;
    }
}
