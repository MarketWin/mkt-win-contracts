// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenFactory {

    function createMarketNFT(string memory name, string memory symbol, string memory cid, address market) external returns (address);
}