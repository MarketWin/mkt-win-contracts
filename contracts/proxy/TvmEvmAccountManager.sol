// SPDX-License-Identifier: BUSL-1.1    
pragma solidity ^0.8.20;

import { TacProxyV1 } from "@tonappchain/evm-ccl/contracts/proxies/TacProxyV1.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TokenAmount, OutMessageV1, TacHeaderV1 } from "@tonappchain/evm-ccl/contracts/core/Structs.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {SmartAccount} from "./SmartAccount.sol";

/**
 * @title TvmEvmAccountManager
 * @notice Manages mapping between TVM callers and EVM accounts with actual smart contract deployment
 */
contract TvmEvmAccountManager is Ownable {
    // Mapping from TVM caller address (string) to EVM smart account address
    mapping(string => address) private tvmToAccount;
    
    // Mapping from EVM smart account address to TVM caller address
    mapping(address => string) private accountToTvm;
    
    // Beacon for SmartAccount implementation upgrades
    UpgradeableBeacon public accountImplementation;
    
    // Authorized proxies that can call restricted functions
    mapping(address => bool) public authorizedProxies;
    
    // Events
    event AccountCreated(string indexed tvmCaller, address indexed accountAddress);
    event TokensBridged(string indexed tvmCaller, address indexed token, uint256 amount);
    event CallExecuted(string indexed tvmCaller, address indexed target, bool success);
    event ProxyAuthorized(address indexed proxy, bool status);
    
    // Modifier to restrict access to authorized proxies only
    modifier onlyAuthorizedProxy() {
        require(authorizedProxies[msg.sender], "Caller is not an authorized proxy");
        _;
    }
    
    /**
     * @notice Constructor
     * @param _accountImpl Initial implementation of the SmartAccount
     */
    constructor(address _accountImpl) 
        Ownable(msg.sender) 
    {
        accountImplementation = new UpgradeableBeacon(_accountImpl, msg.sender);
    }
    
    /**
     * @notice Set proxy authorization status
     * @param proxy The proxy address to authorize or revoke
     * @param status Authorization status to set
     */
    function setProxyAuthorization(address proxy, bool status) external onlyOwner {
        authorizedProxies[proxy] = status;
        emit ProxyAuthorized(proxy, status);
    }
    
    /**
     * @notice Get or create a SmartAccount for a TVM caller
     * @param tvmCaller The TVM caller address
     * @return The SmartAccount address
     */
    function getOrCreateAccount(string memory tvmCaller) public onlyAuthorizedProxy returns (address) {
        // Return existing account if already created
        if (tvmToAccount[tvmCaller] != address(0)) {
            return tvmToAccount[tvmCaller];
        }
        
        // Create new SmartAccount via proxy
        BeaconProxy proxy = new BeaconProxy(
            address(accountImplementation), 
            abi.encodeWithSelector(SmartAccount.initialize.selector, address(this))
        );
        
        address accountAddress = address(proxy);
        
        // Store mappings
        tvmToAccount[tvmCaller] = accountAddress;
        accountToTvm[accountAddress] = tvmCaller;
        
        emit AccountCreated(tvmCaller, accountAddress);
        
        return accountAddress;
    }
    
    /**
     * @notice Execute a function call on behalf of a TVM user through their SmartAccount
     * @param tvmCaller The TVM caller address
     * @param arguments The encoded arguments for target and call data
     * @return success Whether the call was successful
     * @return returnData The return data from the call
     */
    function execute(string memory tvmCaller, bytes calldata arguments) 
        external
        onlyAuthorizedProxy  
        returns (bool success, bytes memory returnData) 
    {
        // Get or create a SmartAccount for the TVM caller
        address account = getOrCreateAccount(tvmCaller);
        
        // Decode the target and call data
        (address target, uint256 value, bytes memory callData) = abi.decode(arguments, (address, uint256, bytes));
        
        // Execute through the SmartAccount
        returnData = SmartAccount(payable(account)).execute(target, value, callData);
        success = true;
        
        return (success, returnData);
    }


    function approve(address token, string memory tvmCaller, address spender, uint256 amount) external onlyAuthorizedProxy {
        address account = getOrCreateAccount(tvmCaller);
        SmartAccount(payable(account)).approve(token,spender, amount);
    }

    

    
    
    /**
     * @notice Update the SmartAccount implementation
     * @param _newImplementation The new implementation address
     */
    function updateAccountImplementation(address _newImplementation) external onlyOwner {
        accountImplementation.upgradeTo(_newImplementation);
    }
    
    /**
     * @notice Checks if an address is a managed account
     * @param addr The address to check
     * @return Whether the address is a managed account
     */
    function isAccountManaged(address addr) external view returns (bool) {
        return bytes(accountToTvm[addr]).length > 0;
    }
    
    /**
     * @notice Get the TVM caller for a managed account
     * @param account The account address
     * @return The TVM caller address
     */
    function getTvmCaller(address account) external view returns (string memory) {
        return accountToTvm[account];
    }
    
    /**
     * @notice Get the managed account for a TVM caller
     * @param tvmCaller The TVM caller address
     * @return The managed account address
     */
    function getAccount(string memory tvmCaller) external view returns (address) {
        return tvmToAccount[tvmCaller];
    }
} 