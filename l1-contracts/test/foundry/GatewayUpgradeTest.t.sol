pragma solidity ^0.8.20;
import "lib/forge-std/src/Test.sol";
import { GatewayUpgrade } from "../../contracts/upgrades/GatewayUpgrade.sol";
import { ProposedUpgrade, BaseZkSyncUpgrade } from "../../contracts/upgrades/BaseZkSyncUpgrade.sol";
import { L2CanonicalTransaction } from "../../contracts/common/Messaging.sol";
import { VerifierParams } from "../../contracts/state-transition/chain-interfaces/IVerifier.sol";
import { TimeNotReached } from "../../contracts/common/L1ContractErrors.sol";
import { ProtocolVersionTooSmall } from "../../contracts/upgrades/ZkSyncUpgradeErrors.sol";



contract GatewayUpgradeTest is Test {
    GatewayUpgrade gw;
    function setUp() public {
        // Deploy GatewayUpgrade and keep reference for subsequent calls
        gw = new GatewayUpgrade();

        // Assemble noop ProposedUpgrade to bypass validations
        ProposedUpgrade memory u = ProposedUpgrade({
            l2ProtocolUpgradeTx: L2CanonicalTransaction({
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
            }),
            bootloaderHash: bytes32(0),
            defaultAccountHash: bytes32(0),
            evmEmulatorHash: bytes32(0),
            verifier: address(0),
            verifierParams: VerifierParams({
                recursionNodeLevelVkHash: bytes32(0),
                recursionLeafLevelVkHash: bytes32(0),
                recursionCircuitsSetVksHash: bytes32(0)
            }),
            l1ContractsUpgradeCalldata: bytes(""),
            postUpgradeCalldata: bytes(""),
            upgradeTimestamp: 0,
            newProtocolVersion: 1
        });

        // Execute upgrade path; should not revert with noop tx
        gw.upgradeExternal(u);
    }

    function test_UpgradeExternal() public {
        // Cache current block timestamp
        uint256 nowTs = block.timestamp;
        
        // Build ProposedUpgrade with future timestamp to trigger TimeNotReached
        L2CanonicalTransaction memory l2tx = L2CanonicalTransaction({txType: 0, from: 0, to: 0, gasLimit: 0, gasPerPubdataByteLimit: 0, maxFeePerGas: 0, maxPriorityFeePerGas: 0, paymaster: 0, nonce: 0, value: 0, reserved: [uint256(0), 0, 0, 0], data: bytes(""), signature: bytes(""), factoryDeps: new uint256[](0), paymasterInput: bytes(""), reservedDynamic: bytes("")});
        ProposedUpgrade memory u = ProposedUpgrade({l2ProtocolUpgradeTx: l2tx, bootloaderHash: bytes32(0), defaultAccountHash: bytes32(0), evmEmulatorHash: bytes32(0), verifier: address(0), verifierParams: VerifierParams({recursionNodeLevelVkHash: bytes32(0), recursionLeafLevelVkHash: bytes32(0), recursionCircuitsSetVksHash: bytes32(0)}), l1ContractsUpgradeCalldata: bytes(""), postUpgradeCalldata: bytes(""), upgradeTimestamp: nowTs + 1, newProtocolVersion: 2});
        vm.expectRevert(abi.encodeWithSelector(TimeNotReached.selector, u.upgradeTimestamp, nowTs));
        gw.upgradeExternal(u);
        
        // Execute upgrade with current timestamp; expect UpgradeComplete with version=2 and txHash=0x0
        ProposedUpgrade memory u2 = u;
        u2.upgradeTimestamp = nowTs;
        vm.expectEmit(true, true, true, false);
        emit BaseZkSyncUpgrade.UpgradeComplete(2, bytes32(0), u2);
        gw.upgradeExternal(u2);
        
        // Retry upgrade with same version to ensure ProtocolVersionTooSmall reverts
        ProposedUpgrade memory u3 = u2;
        vm.expectRevert(ProtocolVersionTooSmall.selector);
        gw.upgradeExternal(u3);
        
    }



}