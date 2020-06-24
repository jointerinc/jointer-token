pragma solidity ^0.5.9;

import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../common/TokenTransfer.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IAuctionTagAlong.sol";
import "../InterFaces/IAuctionProtection.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IAuctionLiquadity.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IToken.sol";
import "../InterFaces/IIndividualBonus.sol";
import "../InterFaces/IWhiteList.sol";

interface InitializeInterface {
    function initialize(
        uint256 _startTime,
        uint256 _minAuctionTime,
        uint256 _interval,
        address _primaryOwner,
        address _systemAddress,
        address _multisigAddress,
        address _registeryAddress
    ) external;
}

contract AuctionRegistery is ProxyOwnable, AuctionRegisteryContracts {
    IAuctionRegistery public contractsRegistry;

    address payable public whiteListAddress;
    address payable public smartSwapAddress;
    address payable public currencyPricesAddress;
    address payable public vaultAddress;
    address payable public mainTokenAddress;
    address payable public auctionProtectionAddress;
    address payable public liquadityAddress;
    address payable public companyFundWalletAddress;
    address payable public companyTokenWalletAddress;
    address payable public individualBonusAddress;

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
        whiteListAddress = getAddressOf(WHITE_LIST);
        smartSwapAddress = getAddressOf(SMART_SWAP);
        currencyPricesAddress = getAddressOf(CURRENCY);
        vaultAddress = getAddressOf(VAULT);
        mainTokenAddress = getAddressOf(MAIN_TOKEN);
        auctionProtectionAddress = getAddressOf(AUCTION_PROTECTION);
        liquadityAddress = getAddressOf(LIQUADITY);
        companyFundWalletAddress = getAddressOf(COMPANY_FUND_WALLET);
        companyTokenWalletAddress = getAddressOf(COMPANY_MAIN_TOKEN_WALLET);
        individualBonusAddress = getAddressOf(INDIVIDUAL_BONUS);
    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
    }
}

contract AuctionUtils is AuctionRegistery {
    
    uint256 public constant PRICE_NOMINATOR = 10**9;
    
    uint256 public constant DECIMAL_NOMINATOR = 10**18;

    // allowed contarct limit the contribution
    uint256 public maxContributionAllowed;

    // managment fee to run auction cut from basesupply
    uint256 public mangmentFee;

    uint256 public stacking;

    // fund that will be locked in contacrt
    uint256 public downSideProtectionRatio;

    // Fund goes to companyWallet
    uint256 public fundWalletRatio;

    // if contribution reach above yesterdayContribution groupBonus multiplyer
    uint256 public groupBonusRatio;

    // user neeed this amount of mainToken to contribute
    uint256 public mainTokenRatio;

    // how much buffer we allow to user contribute more
    uint256 public bufferLimit;

    //ByDefault it false
    bool public mainTokencheckOn;

    function initializeUtils() internal {
        maxContributionAllowed = 150;
        mangmentFee = 2;
        stacking = 1;
        downSideProtectionRatio = 90;
        fundWalletRatio = 90;
        groupBonusRatio = 2;
        mainTokenRatio = 100;
        bufferLimit = 105;
    }

    function setGroupBonusRatio(uint256 _groupBonusRatio)
        external
        onlyOwner()
        returns (bool)
    {
        groupBonusRatio = _groupBonusRatio;
        return true;
    }


    function setBufferLimit(uint256 _bufferLimit)
        external
        onlyOwner()
        returns (bool)
    {
        bufferLimit = _bufferLimit;
        return true;
    }

    function setDownSideProtectionRatio(uint256 _ratio)
        external
        onlyOwner()
        returns (bool)
    {
        require(_ratio < 100, "ERR_SHOULD_BE_LESS_THAN_100");
        downSideProtectionRatio = _ratio;
        return true;
    }

    function setfundWalletRatio(uint256 _ratio)
        external
        onlyOwner()
        returns (bool)
    {
        require(_ratio < 100, "ERR_SHOULD_BE_LESS_THAN_100");
        fundWalletRatio = _ratio;
        return true;
    }

    function setMainTokenRatio(uint256 _ratio)
        external
        onlyOwner()
        returns (bool)
    {
        mainTokenRatio = _ratio;
        return true;
    }

    function setMainTokenCheckOn(bool _mainTokencheckOn)
        external
        onlyOwner()
        returns (bool)
    {
        mainTokencheckOn = _mainTokencheckOn;
        return true;
    }

    function setMaxContributionAllowed(uint256 _maxContributionAllowed)
        external
        onlyOwner()
        returns (bool)
    {
        maxContributionAllowed = _maxContributionAllowed;
        return true;
    }
}

