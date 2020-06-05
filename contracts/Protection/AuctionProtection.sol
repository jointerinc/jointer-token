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
    IAuctionRegistery public contractsRegistry;

    address payable public vaultAddress;
    address payable public auctionAddress;
    address payable public tagAlongAddress;
    address payable public mainTokenAddress;
    address payable public companyFundWalletAddress;
    address payable public stackingAddress;

    function updateRegistery(address _address)
        external
        onlyAuthorized()
        notZeroAddress(_address)
        returns (bool)
    {
        contractsRegistry = IAuctionRegistery(_address);
        _updateAddresses();
        return true;
    }

    function getAddressOf(bytes32 _contractName)
        internal
        view
        returns (address payable)
    {
        return contractsRegistry.getAddressOf(_contractName);
    }

    /**@dev updates all the address from the registry contract
    this decision was made to save gas that occurs from calling an external view function */

    function _updateAddresses() internal {
        vaultAddress = getAddressOf(VAULT);
        stackingAddress = getAddressOf(STACKING);
        mainTokenAddress = getAddressOf(MAIN_TOKEN);
        companyFundWalletAddress = getAddressOf(COMPANY_FUND_WALLET);
        tagAlongAddress = getAddressOf(TAG_ALONG);
        auctionAddress = getAddressOf(AUCTION);
    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
    }
}


contract UtilsStorage {
    uint256 public tokenLockDuration;

    address[] public allowedTokens;

    mapping(address => bool) public tokenAllowed;

    mapping(address => bool) public unLockBlock;

    uint256 public vaultRatio;
}


