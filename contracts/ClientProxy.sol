// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OrdersRelayer.sol";
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
    mapping(string => OrdersRelayer.Order) public orders;

    OrdersRelayer orderRelayer; // OrdersRelayer contract

    uint8 public testNumber = 0;
    uint8 public testNumber2 = 0;

    constructor(address orderRelayerAddr_) {
        console.log(orderRelayerAddr_);
        orderRelayer = OrdersRelayer(orderRelayerAddr_);
    }

    function createProxyOrder(
        string calldata market_,
        OrdersRelayer.Side side_,
        uint256 quantity_,
        OrdersRelayer.OrderType orderType_,
        uint256 price_,
        bool isReduceOnly_,
        bool callback_
    ) public {
        string memory fnSignature = "";
        if (callback_) {
            fnSignature = "saveOrder((string,string,uint8,uint256,uint256,uint8,uint8,uint8,uint256,bool,address),string)";
        }
        orderRelayer.createOrder(
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
        OrdersRelayer.Order calldata order_,
        string calldata orderKey_
    ) public {
        console.log("order saving", orderKey_);
        console.log("order data", order_.id);
        orders["testOrder"] = order_;
    }

    function recievePosition(
        OrdersRelayer.MsgPositionQueryRes calldata msg_
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
        orderRelayer.queryAddressPosition(userAddr_, market_, fnSignature);
    }

    function requestForOrder(string calldata orderKey_) public {
        console.log("Requesting order in proxy\n");
        string
            memory fnSignature = "saveOrder((string,string,uint8,uint256,uint256,uint8,uint8,uint8,uint256,bool,address),string)";
        orderRelayer.queryOrder(orderKey_, fnSignature);
    }

    //Trial Functions
    function requestForNumber(address contractAddr, address user) public {
        string memory sig = "setTestNumber(uint8)";
        OrdersRelayer relayer = OrdersRelayer(contractAddr);
        relayer.queryAddressPosition(user, "test", sig);
    }

    function setTestNumber(uint8 testNumber_) public {
        console.log("setTestNumber", testNumber_);
        testNumber = testNumber_;
        testNumber2 = 10;
    }

    function ping() public pure returns (string memory) {
        return "pong";
    }
}