contract AuctionFormula is SafeMath, TokenTransfer {
    
    function calcuateAuctionTokenDistrubution(
        uint256 dayWiseContributionByWallet,
        uint256 dayWiseSupplyCore,
        uint256 dayWiseSupplyBonus,
        uint256 dayWiseContribution,
        uint256 downSideProtectionRatio
    ) internal pure returns (uint256, uint256) {
        
        uint256 _dayWiseSupplyCore = safeDiv(
            safeMul(dayWiseSupplyCore, dayWiseContributionByWallet),
            dayWiseContribution
        );

        uint256 _dayWiseSupplyBonus = 0;
        if (dayWiseSupplyBonus > 0)
            _dayWiseSupplyBonus = safeDiv(
                safeMul(dayWiseSupplyBonus, dayWiseContributionByWallet),
                dayWiseContribution
            );
        uint256 _returnAmount = safeAdd(
            _dayWiseSupplyCore,
            _dayWiseSupplyBonus
        );

        // user get only 100 - downSideProtectionRatio(90) fund only other fund is locked
        uint256 _userAmount = safeDiv(
            safeMul(_dayWiseSupplyCore, safeSub(100, downSideProtectionRatio)),
            100
        );

        return (_returnAmount, _userAmount);
    }

    function calcuateAuctionFundDistrubution(
        uint256 _value,
        uint256 downSideProtectionRatio,
        uint256 fundWalletRatio
    )
        internal
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 _downsideAmount = safeDiv(
            safeMul(_value, downSideProtectionRatio),
            100
        );
        uint256 newvalue = safeSub(_value, _downsideAmount);

        uint256 _fundwallet = safeDiv(safeMul(newvalue, fundWalletRatio), 100);

        newvalue = safeSub(newvalue, _fundwallet);

        return (_downsideAmount, _fundwallet, newvalue);
    }

    function calculateNewSupply(
        uint256 todayContribution,
        uint256 tokenPrice,
        uint256 decimal
    ) internal pure returns (uint256) {
        return
            safeDiv(
                safeMul(todayContribution, safeExponent(10, decimal)),
                tokenPrice
            );
    }

    function calculateSupplyPercent(uint256 _supply, uint256 _percent)
        internal
        pure
        returns (uint256)
    {
        uint256 _tempSupply = safeDiv(
            safeMul(_supply, 100),
            safeSub(100, _percent)
        );
        uint256 _managmantFee = safeSub(_tempSupply, _supply);
        return _managmantFee;
    }
}

contract AuctionStorage is AuctionFormula, AuctionUtils {
    uint256 public auctionDay;

    // address how much invested by them in auciton till date
    mapping(address => uint256) public userTotalFund;

    // how much token recived by address in auciton till date
    mapping(address => uint256) public userTotalReturnToken;

    // day wise supply (groupBounus+coreSupply)
    mapping(uint256 => uint256) public dayWiseSupply;

    // day wise  coreSupply
    mapping(uint256 => uint256) public dayWiseSupplyCore;

    // day wise bonusSupply
    mapping(uint256 => uint256) public dayWiseSupplyBonus;

    // daywise contribution
    mapping(uint256 => uint256) public dayWiseContribution;

    // daywise markertPrice
    mapping(uint256 => uint256) public dayWiseMarketPrice;

    // dayWise downsideProtection Ratio
    mapping(uint256 => uint256) public dayWiseDownSideProtectionRatio;

    // address wise contribution each day
    mapping(uint256 => mapping(address => uint256))
        public walletDayWiseContribution;

    // day wiser five top contributor
    mapping(uint256 => mapping(uint256 => address)) public topFiveContributior;

    //contributor Index
    mapping(uint256 => mapping(address => uint256)) public topContributiorIndex;

    // check if daywise token disturbuted
    mapping(uint256 => mapping(address => bool)) public returnToken;

    // total contribution till date
    uint256 public totalContribution;

    uint256 public todayContribution;

    uint256 public yesterdayContribution;

    uint256 public allowedMaxContribution;

    uint256 public yesterdaySupply;

    uint256 public todaySupply;

    bool public auctionSoldOut;
    
    
    function initializeStorage() internal {
        auctionDay = 1;
        totalContribution = 2500000 * PRICE_NOMINATOR;
        yesterdayContribution = 500 * PRICE_NOMINATOR;
        allowedMaxContribution = 500 * PRICE_NOMINATOR;
        todaySupply = 50000 * DECIMAL_NOMINATOR;
    }
}

