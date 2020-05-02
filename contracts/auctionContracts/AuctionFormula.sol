pragma solidity 0.5.9;

import "../common/SafeMath.sol";


contract AuctionFormula is SafeMath {
    
    
    uint16 public version = 1;
    
    
    function calcuateAuctionTokenDistrubution(
        uint256 dayWiseContributionByWallet,
        uint256 dayWiseSupplyCore,
        uint256 dayWiseSupplyBonus,
        uint256 dayWiseContribution,
        uint256 downSideProtectionRatio)  
        external
        pure
        returns (uint256, uint256)
    {
        
        uint256 _dayWiseSupplyCore = safeDiv(safeMul(dayWiseSupplyCore,dayWiseContributionByWallet),dayWiseContribution);
        
        uint256 _dayWiseSupplyBonus = 0;
        
        if(dayWiseSupplyBonus > 0 )
            _dayWiseSupplyBonus = safeDiv(safeMul(dayWiseSupplyBonus,dayWiseContributionByWallet),dayWiseContribution);
        
        uint256 _returnAmount = safeAdd(_dayWiseSupplyCore,_dayWiseSupplyBonus);
        
        // user get only 100 - downSideProtectionRatio(90) fund only other fund is locked 
        uint256 _userAmount = safeDiv(safeMul(_dayWiseSupplyCore,safeSub(100,downSideProtectionRatio)),100);
        
        return(_returnAmount,_userAmount);
    }
    
    function calcuateAuctionFundDistrubution(uint256 _value,uint256 downSideProtectionRatio,uint256 fundWalletRatio)
        external
        pure
        returns (uint256, uint256, uint256)
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
    
    
    function calculateVirtualReserve() external pure returns (uint256) {
        
        
    }
    
    
    
    
    function calculateApprectiation(
        uint256 _reserveBaseTokenBalance,
        uint256 _reserveBaseTokenRatio,
        uint256 _reserveMainTokenPrice,
        uint256 _reserveMainTokenRatio,
        uint256 _baseTokenPrice
    ) external pure returns (uint256) {
        
        uint256 ratio = safeDiv(
            safeMul(
                safeMul(_reserveBaseTokenBalance, _reserveMainTokenRatio),
                safeExponent(10, 6)
            ),
            safeMul(_reserveMainTokenPrice, _reserveBaseTokenRatio)
        );
        
        return safeDiv(safeMul(ratio, _baseTokenPrice), safeExponent(10, 6));
    }

    function calculateTokenPrice(
        uint256 _reserveBaseTokenBalance,
        uint256 _reserveBaseTokenRatio,
        uint256 _reserveMainTokenBalance,
        uint256 _reserveMainTokenRatio,
        uint256 _baseTokenPrice
    ) external pure returns (uint256) {
        
        uint256 ratio = safeDiv(
            safeMul(
                safeMul(_reserveBaseTokenBalance, _reserveMainTokenRatio),
                safeExponent(10, 6)
            ),
            safeMul(_reserveMainTokenBalance, _reserveBaseTokenRatio)
        );
        
        return safeDiv(safeMul(ratio, _baseTokenPrice), safeExponent(10, 6));
    }

    function calculateNewSupply(
        uint256 todayContribution,
        uint256 tokenPrice,
        uint256 decimal
    ) external pure returns (uint256) {
        return
            safeDiv(
                safeMul(todayContribution, safeExponent(10, decimal)),
                tokenPrice
            );
    }

    function calculateMangmentFee(uint256 _supply, uint256 _percent)
        external
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
