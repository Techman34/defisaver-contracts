pragma solidity ^0.5.0;

import "../../DS/DSGuard.sol";
import "../../DS/DSAuth.sol";
import "../../constants/ConstantAddresses.sol";

contract SubscriptionsInterface {
    function subscribe(uint _cdpId, uint128 _minRatio, uint128 _maxRatio, uint128 _optimalBoost, uint128 _optimalRepay) external {}
    function unsubscribe(uint _cdpId) external {}
}

/// @title SubscriptionsProxy handles authorization and interaction with the Subscriptions contract
contract MCDCloseSubscriptionProxy is ConstantAddresses {

    address public constant MCD_CLOSE_STATIC_PROXY = address(0);

    function subscribe(uint _cdpId, uint128 _stopLoss, uint128 _takeProfit, address _subscriptions) public {

        address currAuthority = address(DSAuth(address(this)).authority());
        DSGuard guard = DSGuard(currAuthority);

        if (currAuthority == address(0)) {
            guard = DSGuardFactory(FACTORY_ADDRESS).newGuard();
            DSAuth(address(this)).setAuthority(DSAuthority(address(guard)));
        }

        guard.permit(MCD_CLOSE_STATIC_PROXY, address(this), bytes4(keccak256("execute(address,bytes)")));

        SubscriptionsInterface(_subscriptions).subscribe(_cdpId, _stopLoss, _takeProfit);
    }

    function update(uint _cdpId, uint128 _stopLoss, uint128 _takeProfit, address _subscriptions) public {
        SubscriptionsInterface(_subscriptions).subscribe(_cdpId, _stopLoss, _takeProfit);
    }

    function unsubscribe(uint _cdpId, address _subscriptions) public {
        SubscriptionsInterface(_subscriptions).unsubscribe(_cdpId);
    }
}
