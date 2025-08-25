// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../BaseMarket.sol";

contract CreatorMarket is BaseMarket {

    constructor() BaseMarket() {}

    /**
     * @dev override the resolveMarket function in BaseMarket
     * @param _winningOptionId the ID of the winning option
     */
    function resolveMarket(uint256 _winningOptionId) external nonReentrant {
        // require(block.timestamp >= market.resolveTime && !isResolved, "Market cannot be resolved: Not normal resolve time");
        require(optionIds[_winningOptionId], "Invalid winning option");
        require(!isResolved, "Market already resolved");
        uint256 winner = _winningOptionId;
        // If the market is after the deadline, it is marked as a draw
        if (block.timestamp > market.resolveDeadline) {
            winner = DRAW_OPTIONID;
        } else {
            // Only the resolver can resolve the market before the deadline
            require(msg.sender == market.resolver, "No permission to resolve market before deadline");
            winner = _winningOptionId;
        }

        _resolveMarket(winner);
    }
    
    // /**
    //  * @dev pause the market
    //  */
    // function pause() external {
    //     require(msg.sender == market.creator, "Only creator can pause market");
    //     paused = true;
    // }


    function _decodePriceRule() internal view returns (string memory rule) {
        require(market.ruleData.length > 0, "Invalid rule data");
        rule = abi.decode(market.ruleData, (string));
        return rule;
    }

    function decodePriceRule() external view returns (string memory rule) {
        return _decodePriceRule();
    }
}