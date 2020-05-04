pragma solidity ^0.5.9;

contract IAuctionFormula {
   
   function calculateLiquadityReduction(uint256 yesterdayPrice, 
    uint256 dayBeforyesterdayPrice,
    uint256 yesterDaycontibution,
    uint256 reserveSupplyBaseToken,
    uint256 _baseTokenPrice
    )
        external
        pure
        returns (uint256);
        
   function calculateTokenPrice(
        uint256 _reserveBaseTokenBalance,
        uint256 _reserveBaseTokenRatio,
        uint256 _reserveMainTokenBalance,
        uint256 _reserveMainTokenRatio,
        uint256 _baseTokenPrice
    ) public pure returns (uint256);

    function calculateApprectiation(
        uint256 _reserveBaseTokenBalance,
        uint256 _reserveBaseTokenRatio,
        uint256 _reserveMainTokenPrice,
        uint256 _reserveMainTokenRatio,
        uint256 _baseTokenPrice
    ) public pure returns (uint256);
    
      function calcuateAuctionFundDistrubution(uint256 _value,uint256 downSideProtectionRatio,uint256 fundWalletRatio)
        public
        pure
        returns (uint256, uint256, uint256);
        
    
    function calculateMangmentFee(uint256 _supply, uint256 _percent)
        external
        pure
        returns (uint256);
    
     function calcuateAuctionTokenDistrubution(
        uint256 dayWiseContributionByWallet,
        uint256 dayWiseSupplyCore,
        uint256 dayWiseSupplyBonus,
        uint256 dayWiseContribution,
        uint256 downSideProtectionRatio)  
        external
        pure
        returns (uint256, uint256);
}