pragma solidity ^0.5.9;


contract OwnableTemp {
    address public owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor(address _systemAddress) public {
        owner = _systemAddress;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}


contract TestCurrencyPrices is OwnableTemp {
    mapping(address => uint256) public currencyPrices;

    constructor(address _systemAddress, address _multisigAddress)
        public
        OwnableTemp(_systemAddress)
    {}

    //Owner can Set Currency price
    //@ param _price Current price of currency.
    // currency Price set in 6 decimal
    function setCurrencyPriceUSD(
        address[] memory currency,
        uint256[] memory price
    ) public onlyOwner {
        for (uint8 i = 0; i < currency.length; i++) {
            require(price[i] != 0);
            currencyPrices[currency[i]] = price[i];
        }
    }

    function getCurrencyPrice(address _which) public view returns (uint256) {
        return currencyPrices[_which];
    }
}
