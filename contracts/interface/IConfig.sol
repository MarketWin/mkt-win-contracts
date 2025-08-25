// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IConfig {

    struct ConfigData {
        uint256 platformFee;
        uint256 creatorFee;
        uint256 drawFee;
        uint256 buyFee;
        address feeAddress;
        uint256 initPrice;
        uint256 priceInterval;
        uint256 priceGrowthRate;
        uint256 priceGrowthRateDenominator;
        uint256 denominator;
    }

    function PLATFORM_FEE() external view returns (uint256);
    function CREATOR_FEE() external view returns (uint256);
    function DENOMINATOR() external view returns (uint256);
    function DRAW_FEE() external view returns (uint256);
    function BUY_FEE() external view returns (uint256);
    function feeAddress() external view returns (address);
    function INIT_PRICE() external view returns (uint256);
    function PRICE_INTERVAL() external view returns (uint256);
    function PRICE_GROWTH_RATE() external view returns (uint256);
    function PRICE_GROWTH_RATE_DENOMINATOR() external view returns (uint256);


}