// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interface/IMarketNFT.sol";
import "../interface/IMarket.sol";
import "../config/Config.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SimpleNFTMarketplace is Ownable ,IERC721Receiver ,ReentrancyGuard{

    struct Listing {
        uint256 id;
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
    }

    struct Offer {
        uint256 id;
        address buyer;
        uint256 price;
    }

    Config public config;

    uint256 private offerCounter;
    uint256 private listingCounter;
    uint256 private constant EMPTY_OPTIONID = 999999;
    // nftContract => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) public listings;
    // nftContract => tokenId => offerId => Offer
    mapping(address => mapping(uint256 => mapping(uint256 => Offer) )) public offers;
    // nftContract => tokenId => offerIds
    mapping(address => mapping(uint256 => uint256[])) public offerIds;

    event NFTListed(address indexed seller, address indexed nftContract, uint256 indexed tokenId, uint256 price,uint256 listingId);
    event NFTListingCancelled(address indexed seller, address indexed nftContract, uint256 indexed tokenId,uint256 listingId);
    event NFTPurchased(address indexed buyer, address  seller, address indexed nftContract, uint256 indexed tokenId, uint256 price,uint256 listingId);
    event OfferMade(address indexed buyer, address indexed nftContract, uint256 indexed tokenId, uint256 price,uint256 offerId,uint256 listingId);
    event OfferCancelled(address indexed buyer, address indexed nftContract, uint256 indexed tokenId, uint256 price,uint256 offerId,uint256 listingId);
    event OfferAccepted(address indexed seller, address indexed buyer, address indexed nftContract, uint256 tokenId, uint256 price,uint256 offerId,uint256 listingId);

    constructor(address _config) Ownable(msg.sender) {
        config = Config(_config);
    }


    function _checkMarketIsResolved(address nftContract) internal view {
        IMarketNFT nft = IMarketNFT(nftContract);
        IMarket market = IMarket(nft.market());
        require(!market.isResolved(), "Market is already resolved");
    }

    function listNFT(address nftContract, uint256 tokenId, uint256 price) external nonReentrant {
        IMarketNFT nft = IMarketNFT(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "You are not the owner of this NFT");

       _checkMarketIsResolved(nftContract);
        
        // Transfer NFT to marketplace contract
        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        uint256 listingId = listingCounter++;
        listings[nftContract][tokenId] = Listing(listingId, msg.sender, nftContract, tokenId, price);
        emit NFTListed(msg.sender, nftContract, tokenId, price,listingId);
    }

    function cancelListing(address nftContract, uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.seller == msg.sender, "Only the seller can cancel the listing");
        
        delete listings[nftContract][tokenId];

        _cancelAllOffers(nftContract, tokenId);
        // Transfer NFT back to seller
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        emit NFTListingCancelled(msg.sender, nftContract, tokenId,listing.id);
    }

    function buyNFT(address nftContract, uint256 tokenId) external payable nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];

        require(listing.price > 0, "NFT not listed for sale");
        require(msg.value >= listing.price, "Insufficient payment");

        _checkMarketIsResolved(nftContract);
        
        delete listings[nftContract][tokenId];

        _cancelAllOffers(nftContract, tokenId);
        _transferNFTAndFunds(nftContract, tokenId, listing.seller, msg.sender, listing.price);
        emit NFTPurchased(msg.sender, listing.seller, nftContract, tokenId, listing.price,listing.id);
    }

    function makeOffer(address nftContract, uint256 tokenId) external payable nonReentrant {
        require(msg.value > 0, "Offer price must be greater than zero");
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.price > 0, "NFT not listed for sale");
        _checkMarketIsResolved(nftContract);

        uint256 offerId = offerCounter ++;
        Offer memory offer = Offer(offerId, msg.sender, msg.value); 
        offers[nftContract][tokenId][offerId] = offer;
        offerIds[nftContract][tokenId].push(offerId);
        emit OfferMade(msg.sender, nftContract, tokenId, msg.value, offerId,listing.id);
    }

    function cancelOffer(address nftContract, uint256 tokenId, uint256 offerId) external nonReentrant {
        Offer memory offer = offers[nftContract][tokenId][offerId];
        require(offer.buyer == msg.sender, "Only the buyer can cancel the offer");

        delete offers[nftContract][tokenId][offerId];
        _removeOfferId(nftContract, tokenId, offerId);
        payable(offer.buyer).transfer(offer.price);

        Listing memory listing = listings[nftContract][tokenId];
        emit OfferCancelled(msg.sender, nftContract, tokenId, offer.price, offerId,listing.id);
    }

    function acceptOffer(address nftContract, uint256 tokenId, uint256 offerId) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.seller == msg.sender, "Only the seller can accept offers");
        
        _checkMarketIsResolved(nftContract);    

        Offer memory offer = offers[nftContract][tokenId][offerId];
        delete listings[nftContract][tokenId];
        delete offers[nftContract][tokenId][offerId];
        _removeOfferId(nftContract, tokenId, offerId);

        _cancelAllOffers(nftContract, tokenId);
        _transferNFTAndFunds(nftContract, tokenId, listing.seller, offer.buyer, offer.price);
        
        emit OfferAccepted(msg.sender, offer.buyer, nftContract, tokenId, offer.price,offerId,listing.id);
    }

    function _transferNFTAndFunds(address nftContract, uint256 tokenId, address seller, address buyer, uint256 price) private {
        // Transfer NFT from marketplace to buyer
        IMarketNFT(nftContract).safeTransferFrom(address(this), buyer, tokenId);

        // Calculate fee and transfer funds
        uint256 platformFee = price * config.PLATFORM_NFT_FEE() / config.DENOMINATOR();
        uint256 creatorFee = price * config.CREATOR_NFT_FEE() / config.DENOMINATOR();
        uint256 sellerAmount = price - platformFee - creatorFee;

        // Use call to transfer funds to prevent reentrancy attacks
        payable(seller).transfer(sellerAmount);
        payable(config.feeAddress()).transfer(platformFee);
        payable(config.feeAddress()).transfer(creatorFee);
    }

    function _cancelAllOffers(address nftContract, uint256 tokenId) private {
        Listing memory listing = listings[nftContract][tokenId];
        uint256[] storage tokenOfferIds = offerIds[nftContract][tokenId];
        for (uint256 i = 0; i < tokenOfferIds.length; i++) {
            uint256 offerId = tokenOfferIds[i];
            Offer memory offer = offers[nftContract][tokenId][offerId];
            if (offer.buyer != address(0)) {
                payable(offer.buyer).transfer(offer.price);
                emit OfferCancelled(offer.buyer, nftContract, tokenId, offer.price, offer.id,listing.id);
                delete offers[nftContract][tokenId][offer.id];
            }
        }
        delete offerIds[nftContract][tokenId];
    }


      function _removeOfferId(address nftContract, uint256 tokenId, uint256 offerId) private {
        uint256[] storage ids = offerIds[nftContract][tokenId];
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == offerId) {
                ids[i] = ids[ids.length - 1];
                ids.pop();
                break;
            }
        }
    }

    receive() external payable {}

    fallback() external payable {}

      function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {

        return this.onERC721Received.selector;
    }

}