contract IndividualBonus is AuctionStorage {
    
    //the bouns percentaage part
    mapping(uint256 => uint256) public indexReturn;
    
    //Every following state varibale will be kept track of on per day basis
    //the top5Amounts contributed for a day
    mapping(uint256 => uint256[6]) public top5Amounts;

    //keep track of addresses as well as the amounts
    //index to array to addresses
    mapping(uint256 => mapping(uint256 => address[]))
        public indexToContributors;

    //At what index an address is
    mapping(uint256 => mapping(address => uint256)) public addressWhichIndex;

    //When the same guy contributes again need to just reset its index and recompute its place
    //As if it was coming in for the first time
    //So we need to keep track at which index was it in at the time and delete him from that index
    mapping(uint256 => mapping(address => uint256))
        public addressWhichInnerIndex;
    
    uint256 public X_1;
    uint256 public X_2;
    uint256 public X_3;
    uint256 public X_4;
    uint256 public X_5;
    
    
    function updateIndividualBonusRatio(uint256 X1,uint256 X2,uint256 X3,uint256 X4,uint256 X5) external onlyAuthorized(){
        X_1 = X1;
        X_2 = X2;
        X_3 = X3;
        X_4 = X4;
        X_5 = X5;
        indexReturn[1] = X_1;
        indexReturn[2] = X_2;
        indexReturn[3] = X_3;
        indexReturn[4] = X_4;
        indexReturn[5] = X_5;
    }
    
    function _compareTopContributors(address _from) internal {
       
        uint256 currentAmount = walletDayWiseContribution[auctionDay][_from];

        //If the same guy comes delete him and recompute his place
        if (addressWhichIndex[auctionDay][_from] != 0) {
            //the array from which we need to delete the _from


                address[] storage contributorsAt
             = indexToContributors[auctionDay][addressWhichIndex[auctionDay][_from]];

            uint256 indexTodelete = addressWhichInnerIndex[auctionDay][_from];

            for (
                uint256 i = indexTodelete;
                i < safeSub(contributorsAt.length, 1);
                i = safeAdd(i, 1)
            ) {
                contributorsAt[indexTodelete] = contributorsAt[safeAdd(
                    indexTodelete,
                    1
                )];
            }
            delete contributorsAt[safeSub(contributorsAt.length, 1)];
            contributorsAt.length = safeSub(contributorsAt.length, 1);

            // we also need to take him out of the race i.e. his last topContribution so that he is not competing against himself
            //but only if it is the only one who has that same currentAmount
            if (contributorsAt.length == 0) {
                indexTodelete = addressWhichIndex[auctionDay][_from];

                for (
                    uint256 i = indexTodelete;
                    i < safeSub(top5Amounts[auctionDay].length, 1);
                    i = safeAdd(i, 1)
                ) {
                    top5Amounts[auctionDay][indexTodelete] = top5Amounts[auctionDay][safeAdd(
                        indexTodelete,
                        1
                    )];
                }
                delete top5Amounts[auctionDay][safeSub(
                    top5Amounts[auctionDay].length,
                    1
                )];
            }
            //the last would be overwritten in the same function
        }

        //Do all this only if contribution is larger then the 5th guy

        if (top5Amounts[auctionDay][5] <= currentAmount) {
            uint256 i;
            bool flag;
            for (i = 5; i >= 1; i = safeSub(i, 1)) {
                //if it is equal to something just add it to the array and dont disturb anything else(Hence the flag)
                if (
                    currentAmount == top5Amounts[auctionDay][i] &&
                    top5Amounts[auctionDay][i] != 0
                ) {
                    addressWhichInnerIndex[auctionDay][_from] = safeSub(
                        indexToContributors[auctionDay][i].push(_from),
                        1
                    );

                    addressWhichIndex[auctionDay][_from] = i;
                    flag = true;
                }
                //Find the right place for it
                //Go inner untill you have find the right place
                if (currentAmount < top5Amounts[auctionDay][i]) break;
            }

            if (!flag) {
                //if i==0 meaning it is grater than everythig else than add it to the first index
                //In all other cases the break function will give you the right index

                i = safeAdd(i, 1);
                //replace all the before ones
                for (uint256 j = 5; j > i; j = safeSub(j, 1)) {
                    top5Amounts[auctionDay][j] = top5Amounts[auctionDay][safeSub(
                        j,
                        1
                    )];

                    indexToContributors[auctionDay][j] = indexToContributors[auctionDay][safeSub(
                        j,
                        1
                    )];

                    for (
                        uint256 k = 0;
                        k < indexToContributors[auctionDay][j].length;
                        k = safeAdd(k, 1)
                    )
                        addressWhichIndex[auctionDay][indexToContributors[auctionDay][j][k]] = j;
                }
                top5Amounts[auctionDay][i] = currentAmount;
                indexToContributors[auctionDay][i].length = 0; //Why? becuse we need to overwrite it
                addressWhichInnerIndex[auctionDay][_from] = safeSub(
                    indexToContributors[auctionDay][i].push(_from),
                    1
                );
                addressWhichIndex[auctionDay][_from] = i;
            }
        }
    }
    
    
    //This will return how much percentage _which should get
    function _calculateIndividualBouns(uint256 _auctionDay, address _from)
        internal
        view
        returns (uint256)
    {
        uint256 index = addressWhichIndex[_auctionDay][_from];
        //if this one is not in top5 then return 0
        if (index == 0) return 0;
        //Now start counting how many addresses ahead of him
        uint256 i;
        //We need start count from one to reflect that there are this many guys before you
        uint256 count = 1;
        for (i = safeSub(index, 1); i >= 1; i = safeSub(i, 1)) {
            if (count > 5) return 0;
            //lets find out how many are at ith index
            count = safeAdd(count, indexToContributors[_auctionDay][i].length);
        }
        //Do the calculation only if count is less than 5 because if there are 5 contributor ahead of you then you get nothing

        // //If there are not addresses with same amount
        // if (indexToContributors[index].length == 1) return indexReturn[count];

        //If there is... then

        //how many are there?
        uint256 sameAmountAddresses = indexToContributors[_auctionDay][index]
            .length;
        //what the total
        uint256 totalPercentToShare;
        //count from what they have before them to how many they are now
        for (
            uint256 k = count;
            k < safeAdd(count, sameAmountAddresses) && k <= 5;
            k = safeAdd(k, 1)
        ) {
            totalPercentToShare = safeAdd(totalPercentToShare, indexReturn[k]);
        }
        //now divide it amognst them
        // returnAmount = totalPercentToShare / sameAmountAddresses;
        return safeDiv(totalPercentToShare, sameAmountAddresses);

        //NOTE: We can delete the storage varibales at the end when the calculation is done
    }
    
}