contract Utils is SafeMath, UtilsStorage, AuctionRegistery {
    modifier allowedTokenOnly(address _which) {
        require(tokenAllowed[_which], "ERR_ONLY_ALLOWED_TOKEN");
        _;
    }

    modifier allowedAddressOnly(address _which) {
        require(_which == auctionAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    function allowToken(address _which)
        external
        onlySystem()
        notZeroAddress(_which)
        returns (bool)
    {
        require(!tokenAllowed[_which], "ERR_TOKEN_ALREADY_ALLOWED");
        allowedTokens.push(_which);
        tokenAllowed[_which] = true;
        return true;
    }

    function setVaultRatio(uint256 _vaultRatio)
        external
        onlyAuthorized()
        returns (bool)
    {
        require(_vaultRatio < 100);
        vaultRatio = _vaultRatio;
        return true;
    }

    function setTokenLockDuration(uint256 _tokenLockDuration)
        external
        onlyAuthorized()
        returns (bool)
    {
        tokenLockDuration = _tokenLockDuration;
        return true;
    }

    function isTokenLockEndDay(uint256 _firstLockDay)
        public
        view
        returns (bool)
    {
        uint256 tempDay = safeMul(86400, tokenLockDuration);

        uint256 tokenLockEndDay = safeAdd(tempDay, _firstLockDay);

        if (now >= tokenLockEndDay) {
            return true;
        }

        return false;
    }
}


contract ProtectionStorage {
    // timestamp for address where first lock happen
    mapping(address => uint256) public lockedOn;

    mapping(address => mapping(address => uint256)) public lockedFunds;

    mapping(address => mapping(address => uint256)) public currentLockedFunds;

    mapping(address => uint256) public lockedTokens;
}


contract StackingStorage {
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
    Utils,
    ProtectionStorage,
    StackingStorage,
    TokenTransfer,
    InitializeInterface
{
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
    function stackFund(uint256 _amount)
        external
        allowedAddressOnly(msg.sender)
        returns (bool)
    {
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

    function addFundToStacking(address _whom, uint256 _amount)
        internal
        returns (bool)
    {
        totalTokenAmount = safeAdd(totalTokenAmount, _amount);
        _claimTokens(_whom);
        roundWiseToken[_whom][stackRoundId] = safeAdd(
            roundWiseToken[_whom][stackRoundId],
            _amount
        );
        stackBalance[_whom] = safeAdd(stackBalance[_whom], _amount);
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
    function getStackBalance(address _whom) external view returns (uint256) {
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


contract AuctionProtection is Upgradeable, Stacking {
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress
    ) public {
        super.initialize();

        contractsRegistry = IAuctionRegistery(_registeryAddress);
        tokenLockDuration = 365;
        vaultRatio = 90;
        stackRoundId = 1;
        initializeOwner(_primaryOwner, _systemAddress, _authorityAddress);
        _updateAddresses();
    }

    event TokenUnLocked(address indexed _from, uint256 _tokenAmount);

    event InvestMentCancelled(address indexed _from, uint256 _tokenAmount);

    event FundLocked(address _token, address indexed _which, uint256 _amount);

    event FundTransfer(address indexed _to, address _token, uint256 _amount);

    function lockBalance(
        address _token,
        address _which,
        uint256 _amount
    ) internal returns (bool) {
        if (lockedOn[_which] == 0) lockedOn[_which] = now;
        uint256 currentBalance = currentLockedFunds[_which][_token];
        currentLockedFunds[_which][_token] = safeAdd(currentBalance, _amount);
        emit FundLocked(_token, _which, _amount);
        return true;
    }

    function lockEther(address _which)
        public
        payable
        allowedAddressOnly(msg.sender)
        returns (bool)
    {
        return lockBalance(address(0), _which, msg.value);
    }

    function lockTokens(
        IERC20Token _token,
        address _from,
        address _which,
        uint256 _amount
    )
        public
        allowedAddressOnly(msg.sender)
        allowedTokenOnly(address(_token))
        returns (bool)
    {
        ensureTransferFrom(_token, _from, address(this), _amount);
        return lockBalance(address(_token), _which, _amount);
    }

    function cancelInvestment() external returns (bool) {
        require(
            !isTokenLockEndDay(lockedOn[msg.sender]),
            "ERR_INVESTMENT_CANCEL_PERIOD_OVER"
        );

        uint256 _tokenBalance;
        IERC20Token _token;
        for (uint256 tempX = 0; tempX < allowedTokens.length; tempX++) {
            _token = IERC20Token(allowedTokens[tempX]);
            _tokenBalance = lockedFunds[msg.sender][address(_token)];
            if (_tokenBalance > 0) {
                ensureTransferFrom(
                    _token,
                    address(this),
                    msg.sender,
                    _tokenBalance
                );
                lockedFunds[msg.sender][address(_token)] = 0;
                emit FundTransfer(msg.sender, address(_token), _tokenBalance);
            }
        }

        _tokenBalance = lockedFunds[msg.sender][address(0)];

        if (_tokenBalance > 0) {
            msg.sender.transfer(_tokenBalance);
            emit FundTransfer(msg.sender, address(0), _tokenBalance);
            lockedFunds[msg.sender][address(0)] = 0;
        }

        _tokenBalance = lockedTokens[msg.sender];
        if (_tokenBalance > 0) {
            _token = IERC20Token(mainTokenAddress);

            approveTransferFrom(_token, vaultAddress, _tokenBalance);

            ITokenVault(vaultAddress).depositeToken(
                _token,
                address(this),
                _tokenBalance
            );

            emit FundTransfer(vaultAddress, address(_token), _tokenBalance);
            lockedTokens[msg.sender] = 0;
        }
        emit InvestMentCancelled(msg.sender, _tokenBalance);
        return true;
    }

    function _unLockTokens(address _which, bool isStacking)
        internal
        returns (bool)
    {
        uint256 _tokenBalance;
        IERC20Token _token;
        uint256 walletAmount;
        uint256 tagAlongAmount;

        for (uint256 tempX = 0; tempX < allowedTokens.length; tempX++) {
            _token = IERC20Token(allowedTokens[tempX]);
            _tokenBalance = lockedFunds[_which][address(_token)];
            if (_tokenBalance > 0) {
                walletAmount = safeDiv(safeMul(_tokenBalance, vaultRatio), 100);
                tagAlongAmount = safeSub(_tokenBalance, walletAmount);

                approveTransferFrom(_token, tagAlongAddress, tagAlongAmount);

                IAuctionTagAlong(tagAlongAddress).depositeToken(
                    _token,
                    address(this),
                    tagAlongAmount
                );

                ensureTransferFrom(
                    _token,
                    address(this),
                    companyFundWalletAddress,
                    walletAmount
                );

                emit FundTransfer(
                    tagAlongAddress,
                    address(_token),
                    tagAlongAmount
                );
                emit FundTransfer(
                    companyFundWalletAddress,
                    address(_token),
                    walletAmount
                );
                lockedFunds[_which][address(_token)] = 0;
            }
        }
        _tokenBalance = lockedFunds[_which][address(0)];

        if (_tokenBalance > 0) {
            walletAmount = safeDiv(safeMul(_tokenBalance, vaultRatio), 100);
            tagAlongAmount = safeSub(_tokenBalance, walletAmount);

            tagAlongAddress.transfer(tagAlongAmount);
            companyFundWalletAddress.transfer(walletAmount);
            emit FundTransfer(tagAlongAddress, address(0), tagAlongAmount);
            emit FundTransfer(
                companyFundWalletAddress,
                address(0),
                walletAmount
            );
            lockedFunds[_which][address(0)] = 0;
        }

        _tokenBalance = lockedTokens[_which];

        if (_tokenBalance > 0) {
            _token = IERC20Token(mainTokenAddress);
            if (isStacking) {
                addFundToStacking(_which, _tokenBalance);
            } else {
                ensureTransferFrom(
                    _token,
                    address(this),
                    _which,
                    _tokenBalance
                );
                emit TokenUnLocked(_which, _tokenBalance);
            }
            emit FundTransfer(_which, address(_token), _tokenBalance);
            lockedTokens[_which] = 0;
        }
    }

    // user unlock tokens and funds goes to compnay wallet
    function unLockTokens() external returns (bool) {
        return _unLockTokens(msg.sender, false);
    }

    function stackToken() external returns (bool) {
        return _unLockTokens(msg.sender, true);
    }

    function unLockFundByAdmin(address _which)
        external
        onlyOneOfOnwer()
        returns (bool)
    {
        require(
            isTokenLockEndDay(lockedOn[_which]),
            "ERR_ADMIN_CANT_UNLOCK_FUND"
        );
        return _unLockTokens(_which, false);
    }

    function depositToken(
        address _from,
        address _which,
        uint256 _amount
    ) external allowedAddressOnly(msg.sender) returns (bool) {
        IERC20Token token = IERC20Token(mainTokenAddress);

        ensureTransferFrom(token, _from, address(this), _amount);

        lockedTokens[_which] = safeAdd(lockedTokens[_which], _amount);

        uint256 _currentTokenBalance;
        IERC20Token _token;

        for (uint256 tempX = 0; tempX < allowedTokens.length; tempX++) {
            _token = IERC20Token(allowedTokens[tempX]);

            _currentTokenBalance = currentLockedFunds[_which][address(_token)];

            if (_currentTokenBalance > 0) {
                lockedFunds[msg.sender][address(_token)] = safeAdd(
                    lockedFunds[msg.sender][address(_token)],
                    _currentTokenBalance
                );
                currentLockedFunds[_which][address(_token)] = 0;
            }
        }

        if (currentLockedFunds[_which][address(0)] > 0) {
            _currentTokenBalance = currentLockedFunds[_which][address(0)];

            lockedFunds[_which][address(0)] = safeAdd(
                lockedFunds[_which][address(0)],
                _currentTokenBalance
            );

            currentLockedFunds[_which][address(0)] = 0;
        }

        emit FundLocked(address(token), _which, _amount);
        return true;
    }
}
