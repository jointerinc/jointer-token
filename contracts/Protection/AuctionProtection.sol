pragma solidity ^0.5.9;

import "./ProtectionStorage.sol";
import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../common/TokenTransfer.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IContributionTrigger.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/IAuction.sol";
import "../InterFaces/IWhiteList.sol";

interface InitializeInterface {
    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress
    ) external;
}

contract AuctionRegistery is ProxyOwnable,ProtectionStorage, AuctionRegisteryContracts {
    

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
        mainTokenAddress = getAddressOf(MAIN_TOKEN);
        companyFundWalletAddress = getAddressOf(COMPANY_FUND_WALLET);
        triggerAddress = getAddressOf(CONTRIBUTION_TRIGGER);
        auctionAddress = getAddressOf(AUCTION);
        whiteListAddress = getAddressOf(WHITE_LIST);
    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
        return true;
    }
}


contract Utils is SafeMath, AuctionRegistery {
    

    modifier allowedAddressOnly(address _which) {
        require(_which == auctionAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
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

    function isTokenLockEndDay(uint256 _LockDay) internal returns (bool) {
        uint256 auctionDay = IAuction(auctionAddress).auctionDay();
        if (auctionDay > safeAdd(_LockDay, tokenLockDuration)) {
            return true;
        }

        return false;
    }
}




contract Stacking is
    Utils,
    TokenTransfer,
    InitializeInterface
{
    

    // stack fund called from auction contacrt
    // 1% of supply distributed among the stack token
    // there is always more token than 1
    function stackFund(uint256 _amount)
        external
        allowedAddressOnly(msg.sender)
        returns (bool)
    {
        IERC20Token mainToken = IERC20Token(mainTokenAddress);

        if (totalTokenAmount > PERCENT_NOMINATOR) {
            ensureTransferFrom(mainToken, msg.sender, address(this), _amount);

            uint256 ratio = safeDiv(
                safeMul(_amount, safeMul(DECIMAL_NOMINATOR, PERCENT_NOMINATOR)),
                totalTokenAmount
            );

            totalTokenAmount = safeAdd(totalTokenAmount, _amount);

            dayWiseRatio[stackRoundId] = ratio;
        } else
            ensureTransferFrom(
                mainToken,
                msg.sender,
                vaultAddress,
                _amount
            );

        stackRoundId = safeAdd(stackRoundId, 1);
        return true;
    }

    function addFundToStacking(address _whom, uint256 _amount)
        internal
        returns (bool)
    {
        totalTokenAmount = safeAdd(totalTokenAmount, _amount);

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
                    safeMul(DECIMAL_NOMINATOR, PERCENT_NOMINATOR)
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
    function _unlockTokenFromStack(address _whom) internal returns (bool) {
        uint256 _stackToken = calulcateStackFund(_whom);
        uint256 actulToken = safeAdd(stackBalance[_whom], _stackToken);
        ensureTransferFrom(
            IERC20Token(mainTokenAddress),
            address(this),
            _whom,
            actulToken
        );
        totalTokenAmount = safeSub(totalTokenAmount, actulToken);
        stackBalance[_whom] = 0;
        lastRound[_whom] = 0;
        emit StackRemoved(stackRoundId, _whom, actulToken);
    }
    
    function unlockTokenFromStack() external returns (bool) {
        return _unlockTokenFromStack(msg.sender);
    }
    
    function unlockTokenFromStackBehalf(address _whom) external returns (bool) {
        require(IWhiteList(whiteListAddress).address_belongs(_whom) == msg.sender,ERR_AUTHORIZED_ADDRESS_ONLY);
        return _unlockTokenFromStack(_whom);
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
        stackRoundId = 1;
        initializeOwner(_primaryOwner, _systemAddress, _authorityAddress);
        _updateAddresses();
        vaultRatio = 90;
    }

   
    function lockBalance(
        uint256 _auctionDay,
        address _token,
        address _which,
        uint256 _amount
    ) internal returns (bool) {
        if (lockedOn[_which] == 0) {
            lockedOn[_which] = IAuction(auctionAddress).auctionDay();
        }
        uint256 currentBalance = currentLockedFunds[_which][_auctionDay][_token];
        currentLockedFunds[_which][_auctionDay][_token] = safeAdd(currentBalance, _amount);
        emit FundLocked(_token, _which, _amount);
        return true;
    }

    function lockEther(uint256 _auctionDay,address _which)
        public
        payable
        allowedAddressOnly(msg.sender)
        returns (bool)
    {
        return lockBalance(_auctionDay,address(0), _which, msg.value);
    }

  

    function _cancelInvestment(address payable _whom) internal returns (bool) {
        
        require(
            !isTokenLockEndDay(lockedOn[_whom]),
            "ERR_INVESTMENT_CANCEL_PERIOD_OVER"
        );

        uint256 _tokenBalance = lockedFunds[_whom][address(0)];
        if (_tokenBalance > 0) {
            _whom.transfer(_tokenBalance);
            emit FundTransfer(_whom, address(0), _tokenBalance);
            lockedFunds[_whom][address(0)] = 0;
        }

        _tokenBalance = lockedTokens[_whom];
        if (_tokenBalance > 0) {
            IERC20Token _token = IERC20Token(mainTokenAddress);
            approveTransferFrom(_token, vaultAddress, _tokenBalance);

            ITokenVault(vaultAddress).depositeToken(
                _token,
                address(this),
                _tokenBalance
            );

            emit FundTransfer(vaultAddress, address(_token), _tokenBalance);
            lockedTokens[_whom] = 0;
        }
        lockedOn[_whom] = 0;
        emit InvestMentCancelled(_whom, _tokenBalance);
        return true;
    }

    function _unLockTokens(address _which, bool isStacking)
        internal
        returns (bool)
    {
        uint256 _tokenBalance = lockedFunds[_which][address(0)];

        if (_tokenBalance > 0) {
            uint256 walletAmount = safeDiv(
                safeMul(_tokenBalance, vaultRatio),
                100
            );
            uint256 tagAlongAmount = safeSub(_tokenBalance, walletAmount);

            triggerAddress.transfer(tagAlongAmount);
            companyFundWalletAddress.transfer(walletAmount);
            emit FundTransfer(triggerAddress, address(0), tagAlongAmount);
            emit FundTransfer(
                companyFundWalletAddress,
                address(0),
                walletAmount
            );
            lockedFunds[_which][address(0)] = 0;
        }

        _tokenBalance = lockedTokens[_which];

        if (_tokenBalance > 0) {
            IERC20Token _token = IERC20Token(mainTokenAddress);

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
        lockedOn[_which] = 0;
    }

    // user unlock tokens and funds goes to compnay wallet
    function unLockTokens() external returns (bool) {
        return _unLockTokens(msg.sender, false);
    }

    function stackToken() external returns (bool) {
        return _unLockTokens(msg.sender, true);
    }
    
    function cancelInvestment() external returns (bool) {
        return _cancelInvestment(msg.sender);
    }
    
    
    function unLockTokensBehalf(address _whom) external returns (bool) {
        require(IWhiteList(whiteListAddress).address_belongs(_whom) == msg.sender,ERR_AUTHORIZED_ADDRESS_ONLY);
        return _unLockTokens(_whom, false);
    }

    function stackTokenBehalf(address _whom) external returns (bool) {
        require(IWhiteList(whiteListAddress).address_belongs(_whom) == msg.sender,ERR_AUTHORIZED_ADDRESS_ONLY);
        return _unLockTokens(_whom, true);
    }
    
    function cancelInvestmentBehalf(address payable _whom) external returns (bool) {
        require(IWhiteList(whiteListAddress).address_belongs(_whom) == msg.sender,ERR_AUTHORIZED_ADDRESS_ONLY);
        return _cancelInvestment(_whom);
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
        uint256 _auctionDay,
        address _which,
        uint256 _amount
    ) external allowedAddressOnly(msg.sender) returns (bool) {
        IERC20Token token = IERC20Token(mainTokenAddress);

        ensureTransferFrom(token, msg.sender , address(this), _amount);

        lockedTokens[_which] = safeAdd(lockedTokens[_which], _amount);

        if (currentLockedFunds[_which][_auctionDay][address(0)] > 0) {
            uint256 _currentTokenBalance = currentLockedFunds[_which][_auctionDay][address(
                0
            )];
            lockedFunds[_which][address(0)] = safeAdd(
                lockedFunds[_which][address(0)],
                _currentTokenBalance
            );
            currentLockedFunds[_which][_auctionDay][address(0)] = 0;
        }
        emit FundLocked(address(token), _which, _amount);
        return true;
    }
}
