pragma solidity ^0.5.9;

import "./SafeMath.sol";

contract MultiSigConstant {
    string constant ERR_SAME_ADDRESS = "ERR_SAME_ADDRESS";

    string constant ERR_CONTRACT_SELF_ADDRESS = "ERR_CONTRACT_SELF_ADDRESS";

    string constant ERR_ZERO_ADDRESS = "ERR_ZERO_ADDRESS";

    string constant ERR_ZERO_VALUE = "ERR_ZERO_VALUE";

    string constant ERR_AUTHORIZED_ADDRESS_ONLY = "ERR_AUTHORIZED_ADDRESS_ONLY";

    string constant ERR_OWNER_MAXIMUM_LIMIT = "ERR_OWNER_MAXIMUM_LIMIT";

    string constant ERR_OWNER_MINIMUM_LIMIT = "ERR_OWNER_MINIMUM_LIMIT";

    string constant ERR_CONFIRMATION_LIMIT = "ERR_CONFIRMATION_LIMIT";

    string constant ERR_TRAN_NOT_AVILABLE = "ERR_TRAN_NOT_AVILABLE";

    string constant ERR_TRAN_ALREADY_EXUCATED = "ERR_TRAN_ALREADY_EXUCATED";

    string constant ERR_TRAN_ALREADY_SIGNED = "ERR_TRAN_ALREADY_SIGNED";

    string constant ERR_TRAN_NOT_SIGNED = "ERR_TRAN_NOT_SIGNED";

    // validates an address is not zero
    modifier notZeroAddress(address _which) {
        require(_which != address(0), ERR_ZERO_ADDRESS);
        _;
    }
}

