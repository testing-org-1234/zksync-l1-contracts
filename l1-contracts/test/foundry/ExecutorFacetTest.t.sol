pragma solidity ^0.8.20;
import "lib/forge-std/src/Test.sol";
import { ExecutorFacet } from "../../contracts/state-transition/chain-deps/facets/Executor.sol";
import { IExecutor } from "../../contracts/state-transition/chain-interfaces/IExecutor.sol";
import { InvalidProtocolVersion, CanOnlyProcessOneBatch, BatchHashMismatch } from "../../contracts/common/L1ContractErrors.sol";



contract ExecutorFacetTest is Test {
    ExecutorFacet internal executor;
    address internal validator;
    bytes internal commitDataBytes;

    bytes32 internal constant VALIDATORS_SLOT = bytes32(uint256(0x100));
    bytes32 internal constant CHAIN_TYPE_MANAGER_SLOT = bytes32(uint256(0x101));
    bytes32 internal constant STORED_BATCH_HASHES_SLOT = bytes32(uint256(0x102));
    bytes32 internal constant TOTAL_BATCHES_COMMITTED_SLOT = bytes32(uint256(0x103));
    bytes32 internal constant SETTLEMENT_LAYER_SLOT = bytes32(uint256(0x104));

    function setUp() public {
        // 1) Deploy ExecutorFacet with configured L1 chain identifier
        executor = new ExecutorFacet(block.chainid);

        // 2) Initialize nonReentrant lock slot to NOT_ENTERED (1)
        vm.store(
            address(executor),
            bytes32(0x8e94fed44239eb2314ab7a406345e6c5a8f0ccedf3b600de3d004e672c33abf4),
            bytes32(uint256(1))
        );

        // 3) Activate validator role for chosen caller address
        validator = makeAddr("validator");
        bytes32 validatorSlot = keccak256(abi.encode(validator, VALIDATORS_SLOT));
        vm.store(address(executor), validatorSlot, bytes32(uint256(1)));

        // 4) Set chainTypeManager to mock address
        address chainTypeManagerMock = makeAddr("ChainTypeManagerMock");
        vm.store(
            address(executor),
            CHAIN_TYPE_MANAGER_SLOT,
            bytes32(uint256(uint160(chainTypeManagerMock)))
        );

        // 5) Seed storedBatchHashes[0] and ensure totalBatchesCommitted is 0
        IExecutor.StoredBatchInfo memory lastCommittedBatchData = IExecutor.StoredBatchInfo({
            batchNumber: uint64(0),
            batchHash: bytes32(0),
            indexRepeatedStorageChanges: uint64(0),
            numberOfLayer1Txs: uint256(0),
            priorityOperationsHash: bytes32(0),
            l2LogsTreeRoot: bytes32(0),
            timestamp: uint256(block.timestamp),
            commitment: bytes32(0)
        });
        bytes32 lastHash = keccak256(abi.encode(lastCommittedBatchData));
        bytes32 storedHashSlot = keccak256(abi.encode(uint256(0), STORED_BATCH_HASHES_SLOT));
        vm.store(address(executor), storedHashSlot, lastHash);
        vm.store(address(executor), TOTAL_BATCHES_COMMITTED_SLOT, bytes32(uint256(0)));

        // 6) Prepare valid commitData encoding one batch
        IExecutor.CommitBatchInfo[] memory newBatches = new IExecutor.CommitBatchInfo[](1);
        newBatches[0] = IExecutor.CommitBatchInfo({
            batchNumber: uint64(1),
            timestamp: uint64(block.timestamp),
            indexRepeatedStorageChanges: uint64(0),
            newStateRoot: bytes32(uint256(1)),
            numberOfLayer1Txs: uint256(0),
            priorityOperationsHash: bytes32(uint256(2)),
            bootloaderHeapInitialContentsHash: bytes32(0),
            eventsQueueStateHash: bytes32(0),
            systemLogs: "",
            operatorDAInput: ""
        });
        commitDataBytes = abi.encodePacked(uint8(0), abi.encode(lastCommittedBatchData, newBatches));

        // 7) Ensure settlementLayer equals zero
        vm.store(address(executor), SETTLEMENT_LAYER_SLOT, bytes32(uint256(0)));
    }
    
    function test_CommitBatchesGuards() public {
        // Step 1: Protocol version inactive should revert
        bytes32 selfValidatorSlot = keccak256(abi.encode(address(this), VALIDATORS_SLOT));
        vm.store(address(executor), selfValidatorSlot, bytes32(uint256(1)));
        address ctmFalse = makeAddr("ChainTypeManagerFalse");
        bytes memory codeFalse = hex"600060005260206000f3";
        vm.etch(ctmFalse, codeFalse);
        vm.store(address(executor), CHAIN_TYPE_MANAGER_SLOT, bytes32(uint256(uint160(ctmFalse))));
        
        vm.expectRevert(InvalidProtocolVersion.selector);
        executor.commitBatchesSharedBridge(block.chainid, 1, 1, commitDataBytes);
        
        // Step 2: Allow protocol version, but provide two batches to trigger CanOnlyProcessOneBatch
        address ctmTrue = makeAddr("ChainTypeManagerTrue");
        bytes memory codeTrue = hex"600160005260206000f3";
        vm.etch(ctmTrue, codeTrue);
        vm.store(address(executor), CHAIN_TYPE_MANAGER_SLOT, bytes32(uint256(uint160(ctmTrue))));
        
        IExecutor.StoredBatchInfo memory lastCommittedBatchData = IExecutor.StoredBatchInfo({
            batchNumber: uint64(0),
            batchHash: bytes32(0),
            indexRepeatedStorageChanges: uint64(0),
            numberOfLayer1Txs: uint256(0),
            priorityOperationsHash: bytes32(0),
            l2LogsTreeRoot: bytes32(0),
            timestamp: uint256(block.timestamp),
            commitment: bytes32(0)
        });
        IExecutor.CommitBatchInfo[] memory newBatchesTwo = new IExecutor.CommitBatchInfo[](2);
        newBatchesTwo[0] = IExecutor.CommitBatchInfo({
            batchNumber: uint64(1),
            timestamp: uint64(block.timestamp),
            indexRepeatedStorageChanges: uint64(0),
            newStateRoot: bytes32(uint256(1)),
            numberOfLayer1Txs: uint256(0),
            priorityOperationsHash: bytes32(uint256(2)),
            bootloaderHeapInitialContentsHash: bytes32(0),
            eventsQueueStateHash: bytes32(0),
            systemLogs: "",
            operatorDAInput: ""
        });
        newBatchesTwo[1] = IExecutor.CommitBatchInfo({
            batchNumber: uint64(2),
            timestamp: uint64(block.timestamp + 1),
            indexRepeatedStorageChanges: uint64(0),
            newStateRoot: bytes32(uint256(1)),
            numberOfLayer1Txs: uint256(0),
            priorityOperationsHash: bytes32(uint256(2)),
            bootloaderHeapInitialContentsHash: bytes32(0),
            eventsQueueStateHash: bytes32(0),
            systemLogs: "",
            operatorDAInput: ""
        });
        bytes memory commitDataTwo = abi.encodePacked(uint8(0), abi.encode(lastCommittedBatchData, newBatchesTwo));
        
        vm.expectRevert(CanOnlyProcessOneBatch.selector);
        executor.commitBatchesSharedBridge(block.chainid, 1, 2, commitDataTwo);
        
        // Step 3: Mismatch previous batch data to trigger BatchHashMismatch
        IExecutor.StoredBatchInfo memory mismatchedLast = lastCommittedBatchData;
        mismatchedLast.timestamp = lastCommittedBatchData.timestamp + 1;
        IExecutor.CommitBatchInfo[] memory newBatchesOne = new IExecutor.CommitBatchInfo[](1);
        newBatchesOne[0] = IExecutor.CommitBatchInfo({
            batchNumber: uint64(1),
            timestamp: uint64(block.timestamp),
            indexRepeatedStorageChanges: uint64(0),
            newStateRoot: bytes32(uint256(1)),
            numberOfLayer1Txs: uint256(0),
            priorityOperationsHash: bytes32(uint256(2)),
            bootloaderHeapInitialContentsHash: bytes32(0),
            eventsQueueStateHash: bytes32(0),
            systemLogs: "",
            operatorDAInput: ""
        });
        bytes memory badCommit = abi.encodePacked(uint8(0), abi.encode(mismatchedLast, newBatchesOne));
        
        vm.expectRevert(BatchHashMismatch.selector);
        executor.commitBatchesSharedBridge(block.chainid, 1, 1, badCommit);
        
    }



}