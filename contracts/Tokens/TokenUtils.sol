pragma solidity ^0.5.9;

import "./StandardToken.sol";
import "../common/SafeMath.sol";
import "../common/Ownable.sol";
import "../InterFaces/IAuctionRegistery.sol";


contract AuctionRegistery is AuctionRegisteryContracts, Ownable {
    IAuctionRegistery public contractsRegistry;

    constructor(address _registeryAddress)
        public
        notZeroAddress(_registeryAddress)
    {
        contractsRegistry = IAuctionRegistery(_registeryAddress);
    }

    function updateRegistery(address _address)
        external
        onlyAuthorized()
        notZeroAddress(_address)
        returns (bool)
    {
        contractsRegistry = IAuctionRegistery(_address);
        return true;
    }

    function getAddressOf(bytes32 _contractName)
        internal
        view
        returns (address)
    {
        return contractsRegistry.getAddressOf(_contractName);
    }
}


contract TokenUtils is StandardToken {
    uint256 public tokenPrice;

    uint256 public tokenSaleStartDate;

    uint256 public tokenMaturityDays;

    uint256 public tokenHoldBackDays;

    constructor(
        uint256 _tokenPrice,
        uint256 _tokenMaturityDays,
        uint256 _tokenHoldBackDays
    ) public notZeroValue(_tokenPrice) {
        tokenSaleStartDate = now;
        tokenPrice = _tokenPrice;
        tokenMaturityDays = _tokenMaturityDays;
        tokenHoldBackDays = _tokenHoldBackDays;
    }

    function isTokenMature() public view returns (bool) {
        if (tokenMaturityDays == 0) return false;
        uint256 tempDay = safeMul(86400, tokenMaturityDays);
        uint256 tempMature = safeAdd(tempDay, tokenSaleStartDate);
        if (now >= tempMature) {
            return true;
        }
        return false;
    }

    function isHoldbackDaysOver() public view returns (bool) {
        uint256 tempDay = safeMul(86400, tokenHoldBackDays);

        uint256 holdBackDaysEndDay = safeAdd(tempDay, tokenSaleStartDate);

        if (now >= holdBackDaysEndDay) {
            return true;
        }

        return false;
    }
}
