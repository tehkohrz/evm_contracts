// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CreateOrders.sol";
import "./PositionQuerier.sol";
import "./OrdersQuerier.sol";
import "hardhat/console.sol";

contract ClientProxy {
    struct Position {
        string market;
        string accountAddress;
        int256 lots;
        uint256 entryPrice;
        int256 realizedPnl;
        string allocatedMarginDenom;
        uint256 allocatedMarginAmount;
        uint256 openedBlockHeight;
    }

    mapping(address => Position) public positions;
    mapping(string => CreateOrders.Order) public orders;

    CreateOrders createOrders; // CreateOrders contract
    OrdersQuerier ordersQuerier; // OrdersQuerier contract
    PositionQuerier positionQuerier; // PositionQuerier contract

    uint8 public testNumber = 0;
    uint8 public testNumber2 = 0;

    constructor(
        address createOrdersAddr_,
        address ordersQuerierAddr_,
        address positionQuerierAddr_
    ) {
        createOrders = CreateOrders(createOrdersAddr_);
        ordersQuerier = OrdersQuerier(ordersQuerierAddr_);
        positionQuerier = PositionQuerier(positionQuerierAddr_);
    }

    function createProxyOrder(
        string calldata market_,
        CreateOrders.Side side_,
        uint256 quantity_,
        CreateOrders.OrderType orderType_,
        uint256 price_,
        bool isReduceOnly_,
        bool callback_
    ) public {
        string memory fnSignature = "";
        if (callback_) {
            fnSignature = "saveOrder((string,string,uint8,uint256,uint256,uint8,uint8,uint8,uint256,bool,address),string)";
        }
        createOrders.createOrder(
            market_,
            side_,
            quantity_,
            orderType_,
            price_,
            isReduceOnly_,
            fnSignature
        );
    }

    function saveOrder(
        CreateOrders.Order calldata order_,
        string calldata orderKey_
    ) public {
        console.log("order saving", orderKey_);
        console.log("order data", order_.id);
        orders[orderKey_] = order_;
    }

    function recievePosition(
        PositionQuerier.MsgPositionQueryRes calldata msg_
    ) public {
        console.log("message updated in proxy");
        Position memory updatedPosition = Position(
            msg_.market,
            msg_.carbonAddress,
            msg_.lots,
            msg_.entryPrice,
            msg_.realizedPnl,
            msg_.allocatedMarginDenom,
            msg_.allocatedMarginAmount,
            msg_.openedBlockHeight
        );
        positions[msg_.evmAddress] = updatedPosition;
    }

    function requestForPosition(
        address userAddr_,
        string calldata market_
    ) public {
        console.log("Requesting position in proxy\n");
        string
            memory fnSignature = "recievePosition((address,string,string,int256,uint256,int256,string,uint256,uint256))";
        positionQuerier.queryAddressPosition(userAddr_, market_, fnSignature);
    }

    function requestForOrder(string calldata orderKey_) public {
        console.log("Requesting order in proxy\n");
        string
            memory fnSignature = "saveOrder((string,string,uint8,uint256,uint256,uint8,uint8,uint8,uint256,bool,address),string)";
        ordersQuerier.queryOrder(orderKey_, fnSignature);
    }

    function ping() public pure returns (string memory) {
        return "pong";
    }
}
