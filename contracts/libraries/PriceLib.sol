// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../config/Config.sol";
library PriceLib {
    uint256 private constant DECIMALS = 6;
    uint256 private constant DECIMAL_FACTOR = 10**DECIMALS;

    function calculateSharesForFixedAmount(uint256 currentShares, uint256 amount, Config.ConfigData memory config) external pure returns (uint256 additionalShares,uint256 currentPrice) {
        return _calculateSharesForFixedAmount(currentShares, amount, config);
    }

    function _calculateSharesForFixedAmount(uint256 currentShares, uint256 amount, Config.ConfigData memory config) internal pure returns (uint256 additionalShares,uint256 currentPrice) {
        additionalShares = 0;
        uint256 totalShares = currentShares;
        uint256 remainingAmount = amount;
        uint256 priceInterval = config.priceInterval;
        currentPrice = _calculateSharePrice(totalShares, config);
        while (remainingAmount > 0) {
            uint256 sharesToNextInterval;

            sharesToNextInterval = priceInterval - (totalShares % priceInterval);
            
            uint256 amountToNextInterval = sharesToNextInterval * currentPrice / DECIMAL_FACTOR;
            
            if (remainingAmount > amountToNextInterval) {
                // Buy all shares to next interval
                additionalShares += sharesToNextInterval;
                remainingAmount -= amountToNextInterval;
                totalShares += sharesToNextInterval;
            } else {
                // Buy partial shares within current interval
                uint256 partialShares = remainingAmount * DECIMAL_FACTOR / currentPrice;
                additionalShares += partialShares;
                break;
            }
            currentPrice = _calculateSharePrice(totalShares, config);
        }
        return (additionalShares,currentPrice);
    }
        
    function calculateAmountForShares(uint256 currentShares, uint256 sharesToBuy, Config.ConfigData memory config) external pure returns (uint256 amount) {
        return _calculateAmountForShares(currentShares, sharesToBuy, config);
    }

    function _calculateAmountForShares(uint256 currentShares, uint256 sharesToBuy, Config.ConfigData memory config) internal pure returns (uint256 amount) {
        uint256 totalShares = currentShares;
        uint256 remainingShares = sharesToBuy;
        amount = 0;
        uint256 priceInterval = config.priceInterval;

        while (remainingShares > 0) {
            uint256 currentPrice = _calculateSharePrice(totalShares, config);
            uint256 sharesToNextInterval = priceInterval - (totalShares % priceInterval);
            
            if (remainingShares > sharesToNextInterval) {
                amount += (sharesToNextInterval * currentPrice) / DECIMAL_FACTOR;
                remainingShares -= sharesToNextInterval;
                totalShares += sharesToNextInterval;
            } else {
                amount += (remainingShares * currentPrice) / DECIMAL_FACTOR;
                break;
            }
        }

        return amount;
    }


    function calculateSharePrice(uint256 numShares, Config.ConfigData memory config) external pure returns (uint256) {
        return _calculateSharePrice(numShares, config);
    }

    function _calculateSharePrice(uint256 numShares, Config.ConfigData memory config) internal pure returns (uint256) {
        uint256 initialPrice = config.initPrice;
        uint256 interval = config.priceInterval;
        uint256 growthRate = config.priceGrowthRate;
        uint256 growthRateDenominator = config.priceGrowthRateDenominator;
        uint256 growthTimes = numShares / interval;

        uint256 currentPrice = initialPrice;
        for (uint256 i = 0; i < growthTimes; i++) {
            currentPrice = (currentPrice * (growthRateDenominator + growthRate)) / growthRateDenominator;
        }
        return currentPrice;
    }

}