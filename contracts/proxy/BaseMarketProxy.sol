// SPDX-License-Identifier: BUSL-1.1    
pragma solidity ^0.8.20;

import { TacProxyV1 } from "@tonappchain/evm-ccl/contracts/proxies/TacProxyV1.sol";
import "../interface/IMarket.sol";
import { TokenAmount, OutMessageV1, TacHeaderV1, NFTAmount } from "@tonappchain/evm-ccl/contracts/core/Structs.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TvmEvmAccountManager } from "./TvmEvmAccountManager.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IPriceMarket {
    function resolveMarket() external;
    function resolveFee() external view returns (uint256);
}

interface ICreatorMarket{
    function pause() external;
    function resolveMarket(uint256 _winningOptionId) external;
}

contract BaseMarketProxy is TacProxyV1,Ownable {
    TvmEvmAccountManager private tvmEvmAccountManager;

  

    constructor(address _crossChainLayer) TacProxyV1(_crossChainLayer) Ownable(msg.sender) {
    
    }

    function setTvmEvmAccountManager(address _tvmEvmAccountManager) external onlyOwner {
        tvmEvmAccountManager = TvmEvmAccountManager(_tvmEvmAccountManager);
    }


    function buyShares(bytes calldata tacHeader, bytes calldata arguments   ) external _onlyCrossChainLayer {
        (address market, IMarket.BuySharesParams memory params, address _receiver) = _decodeBuyArguments(arguments);
        
        TacHeaderV1 memory header = _decodeTacHeader(tacHeader);

        IERC20(IMarket(market).paymentToken()).approve(address(market), params.amount);

        address evmCaller = tvmEvmAccountManager.getOrCreateAccount(header.tvmCaller);

        _receiver = evmCaller;
        
        IMarket(market).buyShares(params, _receiver);
    }



    function claimSingleReward(bytes calldata tacHeader, bytes calldata arguments) external _onlyCrossChainLayer {
        
        TacHeaderV1 memory header = _decodeTacHeader(tacHeader);

       

        (address market, uint256 _tokenId) = _decodeClaimArguments(arguments);  

        bytes memory callData = abi.encodeWithSelector(
            IMarket.claimSingleReward.selector,
            _tokenId
        );
        
        // Encode the parameters for execute
        bytes memory execArgs = abi.encode(market, 0, callData);

        (, bytes memory returnData) = tvmEvmAccountManager.execute(header.tvmCaller, execArgs);

        uint256 finalReward = abi.decode(returnData, (uint256));
        

        TokenAmount[] memory tokensToBridge = new TokenAmount[](1);
        tokensToBridge[0] = TokenAmount(IMarket(market).paymentToken(), finalReward);

        // approve token with marketProxy from account
        tvmEvmAccountManager.approve(
            tokensToBridge[0].evmAddress, 
            header.tvmCaller,
            address(this), 
            tokensToBridge[0].amount);   
        
        //transfer token from evm caller to marketProxy
        address evmCaller = tvmEvmAccountManager.getOrCreateAccount(header.tvmCaller);
        
        IERC20(IMarket(market).paymentToken()).transferFrom(evmCaller, address(this), finalReward);
        //approve token with crossChainLayer from marketProxy
        IERC20(tokensToBridge[0].evmAddress).approve(
            _getCrossChainLayerAddress(),
            tokensToBridge[0].amount
        );

        OutMessageV1 memory outMsg = OutMessageV1({
        shardsKey: header.shardsKey,
        tvmTarget: header.tvmCaller,
        tvmPayload: "",
        tvmProtocolFee: 0,
        tvmExecutorFee: 0,
        tvmValidExecutors: new string[](0),
        toBridge: tokensToBridge,
        toBridgeNFT: new NFTAmount[](0)
    });

        _sendMessageV1(outMsg,0);
    }

   

    function claimAllReward(bytes calldata tacHeader, bytes calldata arguments) external _onlyCrossChainLayer {
        (address market) = abi.decode(arguments, (address));
        

        TacHeaderV1 memory header = _decodeTacHeader(tacHeader);


        bytes memory callData = abi.encodeWithSelector(
            IMarket.claimAllRewards.selector
        );

        bytes memory execArgs = abi.encode(market, 0, callData);


        (, bytes memory returnData) = tvmEvmAccountManager.execute(header.tvmCaller, execArgs);

        uint256 finalReward = abi.decode(returnData, (uint256));


        TokenAmount[] memory tokensToBridge = new TokenAmount[](1);
        tokensToBridge[0] = TokenAmount(IMarket(market).paymentToken(), finalReward);


        // approve token with marketProxy from account
        tvmEvmAccountManager.approve(
            tokensToBridge[0].evmAddress, 
            header.tvmCaller,
            address(this), 
            tokensToBridge[0].amount);   
        
        //transfer token from evm caller to marketProxy
        address evmCaller = tvmEvmAccountManager.getOrCreateAccount(header.tvmCaller);
        
        IERC20(IMarket(market).paymentToken()).transferFrom(evmCaller, address(this), finalReward);
        
        //approve token with crossChainLayer from marketProxy
        IERC20(tokensToBridge[0].evmAddress).approve(
            _getCrossChainLayerAddress(),
            tokensToBridge[0].amount
        );

        OutMessageV1 memory outMsg = OutMessageV1({
        shardsKey: header.shardsKey,
        tvmTarget: header.tvmCaller,
        tvmPayload: "",
        tvmProtocolFee: 0,
        tvmExecutorFee: 0,
        tvmValidExecutors: new string[](0),
        toBridge: tokensToBridge,
        toBridgeNFT: new NFTAmount[](0)
    });

        _sendMessageV1(outMsg,0);
    }


    function autoResolveMarket(bytes calldata tacHeader, bytes calldata arguments) external _onlyCrossChainLayer {
        TacHeaderV1 memory header = _decodeTacHeader(tacHeader);

        (address market) = abi.decode(arguments, (address));

        IPriceMarket(market).resolveMarket();

        TokenAmount[] memory tokensToBridge = new TokenAmount[](1);
        uint256 resolveFee = IPriceMarket(market).resolveFee();

        uint256 maxResolveFee = 20 * 10**18;

        if (resolveFee > maxResolveFee) {
            resolveFee = maxResolveFee;
        }
        tokensToBridge[0] = TokenAmount(IMarket(market).paymentToken(), resolveFee);
        IERC20(IMarket(market).paymentToken()).approve(
            _getCrossChainLayerAddress(),
            tokensToBridge[0].amount
        );

        OutMessageV1 memory outMsg = OutMessageV1({
        shardsKey: header.shardsKey,
        tvmTarget: header.tvmCaller,
        tvmPayload: "",
        tvmProtocolFee: 0,
        tvmExecutorFee: 0,
        tvmValidExecutors: new string[](0),
        toBridge: tokensToBridge,
        toBridgeNFT: new NFTAmount[](0)
    });

        _sendMessageV1(outMsg,0);
    }


    function resolveMarket(bytes calldata tacHeader, bytes calldata arguments) external _onlyCrossChainLayer {
         TacHeaderV1 memory header = _decodeTacHeader(tacHeader);

        (address market, uint256 _winningOptionId) = abi.decode(arguments, (address,uint256));

         bytes memory callData = abi.encodeWithSelector(
            ICreatorMarket.resolveMarket.selector,
               _winningOptionId
        );

        bytes memory execArgs = abi.encode(market, 0, callData);

        tvmEvmAccountManager.execute(header.tvmCaller, execArgs);
        
    }

    function pause(bytes calldata tacHeader, bytes calldata arguments) external _onlyCrossChainLayer {
        TacHeaderV1 memory header = _decodeTacHeader(tacHeader);


        (address market) = abi.decode(arguments, (address));

        bytes memory callData = abi.encodeWithSelector(
            ICreatorMarket.pause.selector
        );

        bytes memory execArgs = abi.encode(market, 0, callData);

        tvmEvmAccountManager.execute(header.tvmCaller, execArgs);

    }


    function _decodeClaimArguments(bytes calldata arguments) internal pure returns (address market, uint256 _tokenId) {
        (market, _tokenId) = abi.decode(arguments, (address, uint256));
    }   


    function _decodeBuyArguments(bytes calldata arguments) internal pure returns (address market, IMarket.BuySharesParams memory params, address _receiver) {
        (market, params, _receiver) = abi.decode(arguments, (address, IMarket.BuySharesParams, address));
    }




}
