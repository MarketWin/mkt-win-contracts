// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../config/Config.sol";
import "../libraries/PriceLib.sol";
import "../BaseMarket.sol";

import "../interface/IShareToken.sol";
import "../interface/IMarketNFT.sol";

library DataHelper {

     uint256 private constant DRAW_OPTION_ID = 1e18;
  


    function caclueShares2Amount(uint256 shares,address _config) public view returns (uint256) {
        Config  config = Config(_config);
        Config.ConfigData memory configData = Config.ConfigData({
            platformFee: config.PLATFORM_FEE(),
            creatorFee: config.CREATOR_FEE(),
            drawFee: config.DRAW_FEE(),
            platformBuyFee: config.PLATFORM_BUY_FEE(),
            creatorBuyFee: config.CREATOR_BUY_FEE(),
            feeAddress: config.feeAddress(),
            initPrice: config.INIT_PRICE(),
            priceInterval: config.PRICE_INTERVAL(),
            priceGrowthRate: config.PRICE_GROWTH_RATE(),
            priceGrowthRateDenominator: config.PRICE_GROWTH_RATE_DENOMINATOR(),
            denominator: config.DENOMINATOR()
          });
        uint256 baseAmount = PriceLib.calculateAmountForShares(0,shares, configData);
        uint256 totalAmount = baseAmount * configData.denominator / (configData.denominator - configData.platformBuyFee - configData.creatorBuyFee );
        return totalAmount;
    }



    function calcuateProfitPotential(uint256 _option, uint256 _share ,address _market) external view returns (uint256) {
        BaseMarket market = BaseMarket(_market);
        uint256 allPaidAmount = market.allPaidAmount();
        uint256 currentPaidAmount = market.optionPaidAmount(_option);
        uint256 currentShares = market.optionShares(_option);
        uint256 otherPaidAmount = allPaidAmount - currentPaidAmount;   
        return  otherPaidAmount * _share / (currentShares + _share);
    }


    function culAllRewards(address _market,address _user) external view returns(uint256 rewards,uint256 principal)  {
        BaseMarket market = BaseMarket(_market);
        
        IMarketNFT optionNFT = market.optionNFT();
        uint256 winningOption = market.winningOption();
        uint256 nftBalance = optionNFT.balanceOf(_user);
       
        uint256 totalPrincipal   = 0;
        if(nftBalance == 0){
            return (totalPrincipal ,totalPrincipal);
        }
        uint256 shares = 0;
        for (uint256 i = nftBalance; i > 0; i--) {
            uint256 _tokenId = optionNFT.tokenOfOwnerByIndex(_user, i - 1);
            IMarketNFT.NFTMetadata memory metadata   = optionNFT.getTokenMetadata(_tokenId);
        
            if (metadata.isBurned || (winningOption != metadata.optionId && winningOption != DRAW_OPTION_ID )) {
                continue;
            }
            totalPrincipal += metadata.principal;
            if(winningOption != DRAW_OPTION_ID){
                shares += metadata.shares;  
            }
        }  

        return _calculateReward(shares,totalPrincipal,market);

    }

    function culSingleNftRewards(address _market,uint256 _tokenId,address _user) public view returns(uint256 rewards,uint256 principal){
        BaseMarket market = BaseMarket(_market);

        uint256 winningOption = market.winningOption(); 
        IMarketNFT optionNFT = market.optionNFT();

        uint256 nftBalance = optionNFT.balanceOf(_user);

        if(nftBalance == 0){
            return (0,0);
        }
        IMarketNFT.NFTMetadata memory metadata   = optionNFT.getTokenMetadata(_tokenId);
        require(winningOption == DRAW_OPTION_ID || winningOption == metadata.optionId || metadata.isBurned, "not enough NFTs to withdraw");

        principal = metadata.principal;
        uint256 shares = metadata.shares;

        return _calculateReward(shares,principal,market);
    
    }



     function _calculateReward( uint256 userShares,uint256 principal,BaseMarket  market) private view returns (uint256 ,uint256 ) {
       
        (
            uint256 platformFee,   
            uint256 creatorFee,
            uint256 drawFee,,,,,,,,
            uint256 denominator
        )= market.config();

        uint256 winningOption = market.winningOption(); 
        uint256 totalShares = market.optionShares(winningOption);
        uint256 pot = market.optionPaidAmount(winningOption);
        uint256 rewardPool = market.allPaidAmount() - pot;
        uint256 rewards = rewardPool * userShares / totalShares;

        // fee caculate
      
        rewards = _applyFees(rewards,platformFee,creatorFee,denominator);
         // if the market is a draw, the user paid a draw fee

        if(winningOption == DRAW_OPTION_ID){
            principal = _applyDrawFee(principal,drawFee,denominator);
        }

        return (rewards,principal);
    }

    function _applyFees(uint256 rewards, uint256 platformFee, uint256 creatorFee, uint256 denominator) private pure returns (uint256) {
        uint256 platformFeeAmount = (rewards * platformFee) / denominator;
        uint256 creatorFeeAmount = (rewards * creatorFee) / denominator;
        return rewards - (platformFeeAmount + creatorFeeAmount);
}

    function _applyDrawFee(uint256 principal, uint256 drawFee, uint256 denominator) private pure returns (uint256) {
        uint256 fee = (principal * drawFee) / denominator;
        return principal - fee;
    }
}

