pragma solidity ^0.8.20;
import "lib/forge-std/src/Test.sol";
import { DefaultUpgrade } from "../../contracts/upgrades/DefaultUpgrade.sol";
import { ProposedUpgrade, BaseZkSyncUpgrade } from "../../contracts/upgrades/BaseZkSyncUpgrade.sol";
import { VerifierParams } from "../../contracts/state-transition/chain-interfaces/IVerifier.sol";
import { L2CanonicalTransaction } from "../../contracts/common/Messaging.sol";



contract DefaultUpgradeTest is Test {
    DefaultUpgrade defaultUpgrade;
    ProposedUpgrade proposal;
    bytes32 upgradeResult;

    function setUp() public {
        // Deploy DefaultUpgrade
        defaultUpgrade = new DefaultUpgrade();

        // Build minimal patch-only ProposedUpgrade
        proposal.upgradeTimestamp = block.timestamp;
        proposal.newProtocolVersion = 1; // SemVer.pack(0,0,1)
        proposal.bootloaderHash = bytes32(0);
        proposal.defaultAccountHash = bytes32(0);
        proposal.evmEmulatorHash = bytes32(0);
        proposal.verifier = address(0);
        proposal.verifierParams = VerifierParams({
            recursionNodeLevelVkHash: bytes32(0),
            recursionLeafLevelVkHash: bytes32(0),
            recursionCircuitsSetVksHash: bytes32(0)
        });
        proposal.l1ContractsUpgradeCalldata = bytes("");
        proposal.postUpgradeCalldata = bytes("");
        proposal.l2ProtocolUpgradeTx = L2CanonicalTransaction({
            txType: 0,
            from: 0,
            to: 0,
            gasLimit: 0,
            gasPerPubdataByteLimit: 0,
            maxFeePerGas: 0,
            maxPriorityFeePerGas: 0,
            paymaster: 0,
            nonce: 0,
            value: 0,
            reserved: [uint256(0), 0, 0, 0],
            data: bytes(""),
            signature: bytes(""),
            factoryDeps: new uint256[](0),
            paymasterInput: bytes(""),
            reservedDynamic: bytes("")
        });

        // Execute upgrade and capture return value
        upgradeResult = defaultUpgrade.upgrade(proposal);
    }

    function test_UpgradeReturnMatches() public {
        // Prepare a memory copy of the proposal with a higher patch version
        ProposedUpgrade memory p = proposal;
        p.upgradeTimestamp = block.timestamp;
        p.newProtocolVersion = 2;
        
        // Expect events for version bump and upgrade completion
        vm.expectEmit(true, true, false, false);
        emit BaseZkSyncUpgrade.NewProtocolVersion(1, 2);
        vm.expectEmit(true, true, false, false);
        emit BaseZkSyncUpgrade.UpgradeComplete(2, bytes32(0), p);
        
        // Act: execute the upgrade
        bytes32 ret = defaultUpgrade.upgrade(p);
        
        // Assert: return value matches the one captured in setUp
        assertEq(ret, upgradeResult);
        
    }



}
