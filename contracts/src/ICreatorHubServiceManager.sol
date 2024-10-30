// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Reclaim} from "./Reclaim/Reclaim.sol";

interface ICreatorHubServiceManager {
    event NewCreatorTaskCreated(uint32 indexed taskIndex, CreatorTask task);

    event CreatorTaskResponded(uint32 indexed taskIndex, CreatorTask task, address operator);

    struct CreatorTask{
        string channelID;
        uint32 taskCreatedBlock;
    }

    function latestTaskNum() external view returns (uint32);

    function allTaskHashes(
        uint32 taskIndex
    ) external view returns (bytes32);

    function allTaskResponses(
        address operator,
        uint32 taskIndex
    ) external view returns (bytes memory);

    function createTaskMintAccount(
        string memory channelID
    ) external returns (CreatorTask memory);

    function respondToCreateMintAccountTask(
        CreatorTask calldata task,
        uint32 referenceTaskIndex,
        bytes calldata signature,
        Reclaim.Proof memory proof, 
        string memory tokenURI
    ) external;
}
