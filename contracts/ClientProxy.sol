// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OrdersRelayer.sol";
import "hardhat/console.sol";

contract ClientProxy {
    mapping(address => OrdersRelayer.Position) public positions;

    uint8 public testNumber = 0;
    uint8 public testNumber2 = 0;

    function recievePosition(
        OrdersRelayer.MsgPositionUpdate calldata msg_
    ) public {
        console.log("message updated in proxy");
        OrdersRelayer.Position memory updatedPosition = OrdersRelayer.Position(
            msg_.market,
            msg_.accountAddress,
            msg_.lots,
            msg_.entryPrice,
            msg_.realisedPnl,
            msg_.marginDenom,
            msg_.marginAmount,
            msg_.openBlockHeight
        );
        string memory test = updatedPosition.accountAddress;
        console.log("data recieved", test);
        positions[msg_.evmAddress] = updatedPosition;
    }

    function requestForPosition(
        address contractAddr_,
        address userAddr_,
        string calldata market_
    ) public {
        OrdersRelayer relayer = OrdersRelayer(contractAddr_);
        console.log("Requesting in proxy\n");
        string
            memory fnSignature = "recievePosition(address,string,string,int256,uint256,int256,string,uint256,uint256)";
        relayer.queryAddressPosition(userAddr_, market_, fnSignature);
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