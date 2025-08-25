// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IMarketNFT {



   struct NFTMetadata {
        uint256 optionId;
        uint256 principal;
        uint256 shares;
        bool isBurned;
    }

    function mint(address to, uint256 tokenId, uint256 optionId, uint256 paidAmount,uint256 shares) external;
    function burn(uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function tokenOfOwnerByIndex(address account, uint256 index) external view returns (uint256);
    function getTokenMetadata(uint256 tokenId) external view returns (NFTMetadata memory);  
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function market() external view returns (address);
}
