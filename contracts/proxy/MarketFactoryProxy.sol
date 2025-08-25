// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { TacProxyV1 } from "@tonappchain/evm-ccl/contracts/proxies/TacProxyV1.sol";
import "../interface/IMarketFactory.sol";
import { TokenAmount, OutMessageV1, TacHeaderV1 } from "@tonappchain/evm-ccl/contracts/core/Structs.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TvmEvmAccountManager } from "./TvmEvmAccountManager.sol";
import "../config/WhiteListConfig.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MarketFactoryProxy is TacProxyV1, Ownable {

    TvmEvmAccountManager private  tvmEvmAccountManager;

    IMarketFactory private immutable marketFactory;

    WhiteListConfig private wlConfig;

    address wlAdmin;
    
    constructor(address _factory,address _crossChainLayer) TacProxyV1(_crossChainLayer) Ownable(msg.sender) {
        marketFactory = IMarketFactory(_factory);
    }

    function setTvmEvmAccountManager(address _tvmEvmAccountManager) external onlyOwner {
        require(tvmEvmAccountManager == TvmEvmAccountManager(address(0)), "TvmEvmAccountManager already set");
        require(_tvmEvmAccountManager != address(0), "Invalid address");
        tvmEvmAccountManager = TvmEvmAccountManager(_tvmEvmAccountManager);

    }

    function setWhitelistConfig(address _whitelistConfig) external onlyOwner {
        require(_whitelistConfig != address(0), "Invalid address");
        wlConfig = WhiteListConfig(_whitelistConfig);
    }

    function createMarket(
      bytes calldata tacHeader, bytes calldata arguments
    ) external _onlyCrossChainLayer returns (address _marketAddress) {

        (uint8 marketType, IMarket.MarketCreationParams memory params, uint256 estimatedValue) = _decodeArguments(arguments);
        
        TacHeaderV1 memory header = _decodeTacHeader(tacHeader);

        IERC20(marketFactory.paymentToken()).approve(address(marketFactory), estimatedValue);

        address evmCaller = tvmEvmAccountManager.getOrCreateAccount(header.tvmCaller);
        
        marketFactory.createMarket(marketType, params, evmCaller,estimatedValue);


       

    }  


    function addWlAdmin(address _admin) external onlyOwner {
        wlAdmin = _admin;
    }

    modifier onlyWlAdmin() {
        require(wlAdmin == msg.sender, "Not the wl admin");
        _;
    }


    function batchAddWhiteList  (string[] memory _tvmAddresses) external onlyWlAdmin {
       for (uint256 i = 0; i < _tvmAddresses.length; i++) {
            address evmCaller = tvmEvmAccountManager.getOrCreateAccount(_tvmAddresses[i]);
            wlConfig.addToWhitelist(evmCaller);
       }
    }

    function _decodeArguments(bytes calldata arguments) internal pure returns (uint8 marketType, IMarket.MarketCreationParams memory params, uint256 estimatedValue) {
        (marketType, params, estimatedValue) = abi.decode(arguments, (uint8, IMarket.MarketCreationParams, uint256));
    }
    
}