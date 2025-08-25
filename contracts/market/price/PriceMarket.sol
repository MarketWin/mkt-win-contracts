// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../BaseMarket.sol";
import "../../config/Config.sol";

contract PriceMarket is BaseMarket {
    using SafeERC20 for IERC20;

    // price conditions
    mapping(uint8 => string) private conditions;
   
    
    // Chainlink price feed interface
    AggregatorV3Interface private priceFeed;
    
    // store the final price
    uint256 public finalPrice;
    uint256 public finalTime;
    bool public priceFinalized;

    // price forecast event
    event PriceFinalized(uint256 price, uint256 timestamp);
    event OracleAddressSet(address oracleAddress, string assetSymbol);
    event MarketResolvedWithPrice(address indexed market, uint256 winningOptionId, uint256 price);

    // Structure to define a price rule
    struct PriceRule {
        string symbol;
        uint8 conditionType;    // 0=equal, 1=greater than, 2=less than, 3=greater than or equal, 4=less than or equal
        uint256 targetPrice;    // The price threshold to compare against
        string optionNameIfTrue; // The option name that wins if the condition is met
        string optionNameIfFalse; // The option name that wins if the condition is not met
    }

    constructor() BaseMarket() {
        // initialize conditions
    }

    /**
     * @dev set price feed address
     * @param symbol currency pair symbol
     */
    function initPriceFeed(string calldata symbol) external{
        require(address(priceFeed) == address(0), "Price feed already set");
        Config config = Config(configAddress);

        address priceFeedAddress = config.getPriceFeed(symbol);
        require(priceFeedAddress != address(0), "Price feed not configured for this symbol");
        priceFeed = AggregatorV3Interface(priceFeedAddress);
        emit OracleAddressSet(address(priceFeed), symbol);
    }

    /**
     * @dev override the resolveMarket function in BaseMarket
     */
    function resolveMarket() external nonReentrant {
        (uint256 currentPrice, uint256 timeStamp) = getLatestPrice();
        
        (bool resolvable, uint256 winner, string memory errorMessage) = _checkMarketResolution(currentPrice);
        
        require(resolvable, errorMessage);

        _resolveMarket(winner);
        uint256 maxResolveFee = 20 * 10**18;

        // Set the final price
        finalPrice = currentPrice;
        finalTime = timeStamp;
        priceFinalized = true;

        Config config = Config(configAddress);
        address treasury_address = config.feeAddress();

        // Reward the resolver with a portion of the resolve fee
        if (resolveFee > 0 && address(paymentToken) != address(0)) {
            uint256 tokenMaxResolveFee = maxResolveFee;

            if (resolveFee > tokenMaxResolveFee) {
                IERC20(paymentToken).safeTransfer(msg.sender, tokenMaxResolveFee);
                IERC20(paymentToken).safeTransfer(treasury_address, resolveFee - tokenMaxResolveFee);
            } else {
                IERC20(paymentToken).safeTransfer(msg.sender, resolveFee);
            }
        }
    }

    function _checkBeforBuy(BuySharesParams memory params,address _receiver)  internal view override {
        (uint256 currentPrice, uint256 timeStamp) = _getLatestPrice();

        PriceRule memory rule = _decodePriceRule();
        // Calculate 1% of the target price
        uint256 onePctOfTarget = rule.targetPrice / 100;
        // Calculate the absolute difference between current price and target price
        uint256 priceDiff;
        if (currentPrice > rule.targetPrice) {
            priceDiff = currentPrice - rule.targetPrice;
        } else {
            priceDiff = rule.targetPrice - currentPrice;
        }
        // Check if the price difference is less than 1% of the target price
        require(priceDiff >= onePctOfTarget, "it's not allowed to bet when the oracle price is 1% near the prediction price, this is designed to protect earlier bettors");
    }

    // ****** internal function ****** //

    /**
     * @dev Decode the rule data to get the price rule
     * @return rule The price rule decoded from market.ruleData
     */
    function _decodePriceRule() internal view returns (PriceRule memory rule) {
        // decode the rule data
        (string memory symbol, uint8 conditionType, uint256 targetPrice, string memory optionNameIfTrue, string memory optionNameIfFalse) =
            abi.decode(market.ruleData, (string, uint8, uint256, string, string));

        // construct and return PriceRule structure
        return PriceRule({
            symbol: symbol,
            conditionType: conditionType,
            targetPrice: targetPrice,
            optionNameIfTrue: optionNameIfTrue,
            optionNameIfFalse: optionNameIfFalse
        });
    }

    /**
     * @dev Internal function to check if the market can be resolved and determine the winning option
     * @param currentPrice The current price to check against the rule
     * @return resolvable Whether the market can be resolved
     * @return winningOptionId The ID of the winning option if resolved
     * @return errorMessage Error message if market cannot be resolved
     */
    function _checkMarketResolution(uint256 currentPrice) internal view returns (
        bool resolvable,
        uint256 winningOptionId,
        string memory errorMessage
    ) {
        if (isResolved) {
            return (false, 0, "Market already resolved");
        }

        if (address(priceFeed) == address(0)) {
            return (false, 0, "Price feed not set");
        }

        if (block.timestamp < market.resolveTime) {
            return (false, 0, "Not yet resolve time");
        }

        // Decode the price rule
        PriceRule memory rule = _decodePriceRule();

        // Determine if the market can be resolved based on the price condition and time
        if (block.timestamp <= market.resolveDeadline) {
            // Before or at deadline: only resolve if True condition is met
            if (_isPriceConditionMet(rule, currentPrice)) {
                uint256 trueOptionId = _findOptionIdByName(rule.optionNameIfTrue);
                require(trueOptionId > 0, "Option name not found");
                return (true, trueOptionId, "");
            } else {
                return (false, 0, "Price condition not met");
            }
        } else {
            // After deadline: market can be resolved with False option as winner
            uint256 falseOptionId = _findOptionIdByName(rule.optionNameIfFalse);
            require(falseOptionId > 0, "Option name not found");
            return (true, falseOptionId, "");
        }
    }

    /**
     * @dev Check if the price condition is met
     * @param rule The price rule to check
     * @param currentPrice The current price to check against
     * @return true if the condition is met, false otherwise
     */
    function _isPriceConditionMet(PriceRule memory rule, uint256 currentPrice) internal pure returns (bool) {
        if (rule.conditionType == 1) {
            return currentPrice > rule.targetPrice;  // Greater than
        } else if (rule.conditionType == 2) {
            return currentPrice < rule.targetPrice;  // Less than
        }

        return false;
    }

    /**
     * @dev Find the option ID by its name
     * @param optionName The name of the option to find
     * @return The ID of the option, or 0 if not found
     */
    function _findOptionIdByName(string memory optionName) internal view returns (uint256) {
        for (uint256 i = 0; i < options.length; i++) {
            if (keccak256(bytes(options[i].title)) == keccak256(bytes(optionName))) {
                return options[i].optionId;
            }
        }
        return 0; // Return 0 if not found
    }

    function _getLatestPrice() internal view returns (uint256, uint256) {
        require(address(priceFeed) != address(0), "Price feed not set");

        (
            /* uint80 roundID */,
            int256 price,
            /* uint startedAt */,
            uint256 timeStamp,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();
        return(uint256(price), timeStamp);
    }

    /**==== view function */

    function getLatestPrice() public view returns (uint256, uint256) {
        return _getLatestPrice();
    }

    function decodePriceRule() external view returns (PriceRule memory rule) {
        return _decodePriceRule();
    }

    /**
     * @dev Check if the market can be resolved without actually resolving it
     * @return canResolve Whether the market can be resolved
     * @return winningOptionId The ID of the winning option if resolved
     * @return reason A message explaining why the market can or cannot be resolved
     */
    function canResolveMarket() external view returns (bool canResolve, uint256 winningOptionId, string memory reason) {
        uint256 currentPrice;
        try this.getLatestPrice() returns (uint256 price, uint256 timeStamp) {
            currentPrice = price;
        } catch {
            return (false, 0, "Failed to get latest price");
        }

        (bool resolvable, uint256 winner, string memory errorMessage) = _checkMarketResolution(currentPrice);

        if (resolvable) {
            return (true, winner, block.timestamp <= market.resolveDeadline ? "Price condition met" : "Resolve deadline passed");
        } else {
            return (false, 0, errorMessage);
        }
    }
}