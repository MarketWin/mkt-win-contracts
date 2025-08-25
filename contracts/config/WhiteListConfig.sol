// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WhiteListConfig
 * @dev wl config
 */
contract WhiteListConfig is Ownable {
    // whitelist mapping
    mapping(address => bool) public whitelistedAddresses;
    
    // admin mapping
    mapping(address => bool) public admins;
    
    // events
    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);

    /**
     * @dev modifier to check if caller is admin or owner
     */
    modifier onlyAdminOrOwner() {
        require(admins[msg.sender] || owner() == msg.sender, "WhiteListConfig: caller is not admin or owner");
        _;
    }

    /**
     * @dev constructor
     */
    constructor() Ownable(msg.sender) {
       whitelistedAddresses[msg.sender] = true;
       admins[msg.sender] = true;
    }
    
    /**
     * @dev add admin
     * @param admin address to add as admin
     */
    function addAdmin(address admin) external onlyOwner {
        require(admin != address(0), "WhiteListConfig: zero address");
        admins[admin] = true;
        emit AdminAdded(admin);
    }
    
    /**
     * @dev remove admin
     * @param admin address to remove as admin
     */
    function removeAdmin(address admin) external onlyOwner {
        admins[admin] = false;
        emit AdminRemoved(admin);
    }
    
    /**
     * @dev check if address is admin
     * @param account address to check
     * @return true if address is admin
     */
    function isAdmin(address account) public view returns (bool) {
        return admins[account];
    }
    
    /**
     * @dev add address to whitelist
     * @param account address to add
     */
    function addToWhitelist(address account) external onlyAdminOrOwner {
        require(account != address(0), "WhiteListConfig: zero address");
        whitelistedAddresses[account] = true;
        emit AddedToWhitelist(account);
    }
    
    /**
     * @dev batch add address to whitelist
     * @param accounts addresses to add
     */
    function batchAddToWhitelist(address[] calldata accounts) external onlyAdminOrOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0)) {
                whitelistedAddresses[accounts[i]] = true;
                emit AddedToWhitelist(accounts[i]);
            }
        }
    }
    
    /**
     * @dev remove address from whitelist
     * @param account address to remove
     */
    function removeFromWhitelist(address account) external onlyAdminOrOwner {
        whitelistedAddresses[account] = false;
        emit RemovedFromWhitelist(account);
    }
    
    /**
     * @dev check if address is in whitelist
     * @param account address to check
     * @return true if address is in whitelist
     */
    function isWhitelisted(address account) public view returns (bool) {
        return whitelistedAddresses[account];
    }
}