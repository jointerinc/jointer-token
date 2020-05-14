pragma solidity ^0.5.9;

import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
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


contract TokenSpenders is AuctionRegistery, SafeMath {
    mapping(address => bool) isSpender;

    mapping(address => uint256) public spenderIndex;

    address[] public spenders;

    event TokenSpenderAdded(address indexed _which);

    event TokenSpenderRemoved(address indexed _which);

    modifier onlySpender() {
        require(isSpender[msg.sender], ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    function addSpender(address _which)
        external
        onlyAuthorized()
        returns (bool)
    {
        require(!isSpender[_which], ERR_AUTHORIZED_ADDRESS_ONLY);
        isSpender[_which] = true;
        spenderIndex[_which] = spenders.length;
        spenders.push(_which);
        emit TokenSpenderAdded(_which);
        return true;
    }

    function removeSpender(address _which)
        external
        onlyAuthorized()
        returns (bool)
    {
        require(isSpender[_which], ERR_AUTHORIZED_ADDRESS_ONLY);
        uint256 _spenderIndex = spenderIndex[_which];
        address _lastAdress = spenders[safeSub(spenders.length, 1)];
        spenders[_spenderIndex] = _lastAdress;
        spenderIndex[_lastAdress] = _spenderIndex;
        delete isSpender[_which];
        delete spenders[safeSub(spenders.length, 1)];
        emit TokenSpenderRemoved(_which);
        return true;
    }
}


contract TokenVault is Upgradeable, TokenSpenders, InitializeInterface {
    event FundTransfer(
        address indexed _by,
        address _to,
        address _token,
        uint256 amount
    );

    event FundDeposited(address _token, address _from, uint256 _amount);

    function initialize(
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress
    ) public {
        super.initialize();

        contractsRegistry = IAuctionRegistery(_registeryAddress);

        ProxyOwnable.initializeOwner(
            _primaryOwner,
            _systemAddress,
            _authorityAddress
        );
    }

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
        require(postBalance > prevBalance, "ERR_TRANSFER");
    }

    function approveTransferFrom(
        IERC20Token _token,
        address _spender,
        uint256 _amount
    ) internal {
        _token.approve(_spender, _amount);
    }

    function depositeEther() external payable returns (bool) {
        emit FundDeposited(address(0), msg.sender, msg.value);
        return true;
    }

    function depositeToken(IERC20Token _token, address _from, uint256 _amount)
        external
        returns (bool)
    {
        ensureTransferFrom(_token, _from, address(this), _amount);
        emit FundDeposited(address(0), _from, _amount);
        return true;
    }

    function directTransfer(address _token, address _to, uint256 amount)
        external
        onlySpender()
        returns (bool)
    {
        ensureTransferFrom(IERC20Token(_token), address(this), _to, amount);
        emit FundTransfer(msg.sender, _to, _token, amount);
        return true;
    }

    function transferEther(address payable _to, uint256 amount)
        external
        onlySpender()
        returns (bool)
    {
        _to.transfer(amount);
        emit FundTransfer(msg.sender, _to, address(0), amount);
        return true;
    }
}
