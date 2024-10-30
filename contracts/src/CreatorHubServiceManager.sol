// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ECDSAServiceManagerBase} from
    "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {ECDSAUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {ICreatorHubServiceManager} from "./ICreatorHubServiceManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin-upgrades/contracts/utils/ContextUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Reclaim} from "./Reclaim/Reclaim.sol";
import {Claims} from "./Reclaim/Claims.sol";
import {Addresses} from "./Reclaim/Addresses.sol";


/**
 * @title Primary entrypoint for procuring services from HelloWorld.
 * @author Eigen Labs, Inc.
 */


contract CreatorHubServiceManager is ERC721URIStorage, OwnableUpgradeable, ECDSAServiceManagerBase, ICreatorHubServiceManager {
    using ECDSAUpgradeable for bytes32;

    uint32 public latestTaskNum;

    // mapping of task indices to all tasks hashes
    // when a task is created, task hash is stored here,
    // and responses need to pass the actual task,
    // which is hashed onchain and checked against this mapping
    mapping(uint32 => bytes32) public allTaskHashes;

    // mapping of task indices to hash of abi.encode(taskResponse, taskResponseMetadata)
    mapping(address => mapping(uint32 => bytes)) public allTaskResponses;

    modifier onlyOperator() {
        require(
            ECDSAStakeRegistry(stakeRegistry).operatorRegistered(msg.sender),
            "Operator must be the caller"
        );
        _;
    }

    constructor(
        address _avsDirectory,
        address _stakeRegistry,
        address _rewardsCoordinator,
        address _delegationManager

    )
        ECDSAServiceManagerBase(
            _avsDirectory,
            _stakeRegistry,
            _rewardsCoordinator,
            _delegationManager
        )

        ERC721("HelloWorldNFT", "HWNFT")
        OwnableUpgradeable()
    {}

    /* FUNCTIONS */
    // NOTE: this function creates new task, assigns it a taskId
    // creatorhub start here

    mapping(address => string) public userChannelID;

    function createTaskMintAccount(string memory channelID) external returns (CreatorTask memory) {
        // userChannelID[msg.sender] = channelID;
        CreatorTask memory creatorTask;
        creatorTask.channelID = channelID;
        creatorTask.taskCreatedBlock = uint32(block.number);

        // store hash of task onchain, emit event, and increase taskNum
        allTaskHashes[latestTaskNum] = keccak256(abi.encode(creatorTask));
        emit NewCreatorTaskCreated(latestTaskNum, creatorTask);
        latestTaskNum = latestTaskNum + 1;

        return creatorTask;
    }

    function respondToCreateMintAccountTask(CreatorTask calldata task, uint32 referenceTaskIndex, bytes memory signature, Reclaim.Proof memory proof, string memory tokenURI) external {
        require(
            keccak256(abi.encode(task)) == allTaskHashes[referenceTaskIndex],
            "supplied task does not match the one recorded in the contract"
        );
        require(
            allTaskResponses[msg.sender][referenceTaskIndex].length == 0,
            "Operator has already responded to the task"
        );

        // The message that was signed
        bytes32 messageHash = keccak256(abi.encodePacked("Hello, ", task.channelID));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        bytes4 magicValue = IERC1271Upgradeable.isValidSignature.selector;
        if (!(magicValue == ECDSAStakeRegistry(stakeRegistry).isValidSignature(ethSignedMessageHash,signature))){
            revert();
        }

        mintAccount(proof, tokenURI);

        // updating the storage with task responses
        allTaskResponses[msg.sender][referenceTaskIndex] = signature;

        // emitting event
        emit CreatorTaskResponded(referenceTaskIndex, task, msg.sender);
    }

    address public constant ownerAddress = 0x9443CF20fc0C1578c12792D8E80cA92DD4CEcc24;

    event Minted(address indexed to, uint256 indexed tokenId, string uri);
    event Burned(address indexed to, uint256 indexed tokenId);

    function mintAccount(Reclaim.Proof memory proof, string memory tokenURI) public {

        require(proof.signedClaim.claim.owner == ownerAddress, "Owner is not valid!");

        string memory videoId = Claims.extractFieldFromContext(proof.claimInfo.context, '"channelId":"');
        uint256 tokenId = uint256(keccak256(abi.encodePacked(videoId)));

        _safeMint(msg.sender, tokenId);
        
        // processAccount(tokenId, tokenURI);

        emit Minted(msg.sender, tokenId, tokenURI);
    }

    function checkExist(uint256 tokenId) public view returns (bool) {
        return ownerOf(tokenId) != address(0);
    }

    function processAccount(uint256 tokenId, string memory tokenURI) public {
        if (checkExist(tokenId)) {
            require(ownerOf(tokenId) == msg.sender, "Already minted by another address!");

            _burn(tokenId);
            emit Burned(msg.sender, tokenId);
        }
        mintNFT(tokenId, tokenURI);
    }

    function mintNFT(uint256 tokenId, string memory tokenURI) public {
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);
    }

    function _msgSender()
        internal
        view
        override(Context, ContextUpgradeable)
        returns (address sender)
    {
        sender = ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        override(Context, ContextUpgradeable)
        returns (bytes calldata)
    {
        return ContextUpgradeable._msgData();
    }

}
