pragma solidity ^0.5.0;


contract MCDAutomaticClose {

    uint256 public constant CLOSE_GAS_TOKEN = 20; // check this


    /// @notice Bots call this method to repay for user when conditions are met
    /// @dev If the contract ownes gas token it will try and use it for gas price reduction
    /// @param _cdpId Id of the cdp
    /// @param _amount Amount of Eth to convert to Dai
    /// @param _exchangeType Which exchange to use, 0 is to select best one
    /// @param _collateralJoin Address of collateral join for specific CDP
    function closeFor(uint256[6] memory _data,
        address _joinAddr,
        address _exchangeAddress,
        bytes memory _callData,
        uint256 _minCollateral
    ) public onlyApproved {
        if (gasToken.balanceOf(address(this)) >= CLOSE_GAS_TOKEN) {
            gasToken.free(CLOSE_GAS_TOKEN);
        }

        uint ratioBefore;
        bool canCall;
        (canCall, ratioBefore) = subscriptionsContract.canCall(Method.Repay, _cdpId);
        require(canCall);

        uint gasCost = calcGasCost(REPAY_GAS_COST);

        monitorProxyContract.callExecute(subscriptionsContract.getOwner(_cdpId), mcdSaverProxyAddress, abi.encodeWithSignature("repay(uint256,address,uint256,uint256,uint256,uint256)", _cdpId, _collateralJoin, _amount, 0, _exchangeType, gasCost));

        uint ratioAfter;
        bool ratioGoodAfter;
        (ratioGoodAfter, ratioAfter) = subscriptionsContract.ratioGoodAfter(Method.Repay, _cdpId);
        // doesn't allow user to repay too much
        require(ratioGoodAfter);

        emit CdpRepay(_cdpId, msg.sender, _amount, ratioBefore, ratioAfter);
    }


    function getCollAmount(uint256[6] memory _data, uint256 _loanAmount, address _collateralAddr)
        internal
        returns (uint256 collAmount)
    {
        (, uint256 collPrice) = SaverExchangeInterface(SAVER_EXCHANGE_ADDRESS).getBestPrice(
            _data[1],
            _collateralAddr,
            DAI_ADDRESS,
            _data[2]
        );
        collPrice = sub(collPrice, collPrice / 100); // offset the price by 1%

        collAmount = wdiv(_loanAmount, collPrice);
    }
}
