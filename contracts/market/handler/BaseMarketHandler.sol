// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../../interface/IMarket.sol";

abstract contract BaseMarketHandler {
    address public immutable config;
    
    constructor(address _config) {
        config = _config;
    }
    
    /**
     * @dev Validate market creation parameters
     */
    function validateMarketParams(IMarket.MarketCreationParams calldata params) public view virtual {
        // Shared basic validation
        require(params.shareInitParams.length >= 2 && params.shareInitParams.length <= 4, "Invalid option count");
        require(params.mintEndTime > block.timestamp, "Invalid mint end time"); 
        // Call the specific validation hook of the subclass
        _additionalValidation(params);
    }
    
    /**
     * @dev Initialize market - Contains shared initialization logic for all market types
     */
    function initializeMarket(
        address marketAddress,
        IMarket.MarketCreationParams memory params,
        address paymentToken,
        address creator,
        address _config
    ) public virtual {
        
        // prepare option names if not already set
        if (params.optionNames.length == 0 && params.shareInitParams.length > 0) {
            string[] memory optionNames = new string[](params.shareInitParams.length);
            for(uint8 i = 0; i < params.shareInitParams.length; i++){
                optionNames[i] = params.shareInitParams[i].title;
            }
            params.optionNames = optionNames;
        }
        uint8 marketType = getMarketType();
        // initialize market
        IMarket market = IMarket(marketAddress);
        market.initialize(
            params,
            creator,
            paymentToken,
            marketType,
            _config
        );
        
        // Call the specific initialization hook of the subclass
        _afterInitialize(marketAddress, params);
    }

    
    /**
     * @dev Get market type ID - Must be implemented by subclass
     */
    function getMarketType() public pure virtual returns (uint8);
    
    /**
     * @dev Additional validation hook for specific market types - Optional override by subclass
     */
    function _additionalValidation(IMarket.MarketCreationParams calldata params) internal view virtual {
        // Default empty implementation, subclass can override
    }
    

 
    
    /**
     * @dev after initialize hook - must be implemented by subclass
     */
    function _afterInitialize(
        address marketAddress,
        IMarket.MarketCreationParams memory params
    ) internal virtual {
        // Default empty implementation, subclass can override
    }
}