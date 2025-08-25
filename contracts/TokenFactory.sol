// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./invoice/MarketNFT.sol";

contract TokenFactory {


    function createMarketNFT(string memory name, string memory symbol, string memory cid, address market) external returns (address) {
        return address(new MarketNFT(name, symbol, cid, market));
    }
}