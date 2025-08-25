// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/ITokenFactory.sol";
import "./interface/IMarket.sol";
import "./config/WhiteListConfig.sol";

import "./market/handler/BaseMarketHandler.sol";

contract MarketFactory is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    ITokenFactory private immutable tokenFactory;
    address private immutable config;
    
    // Payment token address
    address public paymentToken;
    
    // Switch to control market creation
    bool public marketEnable = false;
    // Mapping to track whitelisted addresses
    mapping(address => bool) public wlCreator;
    
    // Market implementation registry - once set, cannot be changed
    mapping(uint8 => address) public marketImplementations;
    // Market handler registry - once set, cannot be changed
    mapping(uint8 => address) public marketHandlers;
    // Market type names for events and display
    mapping(uint8 => string) public marketTypeNames;
    // Track registered market types
    uint8[] public registeredMarketTypes;
    // Track which market types are enabled
    mapping(uint8 => bool) public marketTypeEnabled;

    // Track which market types are whitelisted
    mapping(uint8 => bool) public marketNeedWhitelist;
    
    WhiteListConfig private wlConfig;
    
    event CreateNewMarket(address indexed market, string title, address creator, uint8 marketType);
    event WhitelistStatusChanged(address indexed user, bool status);

    constructor(address _config,address _tokenFactory) Ownable(msg.sender) {
        config = _config;
        tokenFactory = ITokenFactory(_tokenFactory);    
    }
    
    function setWlConfig(address _wlconfig) external onlyOwner {
        wlConfig = WhiteListConfig(_wlconfig);
    }
    
    /**
     * @dev Set the payment token address
     * @param _paymentToken The address of the ERC20 token to be used for payments
     */
    function setPaymentToken(address _paymentToken) external onlyOwner {
        require(_paymentToken != address(0), "Invalid token address");
        paymentToken = _paymentToken;
    }

    function setMarketTypeWhitelist(uint8 marketType, bool needWhitelist) external onlyOwner {
        marketNeedWhitelist[marketType] = needWhitelist;
    }

    /**
     * @dev Register a new market implementation
     * @param marketType The type ID of the market
     * @param name The name of the market type
     * @param marketImplementation The implementation contract address
     * @param marketHandler The handler contract address
     */

    function registerMarketImplementation(
        uint8 marketType,
        string memory name,
        address marketImplementation,
        address marketHandler
    ) external onlyOwner {
        require(marketImplementation != address(0), "Invalid implementation address");
        require(marketHandler != address(0), "Invalid handler address");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(marketImplementations[marketType] == address(0), "Market type already registered");
        
        marketImplementations[marketType] = marketImplementation;
        marketHandlers[marketType] = marketHandler;
        marketTypeNames[marketType] = name;
        marketTypeEnabled[marketType] = true;
        marketNeedWhitelist[marketType] = true;
        registeredMarketTypes.push(marketType);
    }
    

    function updateMarketImplementation(
        uint8 marketType,
        address marketImplementation,
        address marketHandler
    ) external onlyOwner {
        require(marketImplementation != address(0), "Invalid implementation address");
        require(marketHandler != address(0), "Invalid handler address");
        require(marketImplementations[marketType] != address(0), "Market type not registered");
        marketImplementations[marketType] = marketImplementation;
        marketHandlers[marketType] = marketHandler;
    }
    /**
     * @dev Enable or disable a market type
     * @param marketType The type ID of the market
     * @param enabled Whether the market type should be enabled
     */
    function setMarketTypeEnabled(uint8 marketType, bool enabled) external onlyOwner {
        require(marketImplementations[marketType] != address(0), "Market type not registered");
        marketTypeEnabled[marketType] = enabled;
    }
    
    /**
     * @dev Get all registered market types
     * @return types Array of registered market type IDs
     * @return names Array of market type names
     * @return implementations Array of implementation addresses
     * @return enabled Array indicating if each market type is enabled
     */
    function getRegisteredMarketTypes() external view returns (
        uint8[] memory types,
        string[] memory names,
        address[] memory implementations,
        bool[] memory enabled
    ) {
        uint256 count = registeredMarketTypes.length;
        types = new uint8[](count);
        names = new string[](count);
        implementations = new address[](count);
        enabled = new bool[](count);
        
        for (uint256 i = 0; i < count; i++) {
            uint8 marketType = registeredMarketTypes[i];
            types[i] = marketType;
            names[i] = marketTypeNames[marketType];
            implementations[i] = marketImplementations[marketType];
            enabled[i] = marketTypeEnabled[marketType];
        }
    }
    
    /**
     * @dev Set the market creation switch
     * @param _enabled Whether market creation is enabled for all users
     */
    function setMarketCreationEnabled(bool _enabled) external onlyOwner {
        marketEnable = _enabled;
    }
    
    /**
     * @dev Set the whitelist status for a specific address
     * @param _user Address to update
     * @param _status New whitelist status
     */

    



    /**
     * @dev Create a new market with the specified type and parameters
     * @param marketType The type of market to create
     * @param params Market creation parameters
     * @return _marketAddress The address of the created market
     */
    function createMarket(
        uint8 marketType,
        IMarket.MarketCreationParams memory params,
        address creator,
        uint256 estimatedValue
    ) external nonReentrant returns (address _marketAddress) {
        // basic validation
        if(marketNeedWhitelist[marketType]){
            require(wlConfig.isWhitelisted(creator), "Market creation not allowed: Not whitelisted");
        }
        
        // verify market type is registered and enabled
        address implementation = marketImplementations[marketType];
        require(implementation != address(0), "Market type not registered");
        require(marketTypeEnabled[marketType], "Market type is disabled");
        

        // Use the corresponding type handler for validation
        address handler = marketHandlers[marketType];
        require(handler != address(0), "No handler for market type");
        
        // Validate parameters
        BaseMarketHandler(handler).validateMarketParams(params);
        // clone implementation
        _marketAddress = Clones.clone(implementation);

        _createMarketNft(_marketAddress, params);
        
        // initialize market
        BaseMarketHandler(handler).initializeMarket(_marketAddress, params, paymentToken, creator, config);
        


        if(estimatedValue > 0){

            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), estimatedValue);

            IERC20(paymentToken).approve(address(_marketAddress), estimatedValue);
            // Transfer tokens to the market contract
            initializeShares(_marketAddress, params.shareInitParams,creator);
         
        }
        
        // emit event and return market address
        emit CreateNewMarket(_marketAddress, params.title, creator, marketType);
        return _marketAddress;
    }
    

    function _createMarketNft(address marketAddress, IMarket.MarketCreationParams memory params) private {
        address marketNFT = tokenFactory.createMarketNFT(
            params.title, 
            params.symbol, 
            params.cid, 
            marketAddress
        );
        params.marketNFTAddress = marketNFT;
    }
 

  

    /**
     * @dev Initialize shares for the market
     * @param marketAddress The address of the market
     * @param shareParams Share initialization parameters
     * @return totalValue Total value of initialized shares
     */
    function initializeShares(
        address marketAddress,
        IMarket.ShareInitParams[] memory shareParams,
        address creator
    ) private returns (uint256 totalValue) {
        IMarket market = IMarket(marketAddress);
        uint256 optionIdInit = market.optionIdInit();
        
        for (uint8 i = 0; i < shareParams.length; i++) {
            uint256 buyShares = shareParams[i].initialShare;
            if (buyShares > 0) {
                uint256 amount = market.calculateAmountForShares(i, buyShares);
                uint256 minShare = market.calculateSharesForFixedAmount(i, amount);
                totalValue += amount;
                
                market.buyShares(
                    IMarket.BuySharesParams({
                        optionId: optionIdInit + i,
                        amount: amount,
                        minShare: minShare
                    }),
                    creator
                );
            }
        }
        
        return totalValue;
    }

    /**
     * @dev Withdraw contract balance to owner
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }   
}
