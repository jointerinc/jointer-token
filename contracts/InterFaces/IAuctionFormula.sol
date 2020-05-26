pragma solidity ^0.5.9;


contract IAuctionFormula {
    function calcuateAuctionFundDistrubution(
        uint256 _value,
        uint256 downSideProtectionRatio,
        uint256 fundWalletRatio
    )
        public
        pure
        returns (
            uint256,
            uint256,
            uint256
        );

    function calculateMangmentFee(uint256 _supply, uint256 _percent)
        external
        pure
        returns (uint256);

    function calcuateAuctionTokenDistrubution(
        uint256 dayWiseContributionByWallet,
        uint256 dayWiseSupplyCore,
        uint256 dayWiseSupplyBonus,
        uint256 dayWiseContribution,
        uint256 downSideProtectionRatio
    ) external pure returns (uint256, uint256);
}
