// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/utils/Strings.sol";

contract OrdersRelayer {
    // Commented order fields cannot be added due to stack limitation
    // 12 fields for the local stored map
    struct Order {
        string id;
        uint256 timeCreated; // tag with current timestamp?
        address creator; // this is the mapped carbon address
        string market;
        string side;
        uint256 price;
        uint256 quantity; // Originally int will have extra decimal zeros
        // uint256 available;
        // uint256 filled;
        string status;
        string orderType;
        string timeInForce;
        uint256 avgFilledPrice;
        bool isReduceOnly;
        // string referralAddress; //? this address will with evm or carbon address?
        // uint32 referalCommission; // Originally int need to add decimal zeros
        // uint32 referralKickback; // Originally int need to add decimal zeros
    }

    string public contractId;
    uint256 internal _orderSequence = 0;
    uint64 public decimals;
    address public creator; // carbon broker module address
    string public allowedTimeInForce = "FOK";
    //? a varible to toggle enable and disable the use of this contract?

    // OrderId is the key for the map
    // stores the pending order for info until updates are provided by carbon
    // can consider not having a mapping since successfully relayed
    // orders emit an event but map used to check for id collision
    mapping(string => Order) public pendingOrders;

    event CreateOrder(
        address indexed sender,
        Order order,
        address creator,
        string orderKey
    );

    event testLog(string testVar); //dklog

    constructor(string memory contractId_, uint64 decimals_) {
        contractId = contractId_;
        decimals = decimals_;
        creator = msg.sender;
    }

    // Hash functions to generate a uuid for the order using a combination of contractId
    // and running sequence number within the contract
    function generateOrderKey() public returns (string memory) {
        bool isCollision = true;
        string memory stringId;
        // generate hashId until no collisions found
        while (isCollision) {
            bytes memory bz = abi.encodePacked(contractId, _orderSequence);
            bytes32 hashedId = keccak256(bz);
            stringId = Strings.toHexString(uint256(hashedId), 32);
            isCollision = false;

            // Check existing pending store for key collisions
            Order memory existingOrder = pendingOrders[stringId];
            if (strEquality(existingOrder.status, "pending")) {
                isCollision = true;
            }
        }
        _orderSequence += 1;
        return stringId;
    }

    // CreateOrder - generates a new FOK order to be store in the contract and relayed to carbon
    // Creator is not the msg.sender as the sender can be a relayer contract
    function createOrder(
        address creator_,
        string calldata market_,
        string calldata side_,
        uint256 quantity_,
        string calldata orderType_,
        uint256 price_,
        bool isReduceOnly_
    ) external {
        Order memory newOrder;

        string memory orderKey = generateOrderKey();

        newOrder.id = ""; // This is the id generated by carbon
        newOrder.timeCreated = 0;
        newOrder.market = market_;
        newOrder.side = side_;
        newOrder.price = price_;
        newOrder.quantity = quantity_;
        newOrder.status = "pending";
        newOrder.orderType = orderType_;
        // newOrder.timeInForce = allowedTimeInForce; // dklog
        newOrder.timeInForce = "gtc"; // dklog test gtc and check that the order exist
        newOrder.isReduceOnly = isReduceOnly_;

        // add the order into the mapping
        pendingOrders[orderKey] = newOrder;

        // emitted event to carbon for order creation
        emit CreateOrder(msg.sender, newOrder, creator_, orderKey);
    }

    //todo: update order state with new status from carbon
    //todo: cancel order
    //todo: edit order
    //todo: get marketstat by market id (is this auto?)

    // Helper functions
    function strEquality(
        string memory str1,
        string memory str2
    ) internal pure returns (bool) {
        return (keccak256(bytes(str1)) == keccak256(bytes(str2)));
    }
}

// MarketStat will store the current/latest market stats important for automated trading
// struct MarketStat {
//     string market;
//     string marketType;
// uint256 dayOpen;
// uint256 dayClose;
// uint256 dayHigh;
// uint256 dayLow;
// uint256 dayVolume; // Originally int need to add decimal zeros
// uint256 dayQuoteVolume; // Originally int need to add decimal zeros
//     uint256 indexPrice;
//     uint256 markPrice;
//     uint256 lastPrice;
//     uint256 premiumRate;
//     uint256 lastFundingAt;
//     uint64 openInterest; // Originally int need to add decimal zeros
// }

/*

    // getOrderById is used to obtain data on open orders as pending orders would not have been assigned a order id yet
    //todo: call the contract update methods and see the block height
    function getOrderById(
        string calldata orderId_
    ) public view returns (Order memory, bool) {
        Order memory response;
        // searching the openOrders via the map keys and looping through the orders within
        for (uint256 i = 0; i < openOrdersKeys.length; i += 1) {
            address key = openOrdersKeys[i];
            Order[] memory currentArr = openOrders[key];
            for (uint256 j = 0; j < currentArr.length; j += 1) {
                if (
                    keccak256(bytes(currentArr[j].id)) ==
                    keccak256(bytes(orderId_))
                ) {
                    response = currentArr[j];
                    return (response, true);
                }
            }
        }
        return (response, false);
    }

    // getOrderById is used to obtain data on open orders as pending orders would not have been assigned a order id yet
    //todo: call the contract update methods and see the block height
    function getOrderById(
        string calldata orderId_
    ) public view returns (Order memory, bool) {
        Order memory response;
        // searching the openOrders via the map keys and looping through the orders within
        for (uint256 i = 0; i < openOrdersKeys.length; i += 1) {
            address key = openOrdersKeys[i];
            Order[] memory currentArr = openOrders[key];
            for (uint256 j = 0; j < currentArr.length; j += 1) {
                if (
                    keccak256(bytes(currentArr[j].id)) ==
                    keccak256(bytes(orderId_))
                ) {
                    response = currentArr[j];
                    return (response, true);
                }
            }
        }
        return (response, false);
    }

    // getOrdersByAddress retrieve all the pending and open orders made by the
    // evm address given -> order.address is the mapped carbon address
    // returns empty array if no orders found
    function getOrdersByAddress(
        address creator_
    ) public view returns (Order[] memory) {
        Order[] memory pendingOs = pendingOrders[creator_];
        Order[] memory openOs = openOrders[creator_];
        uint256 totalLength = pendingOs.length + openOs.length;
        Order[] memory foundOrders = new Order[](totalLength);

        // concat the two arrays together
        for (uint256 i = 0; i < pendingOs.length; i += 1) {
            foundOrders[i] = pendingOs[i];
        }
        for (uint256 i = 0; i < openOs.length; i += 1) {
            foundOrders[i + pendingOs.length] = openOs[i];
        }
        return foundOrders;
    }

    // getOrdersByAddress retrieve all the pending and open orders made by the
    // evm address given -> order.address is the mapped carbon address
    // returns empty array if no orders found
    function getOrdersByAddress(
        address creator_
    ) public view returns (Order[] memory) {
        Order[] memory pendingOs = pendingOrders[creator_];
        Order[] memory openOs = openOrders[creator_];
        uint256 totalLength = pendingOs.length + openOs.length;
        Order[] memory foundOrders = new Order[](totalLength);

        // concat the two arrays together
        for (uint256 i = 0; i < pendingOs.length; i += 1) {
            foundOrders[i] = pendingOs[i];
        }
        for (uint256 i = 0; i < openOs.length; i += 1) {
            foundOrders[i + pendingOs.length] = openOs[i];
        }
        return foundOrders;
    }

    */