contract MultiSigOwnable is MultiSigConstant, SafeMath {
    uint256 public constant MAX_OWNERS_ALLOWED = 30;

    mapping(address => bool) public isOwner;

    mapping(address => uint256) public ownerIndex;

    address[] public multiSigOwners;

    uint256 public minConfirmationsRequired;

    modifier onlyAuthorized() {
        require(msg.sender == address(this), ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    modifier notOwner(address _which) {
        require(!isOwner[_which], ERR_SAME_ADDRESS);
        _;
    }

    modifier shoudBeOwner(address _which) {
        require(isOwner[_which], ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);

    function addNewOwner(address _owner)
        external
        onlyAuthorized()
        notZeroAddress(_owner)
        notOwner(_owner)
        returns (bool)
    {
        require(
            safeAdd(multiSigOwners.length, 1) <= MAX_OWNERS_ALLOWED,
            ERR_OWNER_MAXIMUM_LIMIT
        );

        ownerIndex[_owner] = multiSigOwners.length;
        isOwner[_owner] = true;
        multiSigOwners.push(_owner);
        emit OwnerAdded(_owner);
        return true;
    }

    function removeOwner(address _owner)
        external
        onlyAuthorized()
        notZeroAddress(_owner)
        shoudBeOwner(_owner)
        returns (bool)
    {
        require(
            safeSub(multiSigOwners.length, 1) >= 1,
            ERR_OWNER_MINIMUM_LIMIT
        );

        isOwner[_owner] = false;

        uint256 _ownerIndex = ownerIndex[_owner];

        address _lastAdress = multiSigOwners[safeSub(multiSigOwners.length, 1)];

        multiSigOwners[_ownerIndex] = _lastAdress;

        ownerIndex[_lastAdress] = _ownerIndex;

        multiSigOwners.pop();

        if (minConfirmationsRequired > multiSigOwners.length)
            minConfirmationsRequired = multiSigOwners.length;

        emit OwnerRemoved(_owner);
        return true;
    }

    function changeMinConfirmationsRequired(uint256 _minConfirmationsRequired)
        external
        onlyAuthorized()
        returns (bool)
    {
        require(
            multiSigOwners.length >= _minConfirmationsRequired,
            ERR_CONFIRMATION_LIMIT
        );
        minConfirmationsRequired = _minConfirmationsRequired;
        return true;
    }
}

contract MultiSigGovernance is MultiSigOwnable {
    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationsRequired;
    }

    mapping(uint256 => Transaction) public transactions;

    mapping(uint256 => uint256) public confirmationsCount;

    mapping(uint256 => mapping(address => bool)) public confirmations;

    uint256 public transactionCount;

    event NewTransactionAdded(uint256 indexed transactionId, address owner);
    event TransactionConfirmed(uint256 indexed transactionId, address owner);
    event TransactionConfirmationRevoked(
        uint256 indexed transactionId,
        address owner
    );
    event TransactionExecuted(uint256 indexed transactionId, bool isSuccess);

    modifier notExecuted(uint256 transactionId) {
        require(
            transactions[transactionId].destination != address(0),
            ERR_TRAN_NOT_AVILABLE
        );
        require(
            transactions[transactionId].executed == false,
            ERR_TRAN_ALREADY_EXUCATED
        );
        _;
    }

    constructor(
        address[] memory _multiSigOwners,
        uint256 _minConfirmationsRequired
    ) public {
        require(
            _multiSigOwners.length >= _minConfirmationsRequired,
            ERR_CONFIRMATION_LIMIT
        );

        for (uint256 i = 0; i < _multiSigOwners.length; i++) {
            require(
                isOwner[_multiSigOwners[i]] == false &&
                    _multiSigOwners[i] != address(0),
                ERR_SAME_ADDRESS
            );
            isOwner[_multiSigOwners[i]] = true;
            ownerIndex[_multiSigOwners[i]] = i;
        }
        multiSigOwners = _multiSigOwners;
        minConfirmationsRequired = _minConfirmationsRequired;
    }

    function external_call(
        address destination,
        uint256 value,
        uint256 dataLength,
        bytes memory data
    ) private returns (bool) {
        bool result;
        assembly {
            let x := mload(0x40)
            let d := add(data, 32)
            result := call(gas(), destination, value, d, dataLength, x, 0)
        }
        return result;
    }

    function addTransaction(
        address destination,
        uint256 value,
        bytes calldata data,
        uint256 _confirmationsRequired
    )
        external
        shoudBeOwner(msg.sender)
        notZeroAddress(destination)
        returns (uint256 transactionId)
    {
        require(
            _confirmationsRequired >= minConfirmationsRequired,
            ERR_CONFIRMATION_LIMIT
        );

        require(
            multiSigOwners.length >= _confirmationsRequired,
            ERR_OWNER_MAXIMUM_LIMIT
        );

        transactionId = transactionCount;

        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false,
            confirmationsRequired: _confirmationsRequired
        });
        emit NewTransactionAdded(transactionCount, msg.sender);
        transactionCount = safeAdd(transactionCount, 1);
        confirmTransaction(transactionId);
        return transactionId;
    }

    function confirmTransaction(uint256 transactionId)
        public
        shoudBeOwner(msg.sender)
        notExecuted(transactionId)
        returns (bool)
    {
        require(
            !confirmations[transactionId][msg.sender],
            ERR_TRAN_ALREADY_SIGNED
        );
        confirmations[transactionId][msg.sender] = true;

        confirmationsCount[transactionId] = safeAdd(
            confirmationsCount[transactionId],
            1
        );

        emit TransactionConfirmed(transactionId, msg.sender);
        executeTransaction(transactionId);
        return true;
    }

    function revokeConfirmation(uint256 transactionId)
        public
        shoudBeOwner(msg.sender)
        notExecuted(transactionId)
        returns (bool)
    {
        require(confirmations[transactionId][msg.sender], ERR_TRAN_NOT_SIGNED);
        confirmations[transactionId][msg.sender] = false;
        confirmationsCount[transactionId] = safeSub(
            confirmationsCount[transactionId],
            1
        );
        emit TransactionConfirmationRevoked(transactionId, msg.sender);
        return true;
    }

    function executeTransaction(uint256 transactionId)
        public
        shoudBeOwner(msg.sender)
        notExecuted(transactionId)
        returns (bool)
    {
        if (
            confirmationsCount[transactionId] >=
            transactions[transactionId].confirmationsRequired
        ) {
            Transaction storage txn = transactions[transactionId];
            bool result = external_call(
                txn.destination,
                txn.value,
                txn.data.length,
                txn.data
            );
            txn.executed = result;
            emit TransactionExecuted(transactionId, result);
        }
        return true;
    }

    function withDrawEth(uint256 balance, address payable _address)
        external
        onlyAuthorized()
        notZeroAddress(_address)
        returns (bool)
    {
        require(address(this).balance >= balance, ERR_TRAN_NOT_AVILABLE);
        _address.transfer(balance);
    }

    function() external payable {}
}
