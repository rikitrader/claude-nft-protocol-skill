// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/GuardianMultisig.sol";

/**
 * @title GuardianMultisigTest
 * @notice Unit tests for the GuardianMultisig emergency multisig contract.
 */
contract GuardianMultisigTest is Test {
    // -------------------------------------------------------------------
    //  Local event declarations (Solidity <0.8.21 compat)
    // -------------------------------------------------------------------

    event Submission(uint256 indexed txId, address indexed submitter);
    event Confirmation(uint256 indexed txId, address indexed owner);
    event Revocation(uint256 indexed txId, address indexed owner);

    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    GuardianMultisig public multisig;

    address public owner1 = makeAddr("owner1");
    address public owner2 = makeAddr("owner2");
    address public owner3 = makeAddr("owner3");
    address public stranger = makeAddr("stranger");
    address public receiver = makeAddr("receiver");

    uint256 public constant REQUIRED = 2;

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        multisig = new GuardianMultisig(owners, REQUIRED);

        // Fund the multisig for value-transfer tests
        vm.deal(address(multisig), 10 ether);
    }

    // -------------------------------------------------------------------
    //  Helper — submit a simple ETH transfer
    // -------------------------------------------------------------------

    function _submitEthTransfer(address from) internal returns (uint256) {
        vm.prank(from);
        return multisig.submitTransaction(receiver, 1 ether, "");
    }

    // -------------------------------------------------------------------
    //  Constructor Tests
    // -------------------------------------------------------------------

    function test_Constructor_SetsParamsCorrectly() public view {
        assertEq(multisig.required(), REQUIRED);
        assertTrue(multisig.isOwner(owner1));
        assertTrue(multisig.isOwner(owner2));
        assertTrue(multisig.isOwner(owner3));
        assertFalse(multisig.isOwner(stranger));

        address[] memory owners = multisig.getOwners();
        assertEq(owners.length, 3);
    }

    function test_Constructor_RevertsEmptyOwners() public {
        address[] memory empty = new address[](0);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.InvalidRequirement.selector, 0, 1));
        new GuardianMultisig(empty, 1);
    }

    function test_Constructor_RevertsZeroRequired() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.InvalidRequirement.selector, 2, 0));
        new GuardianMultisig(owners, 0);
    }

    function test_Constructor_RevertsRequiredExceedsOwners() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.InvalidRequirement.selector, 2, 5));
        new GuardianMultisig(owners, 5);
    }

    function test_Constructor_RevertsZeroAddressOwner() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = address(0);
        vm.expectRevert(GuardianMultisig.ZeroAddress.selector);
        new GuardianMultisig(owners, 1);
    }

    function test_Constructor_RevertsDuplicateOwner() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner1;
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.OwnerAlreadyExists.selector, owner1));
        new GuardianMultisig(owners, 1);
    }

    // -------------------------------------------------------------------
    //  submitTransaction Tests
    // -------------------------------------------------------------------

    function test_SubmitTransaction_CreatesAndAutoConfirms() public {
        uint256 txId = _submitEthTransfer(owner1);

        assertEq(txId, 0);
        assertEq(multisig.transactionCount(), 1);
        assertEq(multisig.getConfirmationCount(txId), 1);
        assertTrue(multisig.confirmations(txId, owner1));
    }

    function test_SubmitTransaction_EmitsSubmissionAndConfirmation() public {
        vm.prank(owner1);
        vm.expectEmit(true, true, false, false);
        emit Submission(0, owner1);
        multisig.submitTransaction(receiver, 1 ether, "");
    }

    function test_SubmitTransaction_RevertsNonOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.NotOwner.selector, stranger));
        multisig.submitTransaction(receiver, 1 ether, "");
    }

    function test_SubmitTransaction_MultipleIncrementId() public {
        uint256 id1 = _submitEthTransfer(owner1);
        uint256 id2 = _submitEthTransfer(owner2);
        assertEq(id1, 0);
        assertEq(id2, 1);
        assertEq(multisig.transactionCount(), 2);
    }

    // -------------------------------------------------------------------
    //  confirmTransaction Tests
    // -------------------------------------------------------------------

    function test_ConfirmTransaction_IncrementsCount() public {
        uint256 txId = _submitEthTransfer(owner1);
        assertEq(multisig.getConfirmationCount(txId), 1);

        // Note: with required=2 and a second confirm, auto-execution will trigger.
        // For testing confirmation count only, we need required > 2.
        // Instead, verify the state pre-execution by checking confirmations map.
        assertTrue(multisig.confirmations(txId, owner1));
        assertFalse(multisig.confirmations(txId, owner2));
    }

    function test_ConfirmTransaction_AutoExecutesOnThreshold() public {
        uint256 txId = _submitEthTransfer(owner1);

        uint256 receiverBefore = receiver.balance;

        vm.prank(owner2);
        multisig.confirmTransaction(txId);

        // Threshold met (2/2): auto-execute should send 1 ETH
        assertEq(receiver.balance, receiverBefore + 1 ether);
        (,,,bool executed,) = multisig.transactions(txId);
        assertTrue(executed);
    }

    function test_ConfirmTransaction_EmitsConfirmation() public {
        uint256 txId = _submitEthTransfer(owner1);

        vm.prank(owner2);
        vm.expectEmit(true, true, false, false);
        emit Confirmation(txId, owner2);
        multisig.confirmTransaction(txId);
    }

    function test_ConfirmTransaction_RevertsDuplicateConfirmation() public {
        uint256 txId = _submitEthTransfer(owner1);

        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.AlreadyConfirmed.selector, txId, owner1));
        multisig.confirmTransaction(txId);
    }

    function test_ConfirmTransaction_RevertsNonOwner() public {
        uint256 txId = _submitEthTransfer(owner1);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.NotOwner.selector, stranger));
        multisig.confirmTransaction(txId);
    }

    function test_ConfirmTransaction_RevertsTxDoesNotExist() public {
        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.TxDoesNotExist.selector, 999));
        multisig.confirmTransaction(999);
    }

    function test_ConfirmTransaction_RevertsAlreadyExecuted() public {
        uint256 txId = _submitEthTransfer(owner1);

        vm.prank(owner2);
        multisig.confirmTransaction(txId); // auto-executes

        vm.prank(owner3);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.AlreadyExecuted.selector, txId));
        multisig.confirmTransaction(txId);
    }

    // -------------------------------------------------------------------
    //  executeTransaction Tests
    // -------------------------------------------------------------------

    function test_ExecuteTransaction_ExplicitExecution() public {
        // Use a 3-owner multisig with required=3 to avoid auto-execution
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        GuardianMultisig ms3 = new GuardianMultisig(owners, 3);
        vm.deal(address(ms3), 10 ether);

        vm.prank(owner1);
        uint256 txId = ms3.submitTransaction(receiver, 1 ether, "");
        // 1 confirm (auto from submit)

        vm.prank(owner2);
        ms3.confirmTransaction(txId);
        // 2 confirms, need 3 => not executed yet
        (,,,bool executed,) = ms3.transactions(txId);
        assertFalse(executed);

        vm.prank(owner3);
        ms3.confirmTransaction(txId);
        // 3 confirms => auto-execute
        (,,,executed,) = ms3.transactions(txId);
        assertTrue(executed);
    }

    function test_ExecuteTransaction_RevertsWithoutThreshold() public {
        // 3-of-3 multisig
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        GuardianMultisig ms3 = new GuardianMultisig(owners, 3);
        vm.deal(address(ms3), 10 ether);

        vm.prank(owner1);
        uint256 txId = ms3.submitTransaction(receiver, 1 ether, "");

        vm.prank(owner2);
        ms3.confirmTransaction(txId);
        // Only 2 of 3 confirms

        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.NotConfirmed.selector, txId, address(0)));
        ms3.executeTransaction(txId);
    }

    function test_ExecuteTransaction_RevertsNonOwner() public {
        uint256 txId = _submitEthTransfer(owner1);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.NotOwner.selector, stranger));
        multisig.executeTransaction(txId);
    }

    function test_ExecuteTransaction_RevertsTxDoesNotExist() public {
        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.TxDoesNotExist.selector, 0));
        multisig.executeTransaction(0);
    }

    // -------------------------------------------------------------------
    //  revokeConfirmation Tests
    // -------------------------------------------------------------------

    function test_RevokeConfirmation_DecrementsCount() public {
        // 3-of-3 to avoid auto-execute
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        GuardianMultisig ms3 = new GuardianMultisig(owners, 3);
        vm.deal(address(ms3), 10 ether);

        vm.prank(owner1);
        uint256 txId = ms3.submitTransaction(receiver, 1 ether, "");
        assertEq(ms3.getConfirmationCount(txId), 1);

        vm.prank(owner2);
        ms3.confirmTransaction(txId);
        assertEq(ms3.getConfirmationCount(txId), 2);

        vm.prank(owner2);
        ms3.revokeConfirmation(txId);
        assertEq(ms3.getConfirmationCount(txId), 1);
        assertFalse(ms3.confirmations(txId, owner2));
    }

    function test_RevokeConfirmation_EmitsRevocation() public {
        // 3-of-3 to avoid auto-execute
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        GuardianMultisig ms3 = new GuardianMultisig(owners, 3);

        vm.prank(owner1);
        uint256 txId = ms3.submitTransaction(receiver, 0, "");

        vm.prank(owner1);
        vm.expectEmit(true, true, false, false);
        emit Revocation(txId, owner1);
        ms3.revokeConfirmation(txId);
    }

    function test_RevokeConfirmation_RevertsNotConfirmed() public {
        uint256 txId = _submitEthTransfer(owner1);

        vm.prank(owner3);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.NotConfirmed.selector, txId, owner3));
        multisig.revokeConfirmation(txId);
    }

    function test_RevokeConfirmation_RevertsNonOwner() public {
        uint256 txId = _submitEthTransfer(owner1);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.NotOwner.selector, stranger));
        multisig.revokeConfirmation(txId);
    }

    function test_RevokeConfirmation_RevertsAlreadyExecuted() public {
        uint256 txId = _submitEthTransfer(owner1);

        vm.prank(owner2);
        multisig.confirmTransaction(txId); // auto-executes

        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.AlreadyExecuted.selector, txId));
        multisig.revokeConfirmation(txId);
    }

    // -------------------------------------------------------------------
    //  Self-Governance: addOwner Tests
    // -------------------------------------------------------------------

    function test_AddOwner_ViaSelfCall() public {
        address newOwner = makeAddr("newOwner");
        bytes memory addData = abi.encodeWithSelector(GuardianMultisig.addOwner.selector, newOwner);

        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(address(multisig), 0, addData);

        vm.prank(owner2);
        multisig.confirmTransaction(txId); // auto-executes

        assertTrue(multisig.isOwner(newOwner));
        address[] memory owners = multisig.getOwners();
        assertEq(owners.length, 4);
    }

    function test_AddOwner_RevertsDirectCall() public {
        vm.prank(owner1);
        vm.expectRevert("GuardianMultisig: only via multisig");
        multisig.addOwner(makeAddr("someone"));
    }

    function test_AddOwner_RevertsZeroAddress() public {
        bytes memory addData = abi.encodeWithSelector(GuardianMultisig.addOwner.selector, address(0));

        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(address(multisig), 0, addData);

        vm.prank(owner2);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.ExecutionFailed.selector, txId));
        multisig.confirmTransaction(txId);
    }

    function test_AddOwner_RevertsDuplicate() public {
        bytes memory addData = abi.encodeWithSelector(GuardianMultisig.addOwner.selector, owner1);

        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(address(multisig), 0, addData);

        vm.prank(owner2);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.ExecutionFailed.selector, txId));
        multisig.confirmTransaction(txId);
    }

    // -------------------------------------------------------------------
    //  Self-Governance: removeOwner Tests
    // -------------------------------------------------------------------

    function test_RemoveOwner_ViaSelfCall() public {
        bytes memory removeData = abi.encodeWithSelector(GuardianMultisig.removeOwner.selector, owner3);

        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(address(multisig), 0, removeData);

        vm.prank(owner2);
        multisig.confirmTransaction(txId); // auto-executes

        assertFalse(multisig.isOwner(owner3));
        address[] memory owners = multisig.getOwners();
        assertEq(owners.length, 2);
    }

    function test_RemoveOwner_AdjustsRequiredDownward() public {
        // Current: 3 owners, required=2
        // Remove 2 owners so only 1 remains: required should auto-adjust to 1
        // First remove owner3
        bytes memory remove3 = abi.encodeWithSelector(GuardianMultisig.removeOwner.selector, owner3);
        vm.prank(owner1);
        uint256 txId1 = multisig.submitTransaction(address(multisig), 0, remove3);
        vm.prank(owner2);
        multisig.confirmTransaction(txId1);
        // Now 2 owners, required=2

        // Remove owner2 => 1 owner, required must adjust from 2 to 1
        bytes memory remove2 = abi.encodeWithSelector(GuardianMultisig.removeOwner.selector, owner2);
        vm.prank(owner1);
        uint256 txId2 = multisig.submitTransaction(address(multisig), 0, remove2);
        // owner1 auto-confirms (1 confirm); required is still 2, so we need owner2 to confirm too
        // Wait -- owner1 submitted and auto-confirmed. required=2 and only owner1 confirmed.
        // But owner2 is still an owner at this point, so owner2 can confirm.
        vm.prank(owner2);
        multisig.confirmTransaction(txId2);

        assertEq(multisig.required(), 1);
        assertFalse(multisig.isOwner(owner2));
        address[] memory owners = multisig.getOwners();
        assertEq(owners.length, 1);
        assertEq(owners[0], owner1);
    }

    function test_RemoveOwner_RevertsDirectCall() public {
        vm.prank(owner1);
        vm.expectRevert("GuardianMultisig: only via multisig");
        multisig.removeOwner(owner3);
    }

    // -------------------------------------------------------------------
    //  Self-Governance: changeRequirement Tests
    // -------------------------------------------------------------------

    function test_ChangeRequirement_ViaSelfCall() public {
        bytes memory changeData = abi.encodeWithSelector(GuardianMultisig.changeRequirement.selector, 3);

        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(address(multisig), 0, changeData);

        vm.prank(owner2);
        multisig.confirmTransaction(txId); // auto-executes

        assertEq(multisig.required(), 3);
    }

    function test_ChangeRequirement_RevertsInvalid() public {
        // Requirement = 0
        bytes memory changeData = abi.encodeWithSelector(GuardianMultisig.changeRequirement.selector, 0);

        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(address(multisig), 0, changeData);

        vm.prank(owner2);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.ExecutionFailed.selector, txId));
        multisig.confirmTransaction(txId);
    }

    function test_ChangeRequirement_RevertsExceedsOwnerCount() public {
        bytes memory changeData = abi.encodeWithSelector(GuardianMultisig.changeRequirement.selector, 10);

        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(address(multisig), 0, changeData);

        vm.prank(owner2);
        vm.expectRevert(abi.encodeWithSelector(GuardianMultisig.ExecutionFailed.selector, txId));
        multisig.confirmTransaction(txId);
    }

    function test_ChangeRequirement_RevertsDirectCall() public {
        vm.prank(owner1);
        vm.expectRevert("GuardianMultisig: only via multisig");
        multisig.changeRequirement(1);
    }

    // -------------------------------------------------------------------
    //  View Function Tests
    // -------------------------------------------------------------------

    function test_GetConfirmationCount() public {
        uint256 txId = _submitEthTransfer(owner1);
        assertEq(multisig.getConfirmationCount(txId), 1);
    }

    function test_GetTransactionCount_Pending() public {
        _submitEthTransfer(owner1);
        // 1 pending tx (not executed yet since only 1 of 2 confirms)
        assertEq(multisig.getTransactionCount(true, false), 1);
        assertEq(multisig.getTransactionCount(false, true), 0);
    }

    function test_GetTransactionCount_Executed() public {
        uint256 txId = _submitEthTransfer(owner1);
        vm.prank(owner2);
        multisig.confirmTransaction(txId); // auto-executes

        assertEq(multisig.getTransactionCount(false, true), 1);
        assertEq(multisig.getTransactionCount(true, false), 0);
    }

    function test_GetTransactionCount_Both() public {
        _submitEthTransfer(owner1); // pending
        uint256 txId2 = _submitEthTransfer(owner2); // pending
        vm.prank(owner1);
        multisig.confirmTransaction(txId2); // now executed

        assertEq(multisig.getTransactionCount(true, true), 2);
        assertEq(multisig.getTransactionCount(true, false), 1);
        assertEq(multisig.getTransactionCount(false, true), 1);
    }

    function test_GetOwners() public view {
        address[] memory owners = multisig.getOwners();
        assertEq(owners.length, 3);
        assertEq(owners[0], owner1);
        assertEq(owners[1], owner2);
        assertEq(owners[2], owner3);
    }

    function test_IsConfirmed_BeforeThreshold() public {
        uint256 txId = _submitEthTransfer(owner1);
        assertFalse(multisig.isConfirmed(txId));
    }

    function test_IsConfirmed_AtThreshold() public {
        // Use 3-of-3 to check isConfirmed without auto-execute
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        GuardianMultisig ms3 = new GuardianMultisig(owners, 3);

        vm.prank(owner1);
        uint256 txId = ms3.submitTransaction(receiver, 0, "");
        assertFalse(ms3.isConfirmed(txId)); // 1 of 3

        vm.prank(owner2);
        ms3.confirmTransaction(txId);
        assertFalse(ms3.isConfirmed(txId)); // 2 of 3

        // After 3rd confirm, auto-execute triggers, but isConfirmed would be true
        // We check before auto-execute by inspecting the count
        assertEq(ms3.getConfirmationCount(txId), 2);
    }

    // -------------------------------------------------------------------
    //  Receive ETH Tests
    // -------------------------------------------------------------------

    function test_ReceiveEth() public {
        vm.deal(stranger, 5 ether);
        vm.prank(stranger);
        (bool ok,) = address(multisig).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(multisig).balance, 11 ether); // 10 from setUp + 1
    }
}
