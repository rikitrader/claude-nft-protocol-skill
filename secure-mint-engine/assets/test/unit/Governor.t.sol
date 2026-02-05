// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/Governor.sol";

/**
 * @title GovernorTest
 * @notice Unit tests for the Governor on-chain DAO governance contract.
 */
contract GovernorTest is Test {
    // -------------------------------------------------------------------
    //  Events (declared locally for Solidity 0.8.20 emit compatibility)
    // -------------------------------------------------------------------

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address target,
        uint256 value,
        bytes calldataPayload,
        string description,
        uint256 startBlock,
        uint256 endBlock
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 totalForVotes,
        uint256 totalAgainstVotes
    );

    event ProposalExecuted(uint256 indexed proposalId);

    event ProposalCancelled(uint256 indexed proposalId);

    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    Governor public governor;

    address public admin = makeAddr("admin");
    address public proposer = makeAddr("proposer");
    address public voter1 = makeAddr("voter1");
    address public voter2 = makeAddr("voter2");
    address public voter3 = makeAddr("voter3");
    address public stranger = makeAddr("stranger");

    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant QUORUM = 2;
    uint256 public constant VOTING_PERIOD = 100; // blocks

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        governor = new Governor(QUORUM, VOTING_PERIOD, admin);

        vm.startPrank(admin);
        governor.grantRole(PROPOSER_ROLE, proposer);
        governor.grantRole(VOTER_ROLE, voter1);
        governor.grantRole(VOTER_ROLE, voter2);
        governor.grantRole(VOTER_ROLE, voter3);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------
    //  Helper — create a standard proposal and return its ID
    // -------------------------------------------------------------------

    function _createProposal() internal returns (uint256) {
        vm.prank(proposer);
        return governor.propose(
            address(governor),
            0,
            abi.encodeWithSelector(Governor.setQuorum.selector, 3),
            "Raise quorum to 3"
        );
    }

    // -------------------------------------------------------------------
    //  Constructor Tests
    // -------------------------------------------------------------------

    function test_Constructor_SetsParamsCorrectly() public view {
        assertEq(governor.quorum(), QUORUM);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertTrue(governor.hasRole(governor.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(governor.hasRole(ADMIN_ROLE, admin));
    }

    function test_Constructor_RevertsZeroAdmin() public {
        vm.expectRevert("Governor: zero admin");
        new Governor(QUORUM, VOTING_PERIOD, address(0));
    }

    function test_Constructor_RevertsZeroQuorum() public {
        vm.expectRevert(Governor.InvalidQuorum.selector);
        new Governor(0, VOTING_PERIOD, admin);
    }

    function test_Constructor_RevertsZeroVotingPeriod() public {
        vm.expectRevert(Governor.InvalidVotingPeriod.selector);
        new Governor(QUORUM, 0, admin);
    }

    // -------------------------------------------------------------------
    //  Propose Tests
    // -------------------------------------------------------------------

    function test_Propose_CreatesProposal() public {
        uint256 id = _createProposal();

        assertEq(id, 1);
        assertEq(governor.proposalCount(), 1);

        (
            address prop,
            address target,
            uint256 value,
            ,  // calldataPayload
            ,  // description
            uint256 forVotes,
            uint256 againstVotes,
            uint256 startBlock,
            uint256 endBlock,
            bool executed,
            bool cancelled
        ) = governor.proposals(id);

        assertEq(prop, proposer);
        assertEq(target, address(governor));
        assertEq(value, 0);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
        assertEq(startBlock, block.number + 1);
        assertEq(endBlock, block.number + 1 + VOTING_PERIOD);
        assertFalse(executed);
        assertFalse(cancelled);
    }

    function test_Propose_EmitsProposalCreated() public {
        vm.prank(proposer);
        vm.expectEmit(true, true, false, true);
        emit ProposalCreated(
            1,
            proposer,
            address(governor),
            0,
            abi.encodeWithSelector(Governor.setQuorum.selector, 3),
            "Raise quorum to 3",
            block.number + 1,
            block.number + 1 + VOTING_PERIOD
        );
        governor.propose(
            address(governor),
            0,
            abi.encodeWithSelector(Governor.setQuorum.selector, 3),
            "Raise quorum to 3"
        );
    }

    function test_Propose_RevertsWithoutProposerRole() public {
        vm.prank(stranger);
        vm.expectRevert();
        governor.propose(address(governor), 0, "", "test");
    }

    function test_Propose_MultipleProposalsIncrementId() public {
        uint256 id1 = _createProposal();
        uint256 id2 = _createProposal();

        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(governor.proposalCount(), 2);
    }

    // -------------------------------------------------------------------
    //  Vote Tests
    // -------------------------------------------------------------------

    function test_Vote_ForVote() public {
        uint256 id = _createProposal();

        // Move into the voting window
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, true);

        (,,,,, uint256 forVotes,,,,,) = governor.proposals(id);
        assertEq(forVotes, 1);
        assertTrue(governor.hasVoted(id, voter1));
    }

    function test_Vote_AgainstVote() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, false);

        (,,,,,, uint256 againstVotes,,,,) = governor.proposals(id);
        assertEq(againstVotes, 1);
    }

    function test_Vote_EmitsVoteCast() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        vm.expectEmit(true, true, false, true);
        emit VoteCast(id, voter1, true, 1, 0);
        governor.vote(id, true);
    }

    function test_Vote_RevertsOnDoubleVote() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, true);

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(Governor.AlreadyVoted.selector, id, voter1));
        governor.vote(id, true);
    }

    function test_Vote_RevertsOnNonExistentProposal() public {
        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(Governor.ProposalNotFound.selector, 999));
        governor.vote(999, true);
    }

    function test_Vote_RevertsOnProposalIdZero() public {
        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(Governor.ProposalNotFound.selector, 0));
        governor.vote(0, true);
    }

    function test_Vote_RevertsWhenPending() public {
        uint256 id = _createProposal();
        // Do NOT advance blocks; proposal is still Pending

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(Governor.VotingNotActive.selector, id));
        governor.vote(id, true);
    }

    function test_Vote_RevertsAfterVotingPeriod() public {
        uint256 id = _createProposal();
        // Advance beyond endBlock
        vm.roll(block.number + VOTING_PERIOD + 10);

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(Governor.VotingNotActive.selector, id));
        governor.vote(id, true);
    }

    function test_Vote_RevertsWithoutVoterRole() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(stranger);
        vm.expectRevert();
        governor.vote(id, true);
    }

    // -------------------------------------------------------------------
    //  ProposalState Tests
    // -------------------------------------------------------------------

    function test_ProposalState_Pending() public {
        uint256 id = _createProposal();
        // Same block as creation => startBlock = block.number + 1, so current block < startBlock
        assertEq(uint256(governor.proposalState(id)), uint256(Governor.ProposalState.Pending));
    }

    function test_ProposalState_Active() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2); // inside [startBlock, endBlock]
        assertEq(uint256(governor.proposalState(id)), uint256(Governor.ProposalState.Active));
    }

    function test_ProposalState_Defeated_NoVotes() public {
        uint256 id = _createProposal();
        vm.roll(block.number + VOTING_PERIOD + 10);
        // No votes at all => forVotes < quorum
        assertEq(uint256(governor.proposalState(id)), uint256(Governor.ProposalState.Defeated));
    }

    function test_ProposalState_Defeated_AgainstWins() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        // 2 for, 3 against (even though for == quorum, against >= for means defeated)
        vm.prank(voter1);
        governor.vote(id, true);
        vm.prank(voter2);
        governor.vote(id, true);
        vm.prank(voter3);
        governor.vote(id, false);

        // Actually 2 for > 1 against and quorum met, so let's test correctly:
        // Need against >= for with quorum met to get Defeated
        // With 3 voters and quorum=2, let's do 2 against, 1 for
        // Reset: new proposal
        uint256 id2 = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id2, false);
        vm.prank(voter2);
        governor.vote(id2, false);
        vm.prank(voter3);
        governor.vote(id2, true);

        vm.roll(block.number + VOTING_PERIOD + 10);
        // forVotes = 1, againstVotes = 2 => for < quorum => Defeated
        assertEq(uint256(governor.proposalState(id2)), uint256(Governor.ProposalState.Defeated));
    }

    function test_ProposalState_Defeated_QuorumNotMet() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        // Only 1 for vote, quorum is 2
        vm.prank(voter1);
        governor.vote(id, true);

        vm.roll(block.number + VOTING_PERIOD + 10);
        assertEq(uint256(governor.proposalState(id)), uint256(Governor.ProposalState.Defeated));
    }

    function test_ProposalState_Succeeded() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, true);
        vm.prank(voter2);
        governor.vote(id, true);

        // Move past voting period
        vm.roll(block.number + VOTING_PERIOD + 10);
        assertEq(uint256(governor.proposalState(id)), uint256(Governor.ProposalState.Succeeded));
    }

    function test_ProposalState_Executed() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, true);
        vm.prank(voter2);
        governor.vote(id, true);

        vm.roll(block.number + VOTING_PERIOD + 10);
        governor.execute(id);

        assertEq(uint256(governor.proposalState(id)), uint256(Governor.ProposalState.Executed));
    }

    function test_ProposalState_Cancelled() public {
        uint256 id = _createProposal();

        vm.prank(proposer);
        governor.cancel(id);

        assertEq(uint256(governor.proposalState(id)), uint256(Governor.ProposalState.Cancelled));
    }

    function test_ProposalState_RevertsForNonExistent() public {
        vm.expectRevert(abi.encodeWithSelector(Governor.ProposalNotFound.selector, 42));
        governor.proposalState(42);
    }

    // -------------------------------------------------------------------
    //  Execute Tests
    // -------------------------------------------------------------------

    function test_Execute_SucceededProposal() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, true);
        vm.prank(voter2);
        governor.vote(id, true);

        vm.roll(block.number + VOTING_PERIOD + 10);

        vm.expectEmit(true, false, false, false);
        emit ProposalExecuted(id);
        governor.execute(id);

        // Verify the call was executed: quorum should now be 3
        assertEq(governor.quorum(), 3);
    }

    function test_Execute_RevertsBeforeVotingEnds() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, true);
        vm.prank(voter2);
        governor.vote(id, true);

        // Still within voting period (Active state)
        vm.expectRevert(
            abi.encodeWithSelector(
                Governor.ProposalNotSucceeded.selector,
                id,
                Governor.ProposalState.Active
            )
        );
        governor.execute(id);
    }

    function test_Execute_RevertsQuorumNotMet() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, true);
        // Only 1 vote, quorum = 2

        vm.roll(block.number + VOTING_PERIOD + 10);

        vm.expectRevert(
            abi.encodeWithSelector(
                Governor.ProposalNotSucceeded.selector,
                id,
                Governor.ProposalState.Defeated
            )
        );
        governor.execute(id);
    }

    function test_Execute_RevertsNonExistentProposal() public {
        vm.expectRevert(abi.encodeWithSelector(Governor.ProposalNotFound.selector, 999));
        governor.execute(999);
    }

    function test_Execute_RevertsAlreadyExecuted() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, true);
        vm.prank(voter2);
        governor.vote(id, true);

        vm.roll(block.number + VOTING_PERIOD + 10);
        governor.execute(id);

        // Second execution reverts
        vm.expectRevert(
            abi.encodeWithSelector(
                Governor.ProposalNotSucceeded.selector,
                id,
                Governor.ProposalState.Executed
            )
        );
        governor.execute(id);
    }

    function test_Execute_RevertsCancelledProposal() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, true);
        vm.prank(voter2);
        governor.vote(id, true);

        vm.prank(proposer);
        governor.cancel(id);

        vm.roll(block.number + VOTING_PERIOD + 10);

        vm.expectRevert(
            abi.encodeWithSelector(
                Governor.ProposalNotSucceeded.selector,
                id,
                Governor.ProposalState.Cancelled
            )
        );
        governor.execute(id);
    }

    function test_Execute_WithValue() public {
        // Fund the governor
        vm.deal(address(governor), 1 ether);

        // Create proposal to send ETH to stranger
        vm.prank(proposer);
        uint256 id = governor.propose(stranger, 1 ether, "", "Send 1 ETH");

        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, true);
        vm.prank(voter2);
        governor.vote(id, true);

        vm.roll(block.number + VOTING_PERIOD + 10);
        governor.execute(id);

        assertEq(stranger.balance, 1 ether);
    }

    // -------------------------------------------------------------------
    //  Cancel Tests
    // -------------------------------------------------------------------

    function test_Cancel_ByProposer() public {
        uint256 id = _createProposal();

        vm.prank(proposer);
        vm.expectEmit(true, false, false, false);
        emit ProposalCancelled(id);
        governor.cancel(id);

        assertEq(uint256(governor.proposalState(id)), uint256(Governor.ProposalState.Cancelled));
    }

    function test_Cancel_ByAdmin() public {
        uint256 id = _createProposal();

        vm.prank(admin);
        governor.cancel(id);

        assertEq(uint256(governor.proposalState(id)), uint256(Governor.ProposalState.Cancelled));
    }

    function test_Cancel_RevertsUnauthorized() public {
        uint256 id = _createProposal();

        vm.prank(stranger);
        vm.expectRevert("Governor: caller is not proposer or admin");
        governor.cancel(id);
    }

    function test_Cancel_RevertsAlreadyExecuted() public {
        uint256 id = _createProposal();
        vm.roll(block.number + 2);

        vm.prank(voter1);
        governor.vote(id, true);
        vm.prank(voter2);
        governor.vote(id, true);

        vm.roll(block.number + VOTING_PERIOD + 10);
        governor.execute(id);

        vm.prank(proposer);
        vm.expectRevert("Governor: proposal already executed");
        governor.cancel(id);
    }

    function test_Cancel_RevertsAlreadyCancelled() public {
        uint256 id = _createProposal();

        vm.prank(proposer);
        governor.cancel(id);

        vm.prank(proposer);
        vm.expectRevert("Governor: proposal already cancelled");
        governor.cancel(id);
    }

    function test_Cancel_RevertsNonExistentProposal() public {
        vm.expectRevert(abi.encodeWithSelector(Governor.ProposalNotFound.selector, 999));
        vm.prank(admin);
        governor.cancel(999);
    }

    // -------------------------------------------------------------------
    //  setQuorum / setVotingPeriod Tests
    // -------------------------------------------------------------------

    function test_SetQuorum_AdminOnly() public {
        vm.prank(admin);
        governor.setQuorum(5);
        assertEq(governor.quorum(), 5);
    }

    function test_SetQuorum_RevertsZero() public {
        vm.prank(admin);
        vm.expectRevert(Governor.InvalidQuorum.selector);
        governor.setQuorum(0);
    }

    function test_SetQuorum_RevertsNonAdmin() public {
        vm.prank(stranger);
        vm.expectRevert();
        governor.setQuorum(5);
    }

    function test_SetVotingPeriod_AdminOnly() public {
        vm.prank(admin);
        governor.setVotingPeriod(200);
        assertEq(governor.votingPeriod(), 200);
    }

    function test_SetVotingPeriod_RevertsZero() public {
        vm.prank(admin);
        vm.expectRevert(Governor.InvalidVotingPeriod.selector);
        governor.setVotingPeriod(0);
    }

    function test_SetVotingPeriod_RevertsNonAdmin() public {
        vm.prank(stranger);
        vm.expectRevert();
        governor.setVotingPeriod(200);
    }

    // -------------------------------------------------------------------
    //  Receive ETH Tests
    // -------------------------------------------------------------------

    function test_ReceiveEth() public {
        vm.deal(admin, 5 ether);
        vm.prank(admin);
        (bool ok,) = address(governor).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(governor).balance, 1 ether);
    }
}
