// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Config  is Ownable{

    // Pair feed structure to represent supported currency pairs
    struct PairFeed {
        string symbol;       // Pair symbol (e.g., "ETH/USDT")
        address priceFeed;   // Chainlink price feed address for this pair
    }

    struct ConfigData {
        uint256 platformFee;
        uint256 creatorFee;
        uint256 drawFee;
        uint256 platformBuyFee;
        uint256 creatorBuyFee;
        address feeAddress;
        uint256 initPrice;
        uint256 priceInterval;
        uint256 priceGrowthRate;
        uint256 priceGrowthRateDenominator;
        uint256 denominator;
    }
    // -- fee config -- //
    uint256 public  PLATFORM_FEE = 50;
    uint256 public  CREATOR_FEE = 50;
    uint256 public  DENOMINATOR = 1000;
    uint256 public  DRAW_FEE = 50;
    uint256 public  PLATFORM_BUY_FEE = 5;
    uint256 public  CREATOR_BUY_FEE =5;
    uint256 public  PLATFORM_NFT_FEE = 10;
    uint256 public  CREATOR_NFT_FEE = 10;
    address public  feeAddress;
    uint256 public  AUTO_RESOLVE_FEE = 1;

    // -- pair feeds config -- //
    mapping(string => PairFeed) public pairFeeds;     // Mapping from symbol to pair feed
    string[] public supportedPairs;                   // List of all supported pair symbols
    mapping(string => bool) private pairExists;       // To check if a pair exists

    // -- contract config -- //
   
    //-- price config -- //
    uint256 public  INIT_PRICE = 1e15;
    uint256 public  PRICE_INTERVAL = 100 * 1e18;
    uint256 public  PRICE_GROWTH_RATE = 65;
    uint256 public  PRICE_GROWTH_RATE_DENOMINATOR = 1000;

    

    constructor() Ownable(msg.sender) {}


    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }


    // ------  fee Config  setting------ //

    function setFeeAddress(address _feeAddress) external onlyOwner {
        feeAddress = _feeAddress;
    }

     function setDrawFee(uint256 _drawFee) external onlyOwner {
        DRAW_FEE = _drawFee;
    }

    function setRewardFee(uint256 _platformRewardFee, uint256 _creatorRewardFee) external onlyOwner {
        require(_platformRewardFee + _creatorRewardFee <= 200, "Reward fees exceed denominator");
        if (_platformRewardFee > 0) {
            PLATFORM_FEE = _platformRewardFee;
        }
        if (_creatorRewardFee > 0) {
            CREATOR_FEE = _creatorRewardFee;
        }
    }

     function setBuyFee(uint256 _platformBuyFee, uint256 _creatorBuyFee) external onlyOwner {
        require(_platformBuyFee + _creatorBuyFee <= 20, "Buy fees exceed denominator");
        if (_platformBuyFee > 0) {
            PLATFORM_BUY_FEE = _platformBuyFee;
        }
        if (_creatorBuyFee > 0) {
            CREATOR_BUY_FEE = _creatorBuyFee;
        }
    }

    function setNftFee(uint256 _platformNFTFee, uint256 _creatorNFTFee) external onlyOwner(){
        require(_platformNFTFee + _creatorNFTFee <= 30, "NFT fees exceed denominator");
        if (_platformNFTFee > 0) {
            PLATFORM_NFT_FEE = _platformNFTFee;
        }
        if (_creatorNFTFee > 0) {
            CREATOR_NFT_FEE = _creatorNFTFee;
        }
    }

    function setAutoResolveFee(uint256 _autoResolveFee) external onlyOwner {
        require(_autoResolveFee <= 5, "Auto resolve fee exceeds denominator");
        AUTO_RESOLVE_FEE = _autoResolveFee;
    }
 
    // ------  price Config  setting------ //

    function setInitPrice(uint256 _initPrice) external onlyOwner {
        INIT_PRICE = _initPrice;
    }

    function setPriceInterval(uint256 _priceInterval) external onlyOwner {
        PRICE_INTERVAL = _priceInterval;
    }

    function setPriceGrowthRate(uint256 _priceGrowthRate) external onlyOwner {
        PRICE_GROWTH_RATE = _priceGrowthRate;
    }
    
    function setPriceGrowthRateDenominator(uint256 _priceGrowthRateDenominator) external onlyOwner {
        PRICE_GROWTH_RATE_DENOMINATOR = _priceGrowthRateDenominator;
    }

    // ------ Pair Feeds Config ------ //
    
    /**
     * @dev Add a new supported pair
     * @param symbol The pair symbol (e.g., "ETH/USDT")
     * @param priceFeed The Chainlink price feed address
     */
    function addPair(
        string calldata symbol, 
        address priceFeed
    ) external onlyOwner {
        require(!pairExists[symbol], "Pair already exists");
        require(priceFeed != address(0), "Invalid price feed address");
        
        pairFeeds[symbol] = PairFeed({
            symbol: symbol,
            priceFeed: priceFeed
        });
        
        supportedPairs.push(symbol);
        pairExists[symbol] = true;
    }        

    
    /**
     * @dev Remove a pair from the supported list
     * @param symbol The pair symbol to remove
     */
    function removePair(string calldata symbol) external onlyOwner {
        require(pairExists[symbol], "Pair does not exist");
        
        // Find the index of the pair in the supportedPairs array
        uint256 pairIndex;
        bool found = false;
        
        for (uint256 i = 0; i < supportedPairs.length; i++) {
            if (keccak256(bytes(supportedPairs[i])) == keccak256(bytes(symbol))) {
                pairIndex = i;
                found = true;
                break;
            }
        }
        
        require(found, "Pair not found in array");
        
        // Remove the pair by swapping with the last element and popping
        if (pairIndex < supportedPairs.length - 1) {
            supportedPairs[pairIndex] = supportedPairs[supportedPairs.length - 1];
        }
        supportedPairs.pop();
        
        // Remove from mapping
        delete pairFeeds[symbol];
        pairExists[symbol] = false;
    }
    
    /**
     * @dev Get all supported pairs
     * @return Array of all supported pair symbols
     */
    function getAllPairs() external view returns (string[] memory) {
        return supportedPairs;
    }
    

    /**
     * @dev Get the price feed address for a specific pair
     * @param symbol The pair symbol
     * @return The Chainlink price feed address
     */
    function getPriceFeed(string calldata symbol) external view returns (address) {
        require(pairExists[symbol], "Pair does not exist");
        return pairFeeds[symbol].priceFeed;
    }
  
}