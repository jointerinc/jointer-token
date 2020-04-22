pragma solidity ^0.5.9;

import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IAuctionTagAlong.sol";
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
    
    IAuctionRegistery public registry;
    IAuctionRegistery public prevRegistry;

    function updateRegistery(address _address)
        external
        onlyAuthorized()
        notZeroAddress(_address)
        returns (bool)
    {
        prevRegistry = registry;
        registry = IAuctionRegistery(_address);
        return true;
    }

    function getAddressOf(bytes32 _contractName)
        internal
        view
        returns (address)
    {
        return registry.getAddressOf(_contractName);
    }
}


contract UtilsStorage {
    
    mapping(address => bool) public allowedAddress;

    uint256 public tokenLockDuration;

    address[] public allowedTokens;

    mapping(address => bool) public tokenAllowed;


    mapping(address => bool) public unLockBlock;
    
}


contract Utils is SafeMath, UtilsStorage, AuctionRegistery {
    
    modifier allowedTokenOnly(address _which) {
        require(tokenAllowed[_which],"ERR_ONLY_ALLOWED_TOKEN");
        _;
    }

    modifier allowedAddressOnly(address _which) {
        require(allowedAddress[_which],ERR_AUTHORIZED_ADDRESS_ONLY);
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

    function setAllowedAddress(address _address, bool _check)
        external
        onlyOneOfOnwer()
        notZeroAddress(_address)
        returns (bool)
    {
        allowedAddress[_address] = _check;
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


contract AuctionProtection is
    Upgradeable,
    Utils,
    ProtectionStorage,
    InitializeInterface
{
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress
    ) public {
        super.initialize();
        registry = IAuctionRegistery(_registeryAddress);
        tokenLockDuration = 365;
        ProxyOwnable.initializeOwner(
            _primaryOwner,
            _systemAddress,
            _authorityAddress
        );
    }

    event TokenUnLocked(address indexed _from);
    event InvestMentCancelled(address indexed _from);
    event FundLocked(address _token, address _which, uint256 _amount);
    event FundTransfer(address indexed _to, address _token, uint256 _amount);

    function ensureTransferFrom(
        IERC20Token _token,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        uint256 prevBalance = _token.balanceOf(_to);
        if (_from == address(this)) _token.transfer(_to, _amount);
        else _token.transferFrom(_from, _to, _amount);
        uint256 postBalance = _token.balanceOf(_to);
        require(postBalance > prevBalance,"ERR_TRANSFER");
    }

    function approveTransferFrom(
        IERC20Token _token,
        address _spender,
        uint256 _amount
    ) internal {
        _token.approve(_spender, _amount);
    }

    function lockBalance(address _token, address _which, uint256 _amount)
        internal
        returns (bool)
    {
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
            isTokenLockEndDay(lockedOn[msg.sender]),
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
            _token = IERC20Token(getAddressOf(MAIN_TOKEN));
            address tagAlongAdress = getAddressOf(TAG_ALONG);
            approveTransferFrom(_token, tagAlongAdress, _tokenBalance);
            IAuctionTagAlong(tagAlongAdress).depositeToken(
                _token,
                address(this),
                _tokenBalance
            );
            emit FundTransfer(tagAlongAdress, address(_token), _tokenBalance);
            lockedTokens[msg.sender] = 0;
        }
        emit InvestMentCancelled(msg.sender);
        return true;
    }

    // user unlock tokens and funds goes to compnay wallet
    function unLockTokens() external returns (bool) {
        address tagAlongAdress = getAddressOf(TAG_ALONG);
        uint256 _tokenBalance;
        IERC20Token _token;
        for (uint256 tempX = 0; tempX < allowedTokens.length; tempX++) {
            _token = IERC20Token(allowedTokens[tempX]);
            _tokenBalance = lockedFunds[msg.sender][address(_token)];
            if (_tokenBalance > 0) {
                approveTransferFrom(_token, tagAlongAdress, _tokenBalance);
                IAuctionTagAlong(tagAlongAdress).depositeToken(
                    _token,
                    address(this),
                    _tokenBalance
                );
                lockedFunds[msg.sender][address(_token)] = 0;
                emit FundTransfer(
                    tagAlongAdress,
                    address(_token),
                    _tokenBalance
                );
            }
        }

        _tokenBalance = lockedFunds[msg.sender][address(0)];

        if (_tokenBalance > 0) {
            IAuctionTagAlong(tagAlongAdress).depositeEther.value(
                _tokenBalance
            )();
            emit FundTransfer(tagAlongAdress, address(0), _tokenBalance);
            lockedFunds[msg.sender][address(0)] = 0;
        }

        _tokenBalance = lockedTokens[msg.sender];
        if (_tokenBalance > 0) {
            _token = IERC20Token(getAddressOf(MAIN_TOKEN));
            ensureTransferFrom(
                _token,
                address(this),
                msg.sender,
                _tokenBalance
            );
            emit FundTransfer(msg.sender, address(_token), _tokenBalance);
            lockedTokens[msg.sender] = 0;
        }

        emit TokenUnLocked(msg.sender);
        return true;
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

        address tagAlongAdress = getAddressOf(TAG_ALONG);
        uint256 _tokenBalance;
        IERC20Token _token;

        for (uint256 tempX = 0; tempX < allowedTokens.length; tempX++) {
            _token = IERC20Token(allowedTokens[tempX]);
            _tokenBalance = lockedFunds[_which][address(_token)];
            if (_tokenBalance > 0) {
                approveTransferFrom(_token, tagAlongAdress, _tokenBalance);
                IAuctionTagAlong(tagAlongAdress).depositeToken(
                    _token,
                    address(this),
                    _tokenBalance
                );
                lockedFunds[_which][address(_token)] = 0;
                emit FundTransfer(
                    tagAlongAdress,
                    address(_token),
                    _tokenBalance
                );
            }
        }

        _tokenBalance = lockedFunds[_which][address(0)];
        if (_tokenBalance > 0) {
            IAuctionTagAlong(tagAlongAdress).depositeEther.value(
                _tokenBalance
            )();
            emit FundTransfer(tagAlongAdress, address(0), _tokenBalance);
            lockedFunds[_which][address(0)] = 0;
        }

        _tokenBalance = lockedTokens[_which];
        if (_tokenBalance > 0) {
            _token = IERC20Token(getAddressOf(MAIN_TOKEN));
            ensureTransferFrom(_token, address(this), _which, _tokenBalance);
            emit FundTransfer(_which, address(_token), _tokenBalance);
            lockedTokens[_which] = 0;
        }

        emit TokenUnLocked(_which);
        return true;
    }

    function depositToken(address _from, address _which, uint256 _amount)
        external
        allowedAddressOnly(msg.sender)
        returns (bool)
    {
        IERC20Token token = IERC20Token(getAddressOf(MAIN_TOKEN));
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

