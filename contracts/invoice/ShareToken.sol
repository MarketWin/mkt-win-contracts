// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ShareToken is ERC20 {

    uint256 public immutable transferTime;
    address public immutable market;

    modifier onlyMarket() {
        require(msg.sender == market, "Only market can call this function");
        _;
    }

    constructor(string memory name, string memory symbol, uint256 _transferTime, address _market) ERC20(name, symbol) {
        transferTime = _transferTime;
        market = _market;
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0)) {
            require(block.timestamp >= transferTime, "Transfer not allowed before transfer time");
        }
        super._update(from, to, value);
    }

    function mint(address account, uint256 amount) external onlyMarket {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyMarket {
        _burn(account, amount);
    }
}

