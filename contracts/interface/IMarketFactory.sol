// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IMarket.sol";

interface IMarketFactory {

    function paymentToken() external view returns (address);

    function createMarket(
        uint8 marketType,
        IMarket.MarketCreationParams memory params,
        address creator,
        uint256 estimatedValue
    ) external  returns (address _marketAddress);
}