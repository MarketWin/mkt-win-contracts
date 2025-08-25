// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMarket {


     struct BuySharesParams {
        uint256 optionId;
        uint256 amount;
        uint256 minShare;
    }

    struct OptionMeta {
        string title;
        uint256 optionId;
    }

    struct MarketMeta {
        string title;
        string symbol;
        uint8 marketType;
        bytes ruleData;
        string tagId;
        address creator;
        address resolver;
        uint256 mintEndTime;
        uint256 resolveTime;
        uint256 resolveDeadline;
    }
    
    // Share initialization parameters
    struct ShareInitParams {
        string title;
        uint256 initialShare;
    }
    
    // Market creation parameters structure
    struct MarketCreationParams {
        // Basic market information
        string title;
        string symbol;
        string tagId;
        bytes ruleData;
        uint256 mintEndTime;
        uint256 resolveTime;
        uint256 resolveDeadline;
        address resolver;
        // Additional fields needed for market creation
        string cid;
        ShareInitParams[] shareInitParams;  // Initial shares configuration
        string[] optionNames;  // Names of options
        address marketNFTAddress;  // Address of the market NFT
    }

    /**
     * @dev Initialize the market with the provided parameters
     * @param params All parameters needed to initialize the market
     * @param creator Address of the market creator
     * @param marketType Type of the market (from MarketType enum)
     */
    function initialize(
        MarketCreationParams calldata params,
        address creator,
        address paymentToken,   
        uint8 marketType,
        address _config
    ) external;


    function buyShares(BuySharesParams memory params,address _reciver) external;

    function claimSingleReward(uint256 _tokenId) external returns (uint256);

    function claimAllRewards() external returns (uint256);

    function winningOption() external view returns (uint256);

    function paymentToken() external view returns (address);

    function isResolved() external view returns (bool);

    function optionIdInit() external view returns (uint256);

    function calculateAmountForShares(uint256 optionId, uint256 shares) external view returns (uint256);
    function calculateSharesForFixedAmount(uint256 optionId, uint256 amount) external view returns (uint256);
}
