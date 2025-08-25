// PriceMarketHandler.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../handler/BaseMarketHandler.sol";

contract CreatorMarketHandler is BaseMarketHandler {
    constructor(address _config) BaseMarketHandler(_config) {}
    
    /**
     * @dev get market type
     */
    function getMarketType() public pure override returns (uint8) {
        return 2; // Creator market type
    }
    
    /**
     * @dev Creator market specific validation
     */
    function _additionalValidation(IMarket.MarketCreationParams calldata params) internal view override {
        // Creator market specific validation
        require(params.ruleData.length > 0, "Creator rule data required");
        if(params.resolveTime != 0){
            require(params.resolveTime >= params.mintEndTime, "Invalid resolve time");
        } 
    }
    
    /**
     * @dev Creator market initialization specific processing
     */
    function _afterInitialize(
        address marketAddress,
        IMarket.MarketCreationParams memory params
    ) internal override {
        // Handle specific initialization requirements for creator market
        // For example, setting creator data source, configuring oracle, etc.
    }
}