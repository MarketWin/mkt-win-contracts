// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../handler/BaseMarketHandler.sol";
import "../price/PriceMarket.sol";
import "../../config/Config.sol";

contract PriceMarketHandler is BaseMarketHandler {
    constructor(address _config) BaseMarketHandler(_config) {}
    
    /**
     * @dev Get market type ID
     */
    function getMarketType() public pure override returns (uint8) {
        return 1; // Price market type
    }
    
    /**
     * @dev Additional validation for price market
     */
 
    function _additionalValidation(IMarket.MarketCreationParams calldata params) internal view override {
        // Decode symbol from ruleData
        (string memory symbol, string memory optionNameIfTrue, string memory optionNameIfFalse) = _decodeRuleData(params.ruleData);
        
        // Price market specific validation
        address priceFeedAddress = Config(config).getPriceFeed(symbol);
        require(priceFeedAddress != address(0), "Price feed not configured for this symbol");

        // Validate option names
        require(bytes(optionNameIfTrue).length > 0 && bytes(optionNameIfFalse).length > 0, "Option names cannot be empty");
        require(keccak256(bytes(optionNameIfTrue)) != keccak256(bytes(optionNameIfFalse)), "Option names must be different");
        
        // Verify that optionNameIfTrue and optionNameIfFalse exist in shareInitParams
        bool foundTrue = false;
        bool foundFalse = false;
        
        for (uint256 i = 0; i < params.shareInitParams.length; i++) {
            if (keccak256(bytes(params.shareInitParams[i].title)) == keccak256(bytes(optionNameIfTrue))) {
                foundTrue = true;
            }
            if (keccak256(bytes(params.shareInitParams[i].title)) == keccak256(bytes(optionNameIfFalse))) {
                foundFalse = true;
            }
        }
        
        require(foundTrue, "Option name if true must exist in share init params");
        require(foundFalse, "Option name if false must exist in share init params");
    }
    
    /**
     * @dev Price market after initialization specific processing
     */
    function _afterInitialize(
        address marketAddress,
        IMarket.MarketCreationParams memory params
    ) internal override {
        // Handle specific initialization requirements for price market
        // For example, setting price data source, configuring oracle, etc.
        
        // Decode symbol from ruleData
        (string memory symbol, , ) = _decodeRuleData(params.ruleData);
        
        // Use decoded symbol to initialize price oracle
        PriceMarket(marketAddress).initPriceFeed(symbol);
    }
    

    /**
     * @dev from ruleData decode symbol
     * @param ruleData rule data
     * @return symbol symbol
     */
    function _decodeRuleData(bytes memory ruleData) internal pure returns (string memory, string memory, string memory) {
        require(ruleData.length > 0, "Invalid rule data");
        
        // Decode the rule data to get the symbol
       (string memory symbol, , , string memory optionNameIfTrue, string memory optionNameIfFalse) = abi.decode(ruleData, (string, uint8, uint256, string, string));
        
        return (symbol, optionNameIfTrue, optionNameIfFalse);
    }
}