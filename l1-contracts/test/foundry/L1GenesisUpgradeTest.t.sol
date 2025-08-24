pragma solidity ^0.8.20;
import "lib/forge-std/src/Test.sol";
import { L1GenesisUpgrade } from "../../contracts/upgrades/L1GenesisUpgrade.sol";
import { ProposedUpgrade, BaseZkSyncUpgrade } from "../../contracts/upgrades/BaseZkSyncUpgrade.sol";
import { L2CanonicalTransaction } from "../../contracts/common/Messaging.sol";
import { VerifierParams } from "../../contracts/state-transition/chain-interfaces/IVerifier.sol";



contract L1GenesisUpgradeTest is Test {
    L1GenesisUpgrade target;

    function setUp() public {
        target = new L1GenesisUpgrade();

        ProposedUpgrade memory pu;
        pu.upgradeTimestamp = 0;
        pu.newProtocolVersion = 0;
        pu.verifier = address(0);
        pu.verifierParams = VerifierParams({
            recursionNodeLevelVkHash: bytes32(0),
            recursionLeafLevelVkHash: bytes32(0),
            recursionCircuitsSetVksHash: bytes32(0)
        });
        pu.bootloaderHash = bytes32(0);
        pu.defaultAccountHash = bytes32(0);
        pu.evmEmulatorHash = bytes32(0);
        pu.l1ContractsUpgradeCalldata = bytes("");
        pu.postUpgradeCalldata = bytes("");

        L2CanonicalTransaction memory l2tx;
        l2tx.txType = 0;
        pu.l2ProtocolUpgradeTx = l2tx;

        target.upgrade(pu);
    }

    function test_UpgradeReturnsMagic() public {
        // Construct minimal ProposedUpgrade with noop L2 transaction and zeroed hashes and params
        ProposedUpgrade memory pu;
        pu.upgradeTimestamp = 0;
        pu.newProtocolVersion = 0;
        pu.verifier = address(0);
        pu.verifierParams = VerifierParams({recursionNodeLevelVkHash: bytes32(0), recursionLeafLevelVkHash: bytes32(0), recursionCircuitsSetVksHash: bytes32(0)});
        pu.bootloaderHash = bytes32(0);
        pu.defaultAccountHash = bytes32(0);
        pu.evmEmulatorHash = bytes32(0);
        pu.l1ContractsUpgradeCalldata = bytes("");
        pu.postUpgradeCalldata = bytes("");
        L2CanonicalTransaction memory l2tx;
        l2tx.txType = 0;
        pu.l2ProtocolUpgradeTx = l2tx;
        
        // Expect UpgradeComplete with version 0 and empty tx hash
        vm.expectEmit(true, true, false, false);
        emit BaseZkSyncUpgrade.UpgradeComplete(0, bytes32(0), pu);
        
        // Call upgrade and capture return value
        bytes32 ret = target.upgrade(pu);
        
        // Assert returned value is non-zero magic
        assertTrue(ret != bytes32(0));
        
    }



}