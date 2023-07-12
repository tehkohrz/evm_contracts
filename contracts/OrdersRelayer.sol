// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/utils/Strings.sol";
import "./@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./@openzeppelin/contracts/access/Ownable.sol";
import "./@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";

contract OrdersRelayer is Ownable, Pausable {
    struct PositionQuery {
        string market;
        address caller;
        string fnSigature;
    }

    struct Position {
        string market;
        string accountAddress;
        int256 lots;
        uint256 entryPrice;
        int256 realisedPnl;
        string marginDenom;
        uint256 marginAmount;
        uint256 openBlockHeight;
    }

    struct Order {
        string id;
        string market;
        Side side;
        uint256 price;
        uint256 quantity; // Originally int will have extra decimal zeros
        Status status;
        OrderType orderType;
        TimeInForce timeInForce;
        uint256 avgFilledPrice;
        bool isReduceOnly;
        address evmCreator; // evm address of the creator
    }

    struct MsgOrderUpdate {
        string orderKey;
        string orderId;
        uint256 avgFilledPrice;
        Status status;
    }

    struct MsgPositionUpdate {
        address evmAddress;
        string market;
        string accountAddress;
        int256 lots;
        uint256 entryPrice;
        int256 realisedPnl;
        string marginDenom;
        uint256 marginAmount;
        uint256 openBlockHeight;
    }

    enum Status {
        Nil,
        Pending,
        Closed,
        Cancelled,
        Open
    }

    enum TimeInForce {
        FOK,
        GTC,
        IOC
    }

    enum Side {
        Buy,
        Sell
    }

    enum OrderType {
        Limit,
        Market
    }

    // =============Storage==============
    string public contractId;
    uint256 internal _orderSequence = 0;
    uint64 public decimals;

    // Need to define the full signature without the struct
    //?need to be a local var to show people what their method sign needs to be?
    bytes4 public positionResSig =
        bytes4(
            keccak256(
                "recievePosition((address, string, string, int256, uint256, int256, string, uint256, uint256))"
            )
        );

    // OrderId is the key for the map
    // can consider not having a mapping since successfully relayed
    // stores the pending order for info until updates are provided by carbon
    // orders emit an event but map used to check for id collision
    mapping(string => Order) public pendingOrders;

    // Mapping to store caller address and request
    mapping(address => PositionQuery) public positionQueries;

    // =============Events================
    event Test(string log); // dklog

    event CreateOrder(
        string orderKey,
        address creator,
        string market,
        Side side,
        uint256 price,
        uint256 quantity,
        Status status,
        OrderType orderType,
        TimeInForce timeInForce,
        bool isReduceOnly,
        uint64 decimals,
        string contractId
    );

    // carbon address fields removed from event as stack too deep
    event FinalisedOrder(
        string orderKey,
        string id,
        string market,
        Side side,
        uint256 price,
        uint256 quantity,
        Status status,
        OrderType orderType,
        TimeInForce timeInForce,
        uint256 avgFilledPrice,
        bool isReduceOnly,
        address evmCreator
    );

    event PositionResponse(MsgPositionUpdate msg);

    // order error event to inform that the order is not processed by carbon
    event OrderError(string orderKey, string error);

    constructor(string memory contractId_, uint64 decimals_) {
        contractId = contractId_;
        decimals = decimals_;
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
            if (existingOrder.status != Status.Nil) {
                isCollision = true;
            }
        }
        _orderSequence += 1;
        return stringId;
    }

    // createOrder - generates a new FOK order to be store in the contract and relayed to carbon
    // Creator is not the msg.sender as the sender can be a relayer contract
    function createOrder(
        string calldata market_,
        Side side_,
        uint256 quantity_,
        OrderType orderType_,
        uint256 price_,
        bool isReduceOnly_
    ) external whenNotPaused returns (string memory orderKey) {
        Order memory newOrder;
        orderKey = generateOrderKey();

        address creator_ = tx.origin; // to use tx.origin or _msg.Sender?

        newOrder.id = ""; // This is the id generated by carbon
        newOrder.evmCreator = creator_;
        newOrder.market = market_;
        newOrder.side = side_;
        newOrder.price = price_;
        newOrder.quantity = quantity_;
        newOrder.status = Status.Pending;
        newOrder.orderType = orderType_;
        newOrder.timeInForce = TimeInForce.GTC; // DKLOG for testing change back to FOK
        newOrder.isReduceOnly = isReduceOnly_;

        // add the order into the mapping
        pendingOrders[orderKey] = newOrder;

        // emitted event to carbon for order creation
        emit CreateOrder(
            orderKey,
            creator_,
            newOrder.market,
            newOrder.side,
            newOrder.price,
            newOrder.quantity,
            newOrder.status,
            newOrder.orderType,
            newOrder.timeInForce,
            newOrder.isReduceOnly,
            decimals,
            contractId
        );

        return orderKey;
    }

    // updateOrderStatus - receives the finalised order from carbon and broadcast the finalised order
    function updateOrderStatus(
        string calldata orderKey,
        string calldata orderId_,
        uint256 avgFilledPrice_,
        Status status_
    ) public onlyOwner whenNotPaused returns (bool error) {
        // Get the pending order
        Order storage order = pendingOrders[orderKey];
        if (order.quantity == 0) {
            return true;
        }

        // Update the pending order and emit the finalised order details
        order.avgFilledPrice = avgFilledPrice_;
        order.id = orderId_;
        order.status = status_;

        // Remove pending order from the store
        delete pendingOrders[orderKey];
        return false;
    }

    function updateAllOrdersStatus(
        MsgOrderUpdate[] calldata orderUpdates_
    ) external onlyOwner whenNotPaused returns (string memory error) {
        for (uint i = 0; i < orderUpdates_.length; i += 1) {
            bool err = updateOrderStatus(
                orderUpdates_[i].orderKey,
                orderUpdates_[i].orderId,
                orderUpdates_[i].avgFilledPrice,
                orderUpdates_[i].status
            );
            if (err) {
                return "Order could not be updated";
            }
        }
        return "";
    }

    function emitFinalOrder(
        Order calldata order,
        string calldata orderKey
    ) internal {
        emit FinalisedOrder(
            orderKey,
            order.id,
            order.market,
            order.side,
            order.price,
            order.quantity,
            order.status,
            order.orderType,
            order.timeInForce,
            order.avgFilledPrice,
            order.isReduceOnly,
            order.evmCreator
        );
    }

    // deleteErrOrder - deletes the pending order that has been validated to be erroneous by carbon and emits an error event
    function deleteErrOrder(
        string calldata orderKey_,
        string calldata error_
    ) external onlyOwner whenNotPaused {
        // purge the pending order from the store as it will not be processed by carbon
        delete pendingOrders[orderKey_];
        emit OrderError(orderKey_, error_);
    }

    // QueryAddressPosition
    function queryAddressPosition(
        address accountAddress_,
        string calldata market_,
        string calldata callbackSig_
    ) external whenNotPaused {
        PositionQuery memory positionQuery;
        positionQuery.market = market_;
        positionQuery.caller = _msgSender();
        positionQuery.fnSigature = callbackSig_;

        positionQueries[accountAddress_] = positionQuery;
    }

    // Caller contract need to implement the function signature defined above to receive the response
    function respondToPositionQuery(
        MsgPositionUpdate calldata msg_
    ) external onlyOwner whenNotPaused {
        PositionQuery memory queryReq = positionQueries[msg_.evmAddress];

        console.log("respondToPositionQuery\n", queryReq.fnSigature); //dklog
        bytes memory encodedCall = abi.encodeWithSignature(
            queryReq.fnSigature,
            msg_
            // msg_.evmAddress,
            // msg_.market,
            // msg_.accountAddress,
            // msg_.lots,
            // msg_.entryPrice,
            // msg_.realisedPnl,
            // msg_.marginDenom,
            // msg_.marginAmount,
            // msg_.openBlockHeight
        );

        // no need return value of call since it is a fire and forget but send an event so the caller
        // can still check for the position in another way
        (bool success, ) = queryReq.caller.call(encodedCall);
        if (!success) {
            emit PositionResponse(msg_);
        }
        // remove the query from the store
        delete positionQueries[msg_.evmAddress];
    }

    //Trial functions - sanity check that it works
    function updateTestNumber(address evmAddr, uint8 testNumber_) external {
        PositionQuery memory query = positionQueries[evmAddr];
        console.log("relayer", testNumber_);

        // This works must be exact name of function
        query.caller.call(
            abi.encodeWithSignature(query.fnSigature, testNumber_)
        );
    }

    function ping() public pure returns (string memory) {
        return "pong";
    }
}
