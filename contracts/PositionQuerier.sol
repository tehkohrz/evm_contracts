// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./@openzeppelin/contracts/access/Ownable.sol";
import "./@openzeppelin/contracts/security/Pausable.sol";
import "./CreateOrders.sol";

contract PositionQuerier is Ownable, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct PositionQuery {
        string market;
        address caller;
        string fnSigature;
    }

    struct MsgPositionQueryRes {
        address evmAddress;
        string market;
        string carbonAddress;
        int256 lots;
        uint256 entryPrice;
        int256 realizedPnl;
        string allocatedMarginDenom;
        uint256 allocatedMarginAmount;
        uint256 openedBlockHeight;
    }

    // =============Storage==============
    // @notice Id of the contract to easier identify the contract and account of multiple contract for different kinds of orders
    string public contractId;
    //@notice Flag to indicate if the contract is active, for info only all methods are blocked by pausable
    bool public isActive;
    // @notice Number of decimals for conversion of all integer values type decimals
    uint64 public decimals;

    // @notice Mapping of account address to position query request
    mapping(address => PositionQuery) public positionQueries;
    // @notice Set of postionQueryKeys used to track and purge the map to prevent bloat
    EnumerableSet.AddressSet positionQueryKeys;

    // =============Events================

    // @notice event for position query request to carbon
    // @param market - market name the position is in
    // @param account - evm address of the position's account
    // @param contractId - id of the contract for carbon to track the contract to update
    event PositionQueryRequest(
        string market,
        address accountAddress,
        string contractId
    );

    // @notice event for position query response as a back up for callback
    event PositionQueryResponse(MsgPositionQueryRes msg);

    // @param evmAddr - addresss of the position queried
    // @param errPos - fields of the position queries for easier reference to query
    // @param error - error message from evm integration of order module
    event PositionError(
        address evmAddr,
        MsgPositionQueryRes errPos,
        string error
    );

    constructor(string memory contractId_, uint64 decimals_) {
        contractId = contractId_;
        decimals = decimals_;
        isActive = true;
    }

    // @notice registers the position query request from the client and saves the required details
    // @param accountAddress_ - evm address of the position to query
    // @param market_ - market name of the position to query
    // @param callbackSig_ - signature of the callback function to return response
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
        EnumerableSet.add(positionQueryKeys, accountAddress_);

        emit PositionQueryRequest(market_, accountAddress_, contractId);
    }

    // @notice Called by carbon to relay the response after processing query
    function respondToPositionQuery(
        MsgPositionQueryRes calldata msg_
    ) external onlyOwner whenNotPaused {
        PositionQuery memory queryReq = positionQueries[msg_.evmAddress];
        bool noEmitEvent = true;
        if (bytes(queryReq.fnSigature).length > 0) {
            bytes memory encodedCall = abi.encodeWithSignature(
                queryReq.fnSigature,
                msg_
            );

            // no need return value of call since it is a fire and forget but send an event so the caller
            // can still check for the position in another way
            (noEmitEvent, ) = queryReq.caller.call(encodedCall);
        }
        if (!noEmitEvent) {
            emit PositionQueryResponse(msg_);
        }
        positionQueries[msg_.evmAddress] = queryReq;
        // remove the query from the store
        delete positionQueries[msg_.evmAddress];
        EnumerableSet.remove(positionQueryKeys, msg_.evmAddress);
    }

    // @notice Responds to the position query with an error message in carbon address field
    // @dev emits a position error event if callback fn not provided or failed
    // @param evmAddr_ - evm address of the position to query
    // @param error_ - error message returned from evm integration of order module
    function deletePositionQuery(
        address evmAddr_,
        string calldata error_
    ) external onlyOwner {
        bool noEmitEvent = false;
        // purge the pending order and update with unprocessed status
        PositionQuery storage queryReq = positionQueries[evmAddr_];

        // Callback expecting the same format, send back the format with error
        MsgPositionQueryRes memory errPos = MsgPositionQueryRes(
            evmAddr_,
            queryReq.market,
            error_,
            0,
            0,
            0,
            "",
            0,
            0
        );
        // Check for callback request
        if (bytes(queryReq.fnSigature).length > 0) {
            bytes memory encodedCall = abi.encodeWithSignature(
                queryReq.fnSigature,
                errPos
            );
            (noEmitEvent, ) = queryReq.caller.call(encodedCall);
        }

        if (!noEmitEvent) {
            emit PositionError(evmAddr_, errPos, error_);
        }

        EnumerableSet.remove(positionQueryKeys, evmAddr_);
        delete positionQueries[evmAddr_];
    }

    // @notice purge all the lingering position queries from map and set
    function purgePositionQueriesStore() external onlyOwner {
        address[] memory keysArr = EnumerableSet.values(positionQueryKeys);
        for (uint i = 0; i < keysArr.length; i += 1) {
            delete positionQueries[keysArr[i]];
            EnumerableSet.remove(positionQueryKeys, keysArr[i]);
        }
    }

    // @notice deactivates the contract and updates the public active flag
    function deActivateContract() external onlyOwner {
        _pause();
        isActive = false;
    }

    // @notice reactivates the contract and updates the public active flag
    function activateContract() external onlyOwner {
        _unpause();
        isActive = true;
    }

    //todo: remove after tests have been written DKLOG
    function ping() public pure returns (string memory) {
        return "pong";
    }
}