contract AuctionFundCollector is IndividualBonus {
    event FundAdded(
        uint256 indexed _auctionDayId,
        uint256 _todayContribution,
        address indexed _fundBy,
        address indexed _fundToken,
        uint256 _fundAmount,
        uint256 _fundValue,
        uint256 _marketPrice
    );

    // check before contribution
    function _checkContribution(address _from) internal view returns (bool) {
        require(
            IWhiteList(whiteListAddress).isWhiteListed(_from),
            "ERR_WHITELIST_CHECK"
        );
        return true;
    }

    function mainTokenCheck(address _from, uint256 _contributedAmount)
        internal
        returns (bool)
    {
        IERC20Token mainToken = IERC20Token(mainTokenAddress);

        uint256 _mainTokenPrice = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(mainTokenAddress);

        uint256 _tokenAmount = safeDiv(
            safeMul(
                safeDiv(
                    safeMul(mainToken.balanceOf(_from), mainTokenRatio),
                    100
                ),
                _mainTokenPrice
            ),
            safeExponent(10, mainToken.decimals())
        );

        require(
            _tokenAmount >=
                safeAdd(
                    walletDayWiseContribution[auctionDay][_from],
                    _contributedAmount
                ),
            "ERR_USER_DONT_HAVE_ENOUGH_TOKEN"
        );

        uint256 lockToken = safeDiv(
            safeAdd(
                walletDayWiseContribution[auctionDay][_from],
                _contributedAmount
            ),
            _mainTokenPrice
        );

        IToken(mainTokenAddress).lockToken(_from, lockToken, now);
    }
    
    
    function fundAdded(
        address _token,
        uint256 _amount,
        uint256 _decimal,
        address _from,
        uint256 currentMarketPrice
    ) internal {
        require(auctionSoldOut == false, "ERR_AUCTION_SOLD_OUT");

        uint256 _currencyPrices = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(_token);

        uint256 _contributedAmount = safeDiv(
            safeMul(_amount, _currencyPrices),
            safeExponent(10, _decimal)
        );

        if (mainTokencheckOn) {
            mainTokenCheck(_from, _contributedAmount);
        }

        // allow five percent more for buffer
        // Allow five percent more because of volatility in ether price
        if (
            safeAdd(todayContribution, _contributedAmount) >=
            allowedMaxContribution
        ) {
            require(
                safeDiv(safeMul(allowedMaxContribution, bufferLimit), 100) >=
                    safeAdd(todayContribution, _contributedAmount),
                "ERR_CONTRIBUTION_LIMIT_REACH"
            );

            auctionSoldOut = true;
        }

        todayContribution = safeAdd(todayContribution, _contributedAmount);

        walletDayWiseContribution[auctionDay][_from] = safeAdd(
            walletDayWiseContribution[auctionDay][_from],
            _contributedAmount
        );

        userTotalFund[_from] = safeAdd(
            userTotalFund[_from],
            _contributedAmount
        );

        dayWiseContribution[auctionDay] = safeAdd(
            dayWiseContribution[auctionDay],
            _contributedAmount
        );

       _compareTopContributors(_from);

        emit FundAdded(
            auctionDay,
            todayContribution,
            _from,
            _token,
            _amount,
            _contributedAmount,
            currentMarketPrice
        );
    }

    function _contributeWithEther(uint256 _value, address _from)
        internal
        returns (bool)
    {
        (
            uint256 downSideAmount,
            uint256 fundWalletamount,
            uint256 reserveAmount
        ) = calcuateAuctionFundDistrubution(
            _value,
            dayWiseDownSideProtectionRatio[auctionDay],
            fundWalletRatio
        );

        IAuctionProtection(auctionProtectionAddress).lockEther.value(
            downSideAmount
        )(_from);

        uint256 currentMarketPrice = IAuctionLiquadity(liquadityAddress)
            .contributeWithEther
            .value(reserveAmount)();

        companyFundWalletAddress.transfer(fundWalletamount);

        fundAdded(address(0), _value, 18, _from, currentMarketPrice);
    }

    function _contributeWithToken(
        IERC20Token _token,
        uint256 _value,
        address _from
    ) internal returns (bool) {
        ensureTransferFrom(_token, _from, address(this), _value);

        (
            uint256 downSideAmount,
            uint256 fundWalletamount,
            uint256 reserveAmount
        ) = calcuateAuctionFundDistrubution(
            _value,
            dayWiseDownSideProtectionRatio[auctionDay],
            fundWalletRatio
        );

        approveTransferFrom(_token, auctionProtectionAddress, downSideAmount);

        IAuctionProtection(auctionProtectionAddress).lockTokens(
            _token,
            address(this),
            _from,
            downSideAmount
        );

        approveTransferFrom(_token, liquadityAddress, reserveAmount);

        uint256 currentMarketPrice = IAuctionLiquadity(liquadityAddress)
            .contributeWithToken(_token, address(this), reserveAmount);

        ensureTransferFrom(
            _token,
            address(this),
            companyFundWalletAddress,
            fundWalletamount
        );

        fundAdded(address(_token), _value, 18, _from, currentMarketPrice);
    }

    function contributeWithEther() external payable returns (bool) {
        require(_checkContribution(msg.sender));
        return _contributeWithEther(msg.value, msg.sender);
    }

    function contributeWithToken(IERC20Token _token, uint256 _value)
        external
        returns (bool)
    {
        require(_checkContribution(msg.sender));
        return _contributeWithToken(_token, _value, msg.sender);
    }
}

