// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/utils/Strings.sol";
import "./@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./@openzeppelin/contracts/access/Ownable.sol";
import "./@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";

contract OrdersRelayer is Ownable, Pausable {
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

    struct PositionQuery {
        string market;
        address caller;
        string fnSigature;
    }

    struct MsgPositionQueryRes {
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

    struct OrderQuery {
        address caller;
        string fnSigature;
    }

    struct MsgOrderQueryResponse {
        string orderKey;
        Order order;
    }

    enum Status {
        Unprocessed,
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
    mapping(string => OrderQuery) public orderQueries;
    mapping(string => OrderQuery) public orderCreationCallback;

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

    event FinalisedOrder(string orderKey, Order order);

    event PositionResponse(MsgPositionQueryRes msg);

    // order error event to inform that the order is not processed by carbon
    event OrderError(string orderKey, Order errOrder, string error);

    constructor(string memory contractId_, uint64 decimals_) {
        contractId = contractId_;
        decimals = decimals_;
    }

    // Hash functions to generate a uuid for the order using a combination of contractId
    // and running sequence number within the contract
    function generateOrderKey() private returns (string memory) {
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
            if (existingOrder.status != Status.Unprocessed) {
                isCollision = true;
            }
        }
        _orderSequence += 1;
        return stringId;
    }

    // createOrder - generates a new FOK order to be store in the contract and relayed to carbon
    // returns a unique orderKey that is used to identify the order in the contract before
    // Creator is not the msg.sender as the sender can be a relayer contract
    function createOrder(
        string calldata market_,
        Side side_,
        uint256 quantity_,
        OrderType orderType_,
        uint256 price_,
        bool isReduceOnly_,
        string calldata callbackSig_
    ) external whenNotPaused {
        console.log("createOrder called", market_); //dklog

        Order memory newOrder;
        string memory orderKey = generateOrderKey();

        address creator_ = tx.origin; // to use tx.origin or _msg.Sender? //dklog

        newOrder.id = ""; // This is the id generated by carbon
        newOrder.evmCreator = creator_;
        newOrder.market = market_;
        newOrder.side = side_;
        newOrder.price = price_;
        newOrder.quantity = quantity_;
        newOrder.status = Status.Pending;
        newOrder.orderType = orderType_;
        newOrder.timeInForce = TimeInForce.GTC; //! DKLOG for testing change back to FOK
        newOrder.isReduceOnly = isReduceOnly_;

        // add the order into the mapping
        pendingOrders[orderKey] = newOrder;

        // add to the callback map if signature is provided
        if (bytes(callbackSig_).length > 0) {
            // order id field is irrelevant here
            orderCreationCallback[orderKey] = OrderQuery(
                _msgSender(),
                callbackSig_
            );
        }

        // emitted event to carbon for order creation
        // contractId is used to identify the contract the order originates from
        // to account for implementation of multiple contracts for other kinds of orders
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
        console.log("ORDER KEY GENERATED", orderKey);
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

        // Callback to the caller or emit finalised order event
        orderCallback(order, orderKey);
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
        Order memory order,
        string calldata orderKey
    ) internal {
        emit FinalisedOrder(orderKey, order);
    }

    function orderCallback(
        Order storage order,
        string calldata orderKey
    ) internal {
        bool noEmitEvent = false;

        // Check for callback request
        OrderQuery memory req = orderCreationCallback[orderKey];
        if (bytes(req.fnSigature).length > 0) {
            console.log("relayer calling callback"); //dklog
            // Send the full order back to the caller or emit event on failure
            bytes memory encodedCall = abi.encodeWithSignature(
                req.fnSigature,
                order,
                orderKey
            );
            (noEmitEvent, ) = req.caller.call(encodedCall);

            delete orderCreationCallback[orderKey];
        }

        if (!noEmitEvent) {
            console.log("relayer emitting event"); //dklog
            emitFinalOrder(order, orderKey);
        }
    }

    // deleteErrOrder - deletes the pending order that has been validated to be erroneous by carbon and emits an error event
    function deleteErrOrder(
        string calldata orderKey_,
        string calldata error_
    ) external onlyOwner whenNotPaused {
        bool noEmitEvent = false;
        // purge the pending order and update with unprocessed status
        Order storage errOrder = pendingOrders[orderKey_];
        delete pendingOrders[orderKey_];
        errOrder.status = Status.Unprocessed;

        // Check for callback request
        OrderQuery memory req = orderCreationCallback[orderKey_];
        if (bytes(req.fnSigature).length > 0) {
            // Send the full order back to the caller or emit event on failure
            bytes memory encodedCall = abi.encodeWithSignature(
                req.fnSigature,
                errOrder,
                orderKey_
            );
            (noEmitEvent, ) = req.caller.call(encodedCall);

            delete orderCreationCallback[orderKey_];
        }

        if (!noEmitEvent) {
            emit OrderError(orderKey_, errOrder, error_);
        }
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
        MsgPositionQueryRes calldata msg_
    ) external onlyOwner whenNotPaused {
        PositionQuery memory queryReq = positionQueries[msg_.evmAddress];

        console.log("respondToPositionQuery\n", queryReq.fnSigature); //dklog
        bytes memory encodedCall = abi.encodeWithSignature(
            queryReq.fnSigature,
            msg_
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

    // queryOrder - query the order by orderKey and saves the callback fnSig
    // for call back to origin address
    function queryOrder(
        string calldata orderKey_,
        string calldata callbackSig_
    ) external whenNotPaused {
        OrderQuery memory orderQuery;
        orderQuery.caller = _msgSender();
        orderQuery.fnSigature = callbackSig_;
        console.log("received signature", callbackSig_);

        orderQueries[orderKey_] = orderQuery;
        console.log("Request logged");
    }

    // respondToOrderQuery - responds to the order query by calling the callback function
    // emit an event of the order details if the callback fails
    function respondToOrderQuery(
        MsgOrderQueryResponse memory msg_
    ) external whenNotPaused onlyOwner {
        OrderQuery memory queryReq = orderQueries[msg_.orderKey];

        console.log("respondToOrderQuery\n", queryReq.fnSigature); //dklog
        bytes memory encodedCall = abi.encodeWithSignature(
            queryReq.fnSigature,
            msg_.order,
            msg_.orderKey
        );

        (bool success, ) = queryReq.caller.call(encodedCall);
        if (!success) {
            emit FinalisedOrder(msg_.orderKey, msg_.order);
        }
        delete orderQueries[msg_.orderKey];
    }

    //Trial functions - sanity check
    function updateTestNumber(address evmAddr, uint8 testNumber_) external {
        // PositionQuery memory query = positionQueries[evmAddr];
        // console.log("relayer", testNumber_);
        // // This works must be exact name of function
        // query.caller.call(
        //     abi.encodeWithSignature(query.fnSigature, testNumber_)
        // );
    }

    function ping() public pure returns (string memory) {
        return "pong";
    }
}
