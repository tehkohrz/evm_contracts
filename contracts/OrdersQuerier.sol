// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./@openzeppelin/contracts/access/Ownable.sol";
import "./@openzeppelin/contracts/security/Pausable.sol";
import "./CreateOrders.sol";

contract OrdersQuerier is Ownable, Pausable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct OrderQuery {
        address caller;
        string fnSigature;
    }

    struct MsgOrderQueryResponse {
        string orderKey;
        CreateOrders.Order order;
    }

    // =============Storage==============
    // @notice Id of the contract to easier identify the contract and account of multiple contract for different kinds of orders
    string public contractId;
    //@notice Flag to indicate if the contract is active, for info only all methods are blocked by pausable
    bool public isActive;
    // @notice Number of decimals for conversion of all integer values type decimals
    uint64 public decimals;

    // @notice Mapping of orderKey to order query request
    mapping(string => OrderQuery) public orderQueries;
    // @notice Set of orderQuerykeys used to track and purge the map to prevent bloat
    EnumerableSet.Bytes32Set orderQueryKeys;

    // =============Events================

    // @notice event to update the finalised order details as a back up for callback
    // @param orderKey - evmKey of the order
    // @param order - update order after processed by carbon broker
    event FinalisedOrder(string orderKey, CreateOrders.Order order);

    // @notice event for order query request to carbon
    // @param orderKey - evmKey of the order
    event OrderQueryRequest(string orderKey, string contractId);

    // @param orderKey - evmKey of the order
    // @param order - order that has failed and not processed by carbon broker
    // @param error - error message from evm integration of order module
    event OrderError(
        string orderKey,
        CreateOrders.Order errOrder,
        string error
    );

    constructor(string memory contractId_, uint64 decimals_) {
        contractId = contractId_;
        decimals = decimals_;
        isActive = true;
    }

    // @notice registers the order query request from the client and saves the required details
    // @dev mapping of the evm orderKey is persisted in the store of carbon
    // @param orderKey_ - evm key of the order to query
    // @param callbackSig_ - signature of the callback function to return response
    function queryOrder(
        string calldata orderKey_,
        string calldata callbackSig_
    ) external whenNotPaused {
        OrderQuery memory orderQuery;
        orderQuery.caller = _msgSender();
        orderQuery.fnSigature = callbackSig_;

        orderQueries[orderKey_] = orderQuery;
        EnumerableSet.add(
            orderQueryKeys,
            keccak256(abi.encodePacked(orderKey_))
        );

        emit OrderQueryRequest(orderKey_, contractId);
    }

    // @notice Called by carbon to relay the order response after processing query
    function respondToOrderQuery(
        MsgOrderQueryResponse memory msg_
    ) external whenNotPaused onlyOwner {
        OrderQuery memory queryReq = orderQueries[msg_.orderKey];

        // check if there is a callback provided
        bool noEmitEvent = true;
        if (bytes(queryReq.fnSigature).length > 0) {
            bytes memory encodedCall = abi.encodeWithSignature(
                queryReq.fnSigature,
                msg_.order,
                msg_.orderKey
            );

            (noEmitEvent, ) = queryReq.caller.call(encodedCall);
        }
        if (!noEmitEvent) {
            emit FinalisedOrder(msg_.orderKey, msg_.order);
        }

        delete orderQueries[msg_.orderKey];
        EnumerableSet.add(
            orderQueryKeys,
            keccak256(abi.encodePacked(msg_.orderKey))
        );
    }

    // @notice Responds to the order query with an error message in order id
    // @dev emits a position error event if callback fn not provided or failed
    // @param evmAddr_ - evm address of the position to query
    // @param error_ - error message returned from evm integration of order module
    function deleteOrderQuery(
        string calldata orderKey_,
        string calldata error_
    ) external onlyOwner {
        OrderQuery memory queryReq = orderQueries[orderKey_];
        bool noEmitEvent = false;

        // Form error order
        CreateOrders.Order memory errOrder;
        errOrder.id = error_;

        if (bytes(queryReq.fnSigature).length > 0) {
            bytes memory encodedCall = abi.encodeWithSignature(
                queryReq.fnSigature,
                errOrder,
                orderKey_
            );

            (noEmitEvent, ) = queryReq.caller.call(encodedCall);
        }
        if (!noEmitEvent) {
            emit OrderError(orderKey_, errOrder, error_);
        }

        delete orderQueries[orderKey_];
        EnumerableSet.add(
            orderQueryKeys,
            keccak256(abi.encodePacked(orderKey_))
        );
    }

    // @notice purge all the lingering order queries from map and set
    function purgeOrderQueriesStore() external onlyOwner {
        bytes32[] memory keysArr = EnumerableSet.values(orderQueryKeys);
        for (uint i = 0; i < keysArr.length; i += 1) {
            delete orderQueries[string(abi.encodePacked(keysArr[i]))];
            EnumerableSet.remove(orderQueryKeys, keysArr[i]);
        }
    }

    // @ntoice deactivates the contract and updates the public active flag
    function deActivateContract() external onlyOwner {
        _pause();
        isActive = false;
    }

    // @ntoice reactivates the contract and updates the public active flag
    function activateContract() external onlyOwner {
        _unpause();
        isActive = true;
    }

    //todo: remove after tests have been written DKLOG
    function ping() public pure returns (string memory) {
        return "pong";
    }
}