contract Auction is Upgradeable, AuctionFundCollector, InitializeInterface {
    uint256 public MIN_AUCTION_END_TIME; //epoch

    uint256 public LAST_AUCTION_START;

    uint256 public INTERVAL;

    function changeTimings(uint256 _flag, uint256 _time)
        external
        onlyAuthorized()
        returns (bool)
    {
        if (_flag == 1) MIN_AUCTION_END_TIME = _time;
        else if (_flag == 2) LAST_AUCTION_START == _time;
        else if (_flag == 3) INTERVAL == _time;
        return true;
    }

    function initialize(
        uint256 _startTime,
        uint256 _minAuctionTime,
        uint256 _interval,
        address _primaryOwner,
        address _systemAddress,
        address _multisigAddress,
        address _registeryAddress
    ) public {
        super.initialize();
        initializeOwner(_primaryOwner, _systemAddress, _multisigAddress);
        initializeStorage();
        initializeUtils();
        contractsRegistry = IAuctionRegistery(_registeryAddress);
        _updateAddresses();

        dayWiseDownSideProtectionRatio[auctionDay] = downSideProtectionRatio;
        LAST_AUCTION_START = _startTime;
        MIN_AUCTION_END_TIME = _minAuctionTime;
        INTERVAL = _interval;
        X_1 = 50 * PRICE_NOMINATOR;
        X_2 = 40 * PRICE_NOMINATOR;
        X_3 = 30 * PRICE_NOMINATOR;
        X_4 = 20 * PRICE_NOMINATOR;
        X_5 = 10 * PRICE_NOMINATOR;
        indexReturn[1] = X_1;
        indexReturn[2] = X_2;
        indexReturn[3] = X_3;
        indexReturn[4] = X_4;
        indexReturn[5] = X_5;
    }

    event AuctionEnded(
        uint256 indexed _auctionDayId,
        uint256 _todaySupply,
        uint256 _yesterdaySupply,
        uint256 _todayContribution,
        uint256 _yesterdayContribution,
        uint256 _totalContribution,
        uint256 _maxContributionAllowed,
        uint256 _tokenPrice,
        uint256 _tokenMarketPrice
    );

    event FundDeposited(address _token, address indexed _from, uint256 _amount);

    event TokenDistrubuted(
        address indexed _whom,
        uint256 indexed dayId,
        uint256 _totalToken,
        uint256 lockedToken,
        uint256 _userToken
    );

    function getAuctionDetails()
        external
        view
        returns (
            uint256 _todaySupply,
            uint256 _yesterdaySupply,
            uint256 _todayContribution,
            uint256 _yesterdayContribution,
            uint256 _totalContribution,
            uint256 _maxContributionAllowed,
            uint256 _marketPrice
        )
    {
        uint256 _mainTokenPrice = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(mainTokenAddress);

        return (
            todaySupply,
            yesterdaySupply,
            todayContribution,
            yesterdayContribution,
            totalContribution,
            allowedMaxContribution,
            _mainTokenPrice
        );
    }

    function auctionEnd() external onlySystem() returns (bool) {
        require(
            now >= safeAdd(LAST_AUCTION_START, MIN_AUCTION_END_TIME),
            "ERR_MIN_TIME_IS_NOT_OVER"
        );

        uint256 _mainTokenPrice = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(mainTokenAddress);

        if (todayContribution == 0) {
            uint256 _ethPrice = ICurrencyPrices(currencyPricesAddress)
                .getCurrencyPrice(address(0));

            uint256 mainReserveAmount = IAuctionLiquadity(liquadityAddress)
                .contributeTowardMainReserve();

            uint256 mainReserveAmountUsd = safeDiv(
                safeMul(mainReserveAmount, _ethPrice),
                DECIMAL_NOMINATOR
            );

            dayWiseContribution[auctionDay] = mainReserveAmountUsd;

            todayContribution = mainReserveAmountUsd;

            walletDayWiseContribution[auctionDay][vaultAddress] = mainReserveAmountUsd;

            _mainTokenPrice = ICurrencyPrices(currencyPricesAddress)
                .getCurrencyPrice(mainTokenAddress);

            emit FundAdded(
                auctionDay,
                todayContribution,
                vaultAddress,
                address(0),
                mainReserveAmount,
                mainReserveAmountUsd,
                _mainTokenPrice
            );
        }

        uint256 bonusSupply = 0;

        allowedMaxContribution = safeDiv(
            safeMul(todayContribution, maxContributionAllowed),
            100
        );

        if (todayContribution > yesterdayContribution) {
            uint256 _groupBonusRatio = safeMul(
                safeDiv(
                    safeMul(todayContribution, DECIMAL_NOMINATOR),
                    yesterdayContribution
                ),
                groupBonusRatio
            );

            bonusSupply = safeSub(
                safeDiv(
                    safeMul(todaySupply, _groupBonusRatio),
                    DECIMAL_NOMINATOR
                ),
                todaySupply
            );
        }

        uint256 _avgDays = 10;
        uint256 _avgInvestment = 0;

        if (auctionDay < 11 && auctionDay > 1) {
            _avgDays = safeSub(auctionDay,1);
        }
        
        if(auctionDay > 1){
            for (uint32 tempX = 1; tempX <= _avgDays; tempX++) {
                _avgInvestment = safeAdd(
                    _avgInvestment,
                    dayWiseContribution[safeSub(auctionDay, tempX)]
                );
            }
    
            _avgInvestment = safeDiv(
                safeMul(safeDiv(_avgInvestment, _avgDays), maxContributionAllowed),
                100
            );
        }

        if (_avgInvestment > allowedMaxContribution) {
            allowedMaxContribution = _avgInvestment;
        }

        dayWiseSupplyCore[auctionDay] = todaySupply;
        dayWiseSupplyBonus[auctionDay] = bonusSupply;
        dayWiseSupply[auctionDay] = safeAdd(todaySupply, bonusSupply);
        
        
        uint256 stackingAmount = safeDiv(
            safeMul(dayWiseSupply[auctionDay],stacking),100
        );
        uint256 fee = calculateSupplyPercent(
            safeAdd(stackingAmount,dayWiseSupply[auctionDay]),
            mangmentFee
        );
        IToken(mainTokenAddress).mintTokens(safeAdd(fee, stackingAmount));
        ensureTransferFrom(
            IERC20Token(mainTokenAddress),
            address(this),
            companyTokenWalletAddress,
            fee
        );

        approveTransferFrom(
            IERC20Token(mainTokenAddress),
            auctionProtectionAddress,
            stackingAmount
        );

        IAuctionProtection(auctionProtectionAddress).stackFund(stackingAmount);

        uint256 _tokenPrice = safeDiv(
            safeMul(todayContribution, DECIMAL_NOMINATOR),
            dayWiseSupply[auctionDay]
        );

        dayWiseMarketPrice[auctionDay] = _mainTokenPrice;

        todaySupply = safeDiv(
            safeMul(todayContribution, DECIMAL_NOMINATOR),
            _mainTokenPrice
        );

        totalContribution = safeAdd(totalContribution, todayContribution);

        yesterdaySupply = dayWiseSupply[auctionDay];

        yesterdayContribution = todayContribution;

        auctionDay = safeAdd(auctionDay, 1);

        IAuctionLiquadity(liquadityAddress).auctionEnded();

        dayWiseDownSideProtectionRatio[auctionDay] = downSideProtectionRatio;

        LAST_AUCTION_START = safeAdd(LAST_AUCTION_START, INTERVAL);

        auctionSoldOut = false;

        todayContribution = 0;

        emit AuctionEnded(
            auctionDay,
            todaySupply,
            yesterdaySupply,
            todayContribution,
            yesterdayContribution,
            totalContribution,
            allowedMaxContribution,
            _tokenPrice,
            _mainTokenPrice
        );

        return true;
    }

    function _disturbuteToken(uint256 dayId, address _which)
        internal
        returns (bool)
    {
        require(
            returnToken[dayId][_which] == false,
            "ERR_ALREADY_TOKEN_DISTBUTED"
        );


            uint256 dayWiseContributionByWallet
         = walletDayWiseContribution[dayId][_which];

        uint256 dayWiseContribution = dayWiseContribution[dayId];

        (
            uint256 returnAmount,
            uint256 _userAmount
        ) = calcuateAuctionTokenDistrubution(
            dayWiseContributionByWallet,
            dayWiseSupplyCore[dayId],
            dayWiseSupplyBonus[dayId],
            dayWiseContribution,
            dayWiseDownSideProtectionRatio[dayId]
        );

        uint256 _percent = _calculateIndividualBouns(dayId,_which);
        
        uint256 newReturnAmount = 0;
        
        uint256 fee = 0;
        
        if(_percent > 0){
            newReturnAmount = safeDiv(safeMul(returnAmount,_percent),safeMul(100,PRICE_NOMINATOR));
            fee = calculateSupplyPercent(
                newReturnAmount,
                mangmentFee
            );
        }
        
        newReturnAmount = safeAdd(returnAmount,newReturnAmount);
        
        IToken(mainTokenAddress).mintTokens(safeAdd(newReturnAmount,fee));
        
        // here we check with last auction bcz user can invest after auction start
        IToken(mainTokenAddress).lockToken(_which, 0, LAST_AUCTION_START);
        
        ensureTransferFrom(
            IERC20Token(mainTokenAddress),
            address(this),
            companyTokenWalletAddress,
            fee
        );
        ensureTransferFrom(
            IERC20Token(mainTokenAddress),
            address(this),
            _which,
            _userAmount
        );

        approveTransferFrom(
            IERC20Token(mainTokenAddress),
            auctionProtectionAddress,
            safeSub(newReturnAmount, _userAmount)
        );

        IAuctionProtection(auctionProtectionAddress).depositToken(
            address(this),
            _which,
            safeSub(newReturnAmount, _userAmount)
        );

        returnToken[dayId][_which] = true;
        emit TokenDistrubuted(
            _which,
            dayId,
            newReturnAmount,
            safeSub(newReturnAmount, _userAmount),
            _userAmount
        );
        return true;
    }

    function disturbuteTokens(uint256 dayId, address[] calldata _which)
        external
        onlySystem()
        returns (bool)
    {
        require(dayId < auctionDay, "ERR_AUCTION_DAY");
        for (uint256 tempX = 0; tempX < _which.length; tempX++) {
            if (returnToken[dayId][_which[tempX]] == false)
                _disturbuteToken(dayId, _which[tempX]);
        }
        return true;
    }

    function disturbuteTokens(uint256 dayId) external returns (bool) {
        require(dayId < auctionDay, "ERR_AUCTION_DAY");
        _disturbuteToken(dayId, msg.sender);
    }

    //In case if there is other tokens into contract
    function returnFund(
        IERC20Token _token,
        uint256 _value,
        address payable _which
    ) external onlyOwner() returns (bool) {
        if (address(_token) == address(0)) {
            _which.transfer(_value);
        } else {
            ensureTransferFrom(_token, address(this), _which, _value);
        }
        return true;
    }

    function() external payable {
        emit FundDeposited(address(0), msg.sender, msg.value);
    }
}
