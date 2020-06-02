pragma solidity ^0.5.9;

import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../common/TokenTransfer.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IAuctionTagAlong.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IERC20Token.sol";


interface InitializeInterface {
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress
    ) external;
}


contract AuctionRegistery is ProxyOwnable, AuctionRegisteryContracts {
    address payable public vaultAddress;
    address payable public mainTokenAddress;
    address payable public auctionAddress;
    address payable public auctionProtectionAddress;

    IAuctionRegistery public contractsRegistry;

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
        returns (address payable)
    {
        return contractsRegistry.getAddressOf(_contractName);
    }

    function updateAddresses() public {
        vaultAddress = getAddressOf(VAULT);
        mainTokenAddress = getAddressOf(MAIN_TOKEN);
        auctionProtectionAddress = getAddressOf(AUCTION_PROTECTION);
        auctionAddress = getAddressOf(AUCTION);
    }
}


contract StackingStorage is SafeMath {
    // We track Token only transfer by auction or downside
    // Reason for tracking this bcz someone can send token direclty

    uint256 public constant PERCENT_NOMINATOR = 10**6;

    uint256 public constant DECIMAL_NOMINATOR = 10**18;

    uint256 public totalTokenAmount;

    uint256 public stackRoundId;

    mapping(uint256 => uint256) dayWiseRatio;

    mapping(address => uint256) lastRound;

    mapping(address => mapping(uint256 => uint256)) roundWiseToken;

    mapping(address => uint256) stackBalance;
}


contract Stacking is
    AuctionRegistery,
    Upgradeable,
    StackingStorage,
    TokenTransfer,
    InitializeInterface
{
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress
    ) public {
        super.initialize();

        contractsRegistry = IAuctionRegistery(_registeryAddress);

        stackRoundId = 1;

        initializeOwner(_primaryOwner, _systemAddress, _authorityAddress);
    }

    event StackAdded(
        uint256 indexed _roundId,
        address indexed _whom,
        uint256 _amount
    );

    event StackRemoved(
        uint256 indexed _roundId,
        address indexed _whom,
        uint256 _amount
    );

    // stack fund called from auction contacrt
    // 1% of supply distributed among the stack token
    function stackFund(uint256 _amount) external returns (bool) {
        require(msg.sender == auctionAddress, ERR_AUTHORIZED_ADDRESS_ONLY);

        IERC20Token mainToken = IERC20Token(mainTokenAddress);

        if (totalTokenAmount > 0) {
            ensureTransferFrom(mainToken, msg.sender, address(this), _amount);

            uint256 ratio = safeDiv(
                safeMul(_amount, DECIMAL_NOMINATOR),
                totalTokenAmount
            );

            totalTokenAmount = safeAdd(totalTokenAmount, _amount);

            dayWiseRatio[stackRoundId] = ratio;
        } else ensureTransferFrom(mainToken, msg.sender, vaultAddress, _amount);

        stackRoundId = safeAdd(stackRoundId, 1);

        return true;
    }

    // system track each and every stacker
    // updating lastRound if it zero
    // this called when user wants to choose stack token
    function addFundToStacking(address _whom, uint256 _amount)
        external
        returns (bool)
    {
        require(
            msg.sender == auctionProtectionAddress,
            ERR_AUTHORIZED_ADDRESS_ONLY
        );

        ensureTransferFrom(
            IERC20Token(mainTokenAddress),
            msg.sender,
            address(this),
            _amount
        );

        totalTokenAmount = safeAdd(totalTokenAmount, _amount);

        // 0x -> 3 -> 2
        roundWiseToken[_whom][stackRoundId] = safeAdd(
            roundWiseToken[_whom][stackRoundId],
            _amount
        );

        //0x -> 0 -> 4
        stackBalance[_whom] = safeAdd(stackBalance[_whom], _amount);

        // 0 -> 2
        if (lastRound[_whom] == 0) {
            lastRound[_whom] = stackRoundId;
        }

        emit StackAdded(stackRoundId, _whom, _amount);
    }

    // calulcate actul fund user have
    function calulcateStackFund(address _whom) internal view returns (uint256) {
        uint256 _lastRound = lastRound[_whom];

        uint256 _token;

        uint256 _stackToken = 0;

        if (_lastRound > 0) {
            for (uint256 x = _lastRound; x < stackRoundId; x++) {
                _token = safeAdd(_token, roundWiseToken[_whom][x]);

                uint256 _tempStack = safeDiv(
                    safeMul(dayWiseRatio[x], _token),
                    DECIMAL_NOMINATOR
                );

                _stackToken = safeAdd(_stackToken, _tempStack);

                _token = safeAdd(_token, _tempStack);
            }
        }
        return _stackToken;
    }

    // this method distribut token
    function _claimTokens(address _which) internal returns (bool) {
        uint256 _stackToken = calulcateStackFund(_which);

        lastRound[_which] = stackRoundId;

        stackBalance[_which] = safeAdd(stackBalance[_which], _stackToken);

        return true;
    }

    // every 5th Round system call this so token distributed
    // user also can call this
    function distributionStackInBatch(address[] calldata _which)
        external
        returns (bool)
    {
        for (uint8 x = 0; x < _which.length; x++) {
            _claimTokens(_which[x]);
        }
    }

    // show stack balace with what user get
    function getBalance(address _whom) external view returns (uint256) {
        uint256 _stackToken = calulcateStackFund(_whom);
        return safeAdd(stackBalance[_whom], _stackToken);
    }

    // unlocking stack token
    function unlockTokenFromStack() external returns (bool) {
        uint256 _stackToken = calulcateStackFund(msg.sender);

        uint256 actulToken = safeAdd(stackBalance[msg.sender], _stackToken);

        ensureTransferFrom(
            IERC20Token(mainTokenAddress),
            address(this),
            msg.sender,
            actulToken
        );

        totalTokenAmount = safeSub(totalTokenAmount, actulToken);

        stackBalance[msg.sender] = 0;

        lastRound[msg.sender] = 0;

        emit StackRemoved(stackRoundId, msg.sender, actulToken);
    }
}
