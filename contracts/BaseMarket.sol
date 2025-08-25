// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/IMarketNFT.sol";
import "./interface/IShareToken.sol";
import "./interface/IMarket.sol";
import "./config/Config.sol";
import "./libraries/PriceLib.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
abstract contract BaseMarket is IMarket, ReentrancyGuard {
    using SafeERC20 for IERC20;

    Config.ConfigData public config;
    address public configAddress;
    // ------ Market properties ------ //
    MarketMeta public market;
    bool public isResolved;

    uint256 private constant EMPTY_OPTIONID = 999999;
    uint256 public constant optionIdInit = 100;

    uint256 private  winningOptionId;

    IMarketNFT public optionNFT;


    address public paymentToken;

    OptionMeta[] public options;
    
    mapping(uint256 => uint256) public optionShares;
    mapping(uint256 => uint256) public optionPrice;
    mapping(uint256 => uint256) public optionPaidAmount;  
    mapping(uint256 => bool) public optionIds;

    
    uint256 public allPaidAmount;
    uint256 public _tokenIdCounter;
    uint256 public resolveFee;
    uint256 internal constant DRAW_OPTIONID = 1e18;
    bool private isInitialized;
    bool public paused;
    
    
    event SharesPurchased(uint256 indexed optionId, address indexed buyer, uint256 shares, uint256 amount,uint256 tokenId);
    event MarketResolved(address indexed market, uint256 winningOptionId);
    event RewardClaimed(address indexed market, address indexed user, uint256 tokenId,uint256 reward);
    event RewardAllClaimed(address indexed market, address indexed user, uint256[] tokenId,uint256 reward);
    

    constructor() {
    }


    function initialize(
        IMarket.MarketCreationParams calldata params,
        address _creator,
        address _paymentToken,
        uint8 _marketType,
        address _config
    ) external  {
        require(!isInitialized, "Already initialized");
        Config configCa = Config(_config);
        configAddress = _config;
        config = Config.ConfigData({
            platformFee: configCa.PLATFORM_FEE(),
            creatorFee: configCa.CREATOR_FEE(),
            drawFee: configCa.DRAW_FEE(),
            platformBuyFee: configCa.PLATFORM_BUY_FEE(),
            creatorBuyFee: configCa.CREATOR_BUY_FEE(),
            feeAddress: configCa.feeAddress(),
            initPrice: configCa.INIT_PRICE(),
            priceInterval: configCa.PRICE_INTERVAL(),
            priceGrowthRate: configCa.PRICE_GROWTH_RATE(),
            priceGrowthRateDenominator: configCa.PRICE_GROWTH_RATE_DENOMINATOR(),
            denominator: configCa.DENOMINATOR()
          });
        uint256 _finalResolveTime = params.resolveTime == 0 ? params.mintEndTime : params.resolveTime;
        market = MarketMeta({
            title: params.title,
            symbol: params.symbol,
            marketType: _marketType,
            ruleData: params.ruleData,
            tagId: params.tagId,
            creator: _creator,
            resolver: params.resolver == address(0) ? msg.sender : params.resolver,
            mintEndTime: params.mintEndTime,
            resolveTime: _finalResolveTime,
            resolveDeadline: params.resolveDeadline == 0 ? _finalResolveTime + 30 days : params.resolveDeadline 
        });
           
        
        for (uint8 i = 0; i < params.optionNames.length; i++) {
            options.push(OptionMeta({
                title: params.optionNames[i],
                optionId: optionIdInit + i
            }));
            optionIds[options[i].optionId] = true;
        }
        
        optionNFT = IMarketNFT(params.marketNFTAddress);
        paymentToken = _paymentToken;
        winningOptionId = EMPTY_OPTIONID;
        isInitialized = true;
    }

    // ------ Market config ------ //
    /*
        @dev this function is used to resolve the market and set the winning option
        @param _winningOptionId the ID of the winning option 
        winningOption must be in the options array
        if _winningOptionId is DRAW_ADDRESS, it means the market is a draw
     */

    function _resolveMarket(uint256 _winningOptionId) internal{
        require(optionIds[_winningOptionId] , "invalid winning option");
        winningOptionId = _winningOptionId;
        isResolved = true;
        emit MarketResolved(address(this), winningOptionId);
    } 
    // function resolveMarket(uint256 _winningOptionId) external nonReentrant {
    //     require(block.timestamp >= market.resolveTime && !isResolved, "Market cannot be resolved: Not  normal resolve");

    //     require(optionIds[_winningOptionId] , "invalid winning option");
    //     if(block.timestamp > market.resolveDeadline){
    //         _winningOptionId = DRAW_OPTIONID;
    //     } else {
    //         require(msg.sender == market.resolver, "no permission to resolve market before deadline");
    //     }

    //     // set winning option   
    //     winningOptionId = _winningOptionId;
    //     isResolved = true;
    //     emit MarketResolved(address(this), _winningOptionId);
    // }

    
    


    modifier resolved (){
        require(isResolved, "market is not resolved");
        _;
    }





    // ---- market trade functions ---- //


    /**
     * @dev override the _checkBeforBuy function in BaseMarket  
     * default empty implementation,if there is a need to check before buy, override this function 
     */
    function _checkBeforBuy(BuySharesParams memory params,address _receiver)  internal view virtual {

    }
   
    function buyShares(BuySharesParams memory params,address _receiver) external nonReentrant {
        require(!isResolved, "market is resolved");
        require(block.timestamp < market.mintEndTime, "mint time is over, you can't buy shares anymore");
        require(optionIds[params.optionId] , "option is not allowed"); 
       
        require(!paused, "market is paused");
        _checkBeforBuy(params,_receiver);
        // Transfer tokens from sender to this contract
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), params.amount);

        uint256 platformFee = (params.amount * config.platformBuyFee) / config.denominator;
        uint256 creatorFee = (params.amount * config.creatorBuyFee) / config.denominator;
        uint256 totalFee = platformFee + creatorFee;
        uint256 baseAmount = params.amount - totalFee;

        if (market.marketType == 1) {
            resolveFee += platformFee * 5 / 10000 + creatorFee * 5 / 10000;
            platformFee = platformFee - platformFee * 5 / 10000;
            creatorFee = creatorFee - creatorFee * 5 / 10000;
        }

        // Transfer fees
        IERC20(paymentToken).safeTransfer(config.feeAddress, platformFee);
        IERC20(paymentToken).safeTransfer(market.creator, creatorFee);

        uint256 currentShares = optionShares[params.optionId];
        (uint256 sharesBought,uint256 currentPrice) = PriceLib.calculateSharesForFixedAmount(currentShares, baseAmount, config);

        require(sharesBought >= params.minShare, "Shares bought less than minimum");

        optionNFT.mint(_receiver,_tokenIdCounter, params.optionId, baseAmount,sharesBought);
        
        // Update state variables
        uint256  tokenId = _tokenIdCounter;
        optionPaidAmount[params.optionId] += baseAmount;
        optionShares[params.optionId] += sharesBought;
        _tokenIdCounter++;
        allPaidAmount += baseAmount;
        optionPrice[params.optionId] = currentPrice;
        
     
        emit SharesPurchased(params.optionId, _receiver, sharesBought, baseAmount,tokenId);
    }


    function claimSingleReward(uint256 _tokenId) external nonReentrant resolved returns (uint256) {
        require(optionNFT.ownerOf(_tokenId) == msg.sender, "Not the owner of this token");
        IMarketNFT.NFTMetadata memory metadata = optionNFT.getTokenMetadata(_tokenId);
        require(!metadata.isBurned && (winningOptionId == DRAW_OPTIONID || winningOptionId == metadata.optionId), "Token is not eligible for withdrawal");

        uint256 userShares = metadata.shares;

        uint256 reward = _calculateReward(metadata.optionId, userShares);
        uint256 principal = metadata.principal;

        optionNFT.burn(_tokenId);

        uint256 finalReward = _distributeReward(reward,principal);

        emit RewardClaimed(address(this), msg.sender, _tokenId,finalReward);
        
        return finalReward;
    }


    function _calculateReward(uint256 _winOption, uint256 userShares) private view returns (uint256) {
       
        uint256 totalShares = optionShares[_winOption];
        uint256 pot = optionPaidAmount[_winOption];
        uint256 rewardPool = allPaidAmount - pot;
        return (rewardPool * userShares) / totalShares;
    }

    /*
        @dev this function is used to distribute the reward to the user
        fee is deducted from the reward
        @param reward the reward to distribute
        @param userShares the shares of the user
    */
    function _distributeReward(uint256 reward,uint256 principal) private returns (uint256)  {
        if(reward != 0){
            uint256 platformFeeAmount = (reward * config.platformFee) / config.denominator;
            uint256 creatorFeeAmount = (reward * config.creatorFee) / config.denominator;
            reward -= (platformFeeAmount + creatorFeeAmount);
            
            // Transfer fees
            IERC20(paymentToken).safeTransfer(config.feeAddress, platformFeeAmount);
            IERC20(paymentToken).safeTransfer(market.creator, creatorFeeAmount);
        }
       
        // if the market is a draw, the user paid a draw fee
        if(winningOptionId== DRAW_OPTIONID){
            uint256 drawFee = (principal * config.drawFee) / config.denominator;
            IERC20(paymentToken).safeTransfer(config.feeAddress, drawFee);
            principal -= drawFee;
        }

        uint256 finalReward = reward + principal;    
        IERC20(paymentToken).safeTransfer(msg.sender, finalReward);

        return finalReward;
    }


    function claimAllRewards() external  nonReentrant resolved returns (uint256) {

        uint256 nftBalance = optionNFT.balanceOf(msg.sender);
        require(nftBalance > 0, "no eligible shares to claim from");
        uint256 totalShares = 0;
        uint256 totalPrincipal = 0;
        uint256 reward = 0;
        uint256[] memory tokenIds = new uint256[](nftBalance);
        for (uint256 i = nftBalance; i > 0; i--) {
            uint256 _tokenId = optionNFT.tokenOfOwnerByIndex(msg.sender, i - 1);
            IMarketNFT.NFTMetadata memory metadata = optionNFT.getTokenMetadata(_tokenId);
            if(metadata.isBurned || (winningOptionId != metadata.optionId && winningOptionId != DRAW_OPTIONID)){
                continue;
            }

            totalShares += metadata.shares;
            totalPrincipal += metadata.principal;
            optionNFT.burn(_tokenId);
            tokenIds[i - 1] = _tokenId;
        }

        require(totalShares > 0, "no eligible shares to claim from");
        
        if(winningOptionId != DRAW_OPTIONID){
             reward = _calculateReward(winningOptionId, totalShares);
        }
        uint256 finalReward = _distributeReward(reward, totalPrincipal);

        emit RewardAllClaimed(address(this), msg.sender, tokenIds, finalReward);

        return finalReward;
    }    



    

   
    // ------ Market view functions ------ //


    function calculateAmountForShares(uint256 _optionId, uint256 _shares) external view returns (uint256) {
        uint256 currentShares = optionShares[_optionId];
        uint256 baseAmount = PriceLib.calculateAmountForShares(currentShares, _shares, config);
        uint256 totalAmount = baseAmount * config.denominator / (config.denominator - (config.platformBuyFee + config.creatorBuyFee) );
        return totalAmount;
    }

    function calculateSharesForFixedAmount(uint256 _optionId, uint256 amount) external view returns (uint256) {
        uint256 currentShares = optionShares[_optionId];
        uint256 baseAmount = amount - (amount * (config.platformBuyFee + config.creatorBuyFee)) / config.denominator;
        (uint256 sharesBought,) = PriceLib.calculateSharesForFixedAmount(currentShares, baseAmount, config);
        return sharesBought;
    }

    function winningOption() external view returns (uint256) {
        return winningOptionId;
    }
    
}
