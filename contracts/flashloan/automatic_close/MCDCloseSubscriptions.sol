pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../../constants/ConstantAddresses.sol";


/// @title Handles subscriptions for automatic monitoring
contract MCDCloseSubscriptions is ConstantAddresses {

    struct CdpHolder {
        uint256 takeProfit;
        uint256 stopLoss;
        uint256 cdpId;
        address owner;
    }

    struct SubPosition {
        uint arrPos;
        bool subscribed;
    }

    CdpHolder[] public subscribers;
    mapping (uint => SubPosition) public subscribersPos;

    mapping (bytes32 => uint) public minLimits;

    address public owner;
    uint public changeIndex;

    Manager public manager = Manager(MANAGER_ADDRESS);
    Vat public vat = Vat(VAT_ADDRESS);
    Spotter public spotter = Spotter(SPOTTER_ADDRESS);

    event Subscribed(address indexed owner, uint cdpId);
    event Unsubscribed(address indexed owner, uint cdpId);
    event Updated(address indexed owner, uint cdpId);

    constructor(address _saverProxy) public {
        owner = msg.sender;
    }

    function subscribe(uint _cdpId, uint256 _stopLoss, uint256 _takeProfit) external {
        require(isOwner(msg.sender, _cdpId), "Must be called by Cdp owner");
        // require(checkParams(manager.ilks(_cdpId), _minRatio, _maxRatio), "Must be correct params");

        SubPosition storage subInfo = subscribersPos[_cdpId];

        CdpHolder memory subscription = CdpHolder({
                minRatio: _stopLoss,
                maxRatio: _takeProfit,
                owner: msg.sender,
                cdpId: _cdpId
            });

        changeIndex++;

        if (subInfo.subscribed) {
            subscribers[subInfo.arrPos] = subscription;

            emit Updated(msg.sender, _cdpId);
        } else {
            subscribers.push(subscription);

            subInfo.arrPos = subscribers.length - 1;
            subInfo.subscribed = true;

            emit Subscribed(msg.sender, _cdpId);
        }
    }

    /// @notice Called by the users DSProxy
    /// @dev Owner who subscribed cancels his subscription
    function unsubscribe(uint _cdpId) external {
        require(isOwner(msg.sender, _cdpId), "Must be called by Cdp owner");

        _unsubscribe(_cdpId);
    }

        /// @dev Internal method to remove a subscriber from the list
    function _unsubscribe(uint _cdpId) internal {
        require(subscribers.length > 0, "Must have subscribers in the list");

        SubPosition storage subInfo = subscribersPos[_cdpId];

        require(subInfo.subscribed, "Must first be subscribed");

        uint lastCdpId = subscribers[subscribers.length - 1].cdpId;

        SubPosition storage subInfo2 = subscribersPos[lastCdpId];
        subInfo2.arrPos = subInfo.arrPos;

        subscribers[subInfo.arrPos] = subscribers[subscribers.length - 1];
        delete subscribers[subscribers.length - 1];
        subscribers.length--;

        changeIndex++;
        subInfo.subscribed = false;
        subInfo.arrPos = 0;

        emit Unsubscribed(msg.sender, _cdpId);
    }

    /// @notice Admin function to unsubscribe a CDP if it's owner transfered to a different addr
    function unsubscribeIfMoved(uint _cdpId) public {
        require(msg.sender == owner, "Must be owner");

        SubPosition storage subInfo = subscribersPos[_cdpId];

        if (subInfo.subscribed) {
            if (getOwner(_cdpId) != subscribers[subInfo.arrPos].owner) {
                _unsubscribe(_cdpId);
            }
        }
    }

    /// @dev Checks if the _owner is the owner of the CDP
    function isOwner(address _owner, uint _cdpId) internal view returns (bool) {
        return getOwner(_cdpId) == _owner;
    }

    /// @notice Returns an address that owns the CDP
    /// @param _cdpId Id of the CDP
    function getOwner(uint _cdpId) public view returns(address) {
        return manager.owns(_cdpId);
    }

    /// @notice Checks if Close can be triggered for the CDP
    /// @dev Called by MCDMonitor to enforce the min/max check
    function canCall(uint _cdpId) public view returns(bool, uint) {
        SubPosition memory subInfo = subscribersPos[_cdpId];

        if (!subInfo.subscribed) return (false, 0);

        CdpHolder memory subscriber = subscribers[subInfo.arrPos];

        if (getOwner(_cdpId) != subscriber.owner) return (false, 0);

        uint price = getPrice(_cdpId);

        return ((price < subscriber.stopLoss) || (price > subscriber.takeProfit), price);
    }

    function getPrice(uint _cdpId) public view returns(uint) {

    }
}
