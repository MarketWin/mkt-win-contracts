// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import  "../interface/IMarketNFT.sol";

contract MarketNFT is ERC721Enumerable {
 

    address public market;  
    mapping(uint256 => IMarketNFT.NFTMetadata) private _tokenMetadata;

    string public cid;

    constructor(string memory name, string memory symbol, string memory _cid, address _market) ERC721(name, symbol) {
        market = _market;
        cid = _cid;
    }


    modifier onlyMarket() {
        require(msg.sender == market, "Only market can call this function");
        _;
    }

    function setCid(string memory _cid) external {
        cid = _cid;
    }

    function mint(address to, uint256 tokenId, uint256 optionId, uint256 paidAmount, uint256 shares) external onlyMarket {
        _safeMint(to, tokenId);
        _tokenMetadata[tokenId] = IMarketNFT.NFTMetadata(optionId, paidAmount, shares,false);
    }

    function burn(uint256 tokenId) external onlyMarket {
        _tokenMetadata[tokenId].isBurned = true;
    }

    function getTokenMetadata(uint256 tokenId) external view returns (IMarketNFT.NFTMetadata memory) {
        
        require(_tokenMetadata[tokenId].principal != 0, "Token does not exist");
        
        IMarketNFT.NFTMetadata memory metadata = _tokenMetadata[tokenId];
        return metadata;
    }

  


}