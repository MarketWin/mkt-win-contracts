// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.2 <0.9.0;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SmartAccount is Initializable, IERC721Receiver {
   address public owner;

   event Executed(address indexed target, uint256 value, bytes data);
   event ERC20Transferred(address indexed token, address indexed to, uint256 amount);
   event ERC721Transferred(address indexed token, address indexed to, uint256 tokenId);

   modifier onlyOwner() {
       require(msg.sender == owner, "Not the owner");
       _;
   }

   function initialize(address _owner) public initializer {
       owner = _owner;
   }

   function execute(address target, uint256 value, bytes calldata data) external onlyOwner returns (bytes memory) {
      (bool success, bytes memory result) = target.call{value: value}(data);
    if (!success) {
        if (result.length > 0) {
            assembly {
                let result_ptr := add(result, 0x20)
                let result_size := mload(result)
                revert(result_ptr, result_size)
            }
        } else {
            revert("Call reverted without a message");
        }
    }
       return result;
   }

   function approve(address token, address spender, uint256 amount) external onlyOwner {
       IERC20(token).approve(spender, amount);
   }

   // ERC20 transfer convenience function
   

   // ERC721 transfer convenience function
   function approveErc721(address token, address spender, uint256 tokenId) external onlyOwner {
       IERC721(token).approve(spender, tokenId);
   }

   // ERC721 receiver implementation
   function onERC721Received(
       address, address, uint256, bytes calldata
   ) external pure override returns (bytes4) {
       return IERC721Receiver.onERC721Received.selector;
   }

   receive() external payable {}
}