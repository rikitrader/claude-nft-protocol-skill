// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Governor
 * @author SecureMintEngine
 * @notice Lightweight on-chain DAO governance for SecureMintEngine parameter
 *         changes. Unlike a full Governor (ERC-5805), this contract uses a
 *         simple role-based proposal + multisig approval model without a
 *         voting token.
 *
 * @dev Governance flow:
 *
 *      1. Propose  — A PROPOSER creates a proposal targeting a contract call.
 *      2. Vote     — VOTER_ROLE holders cast for/against votes during the
 *                    voting window (startBlock .. endBlock).
 *      3. Execute  — Anyone can execute a succeeded proposal after the voting
 *                    period ends (forVotes > againstVotes, forVotes >= quorum).
 *      4. Cancel   — The proposer or an ADMIN can cancel a non-executed proposal.
 *
 *      Proposal states:
 *
 *      | State     | Condition                                        |
 *      |-----------|--------------------------------------------------|
 *      | Pending   | block.number < startBlock                        |
 *      | Active    | startBlock <= block.number <= endBlock            |
 *      | Defeated  | Voting ended, quorum not met or against >= for   |
 *      | Succeeded | Voting ended, quorum met, for > against          |
 *      | Executed  | Proposal was successfully executed                |
 *      | Cancelled | Proposal was cancelled before execution           |
 */
contract Governor is AccessControl {
    // -------------------------------------------------------------------
    //  Roles
    // -------------------------------------------------------------------

    /// @notice Proposers can create new governance proposals.
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    /// @notice Voters can cast votes on active proposals.
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");

    /// @notice Admins can configure governance parameters and cancel proposals.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // -------------------------------------------------------------------
    //  Enums
    // -------------------------------------------------------------------

    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Executed,
        Cancelled
    }

    // -------------------------------------------------------------------
    //  Structs
    // -------------------------------------------------------------------

    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes calldataPayload;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startBlock;
        uint256 endBlock;
        bool executed;
        bool cancelled;
    }

    // -------------------------------------------------------------------
    //  Custom Errors
    // -------------------------------------------------------------------

    /// @dev Thrown when referencing a proposal ID that does not exist.
    error ProposalNotFound(uint256 proposalId);

    /// @dev Thrown when a voter has already cast a vote on a proposal.
    error AlreadyVoted(uint256 proposalId, address voter);

    /// @dev Thrown when trying to vote outside the active voting window.
    error VotingNotActive(uint256 proposalId);

    /// @dev Thrown when trying to execute a proposal that is not in Succeeded state.
    error ProposalNotSucceeded(uint256 proposalId, ProposalState currentState);

    /// @dev Thrown when the low-level call to the target contract fails.
    error ProposalExecutionFailed(uint256 proposalId);

    /// @dev Thrown when a zero voting period is provided.
    error InvalidVotingPeriod();

    /// @dev Thrown when a zero quorum is provided.
    error InvalidQuorum();

    // -------------------------------------------------------------------
    //  Events
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
    //  State Variables
    // -------------------------------------------------------------------

    /// @notice Total number of proposals created.
    uint256 public proposalCount;

    /// @notice Number of for-votes required for a proposal to succeed.
    uint256 public quorum;

    /// @notice Duration of the voting window in blocks.
    uint256 public votingPeriod;

    /// @notice Mapping from proposal ID to proposal data.
    mapping(uint256 => Proposal) public proposals;

    /// @notice Tracks whether an address has voted on a given proposal.
    /// @dev proposalId => voter => hasVoted
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // -------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------

    /**
     * @param quorum_       Initial quorum (minimum for-votes to pass).
     * @param votingPeriod_ Voting window duration in blocks.
     * @param admin         Initial admin address.
     */
    constructor(
        uint256 quorum_,
        uint256 votingPeriod_,
        address admin
    ) {
        require(admin != address(0), "Governor: zero admin");
        if (quorum_ == 0) revert InvalidQuorum();
        if (votingPeriod_ == 0) revert InvalidVotingPeriod();

        quorum = quorum_;
        votingPeriod = votingPeriod_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    // -------------------------------------------------------------------
    //  External — Propose
    // -------------------------------------------------------------------

    /**
     * @notice Creates a new governance proposal.
     * @param target          Address of the contract to call if the proposal passes.
     * @param value           ETH value to send with the call.
     * @param calldataPayload Encoded function call data.
     * @param description     Human-readable description of the proposal.
     * @return proposalId     The ID of the newly created proposal.
     */
    function propose(
        address target,
        uint256 value,
        bytes calldata calldataPayload,
        string calldata description
    ) external onlyRole(PROPOSER_ROLE) returns (uint256 proposalId) {
        proposalId = ++proposalCount;

        uint256 startBlock = block.number + 1;
        uint256 endBlock = startBlock + votingPeriod;

        proposals[proposalId] = Proposal({
            proposer: msg.sender,
            target: target,
            value: value,
            calldataPayload: calldataPayload,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            startBlock: startBlock,
            endBlock: endBlock,
            executed: false,
            cancelled: false
        });

        emit ProposalCreated(
            proposalId,
            msg.sender,
            target,
            value,
            calldataPayload,
            description,
            startBlock,
            endBlock
        );
    }

    // -------------------------------------------------------------------
    //  External — Vote
    // -------------------------------------------------------------------

    /**
     * @notice Casts a vote on an active proposal.
     * @dev Each VOTER_ROLE address gets exactly one vote per proposal.
     * @param proposalId The proposal to vote on.
     * @param support    True for a for-vote, false for an against-vote.
     */
    function vote(
        uint256 proposalId,
        bool support
    ) external onlyRole(VOTER_ROLE) {
        if (proposalId == 0 || proposalId > proposalCount) {
            revert ProposalNotFound(proposalId);
        }

        if (proposalState(proposalId) != ProposalState.Active) {
            revert VotingNotActive(proposalId);
        }

        if (hasVoted[proposalId][msg.sender]) {
            revert AlreadyVoted(proposalId, msg.sender);
        }

        hasVoted[proposalId][msg.sender] = true;

        Proposal storage p = proposals[proposalId];

        if (support) {
            p.forVotes += 1;
        } else {
            p.againstVotes += 1;
        }

        emit VoteCast(proposalId, msg.sender, support, p.forVotes, p.againstVotes);
    }

    // -------------------------------------------------------------------
    //  External — Execute
    // -------------------------------------------------------------------

    /**
     * @notice Execute a succeeded proposal. Callable by anyone (standard governance pattern).
     * @dev Permissionless execution ensures proposals cannot be blocked by a single actor.
     *      The proposal must be in Succeeded state (voting ended, quorum met,
     *      forVotes > againstVotes).
     * @param proposalId The proposal to execute.
     */
    function execute(uint256 proposalId) external payable {
        if (proposalId == 0 || proposalId > proposalCount) {
            revert ProposalNotFound(proposalId);
        }

        ProposalState state = proposalState(proposalId);
        if (state != ProposalState.Succeeded) {
            revert ProposalNotSucceeded(proposalId, state);
        }

        Proposal storage p = proposals[proposalId];
        p.executed = true;

        // solhint-disable-next-line avoid-low-level-calls
        // slither-disable-next-line low-level-calls
        (bool success, ) = p.target.call{value: p.value}(p.calldataPayload);
        if (!success) {
            revert ProposalExecutionFailed(proposalId);
        }

        // slither-disable-next-line reentrancy-events
        emit ProposalExecuted(proposalId);
    }

    // -------------------------------------------------------------------
    //  External — Cancel
    // -------------------------------------------------------------------

    /**
     * @notice Cancels a proposal that has not yet been executed.
     * @dev Only the original proposer or an ADMIN can cancel.
     * @param proposalId The proposal to cancel.
     */
    function cancel(uint256 proposalId) external {
        if (proposalId == 0 || proposalId > proposalCount) {
            revert ProposalNotFound(proposalId);
        }

        Proposal storage p = proposals[proposalId];

        require(
            msg.sender == p.proposer || hasRole(ADMIN_ROLE, msg.sender),
            "Governor: caller is not proposer or admin"
        );
        require(!p.executed, "Governor: proposal already executed");
        require(!p.cancelled, "Governor: proposal already cancelled");

        p.cancelled = true;

        emit ProposalCancelled(proposalId);
    }

    // -------------------------------------------------------------------
    //  External — Configuration (ADMIN_ROLE)
    // -------------------------------------------------------------------

    /**
     * @notice Updates the quorum threshold.
     * @param newQuorum The new minimum number of for-votes required.
     */
    function setQuorum(uint256 newQuorum) external onlyRole(ADMIN_ROLE) {
        if (newQuorum == 0) revert InvalidQuorum();
        quorum = newQuorum;
    }

    /**
     * @notice Updates the voting period duration.
     * @param newPeriod The new voting window duration in blocks.
     */
    function setVotingPeriod(uint256 newPeriod) external onlyRole(ADMIN_ROLE) {
        if (newPeriod == 0) revert InvalidVotingPeriod();
        votingPeriod = newPeriod;
    }

    // -------------------------------------------------------------------
    //  Public — View Functions
    // -------------------------------------------------------------------

    /**
     * @notice Returns the current state of a proposal.
     * @param proposalId The proposal to query.
     * @return The current ProposalState.
     */
    function proposalState(uint256 proposalId) public view returns (ProposalState) {
        if (proposalId == 0 || proposalId > proposalCount) {
            revert ProposalNotFound(proposalId);
        }

        Proposal storage p = proposals[proposalId];

        if (p.cancelled) {
            return ProposalState.Cancelled;
        }

        if (p.executed) {
            return ProposalState.Executed;
        }

        // slither-disable-next-line timestamp
        if (block.number < p.startBlock) {
            return ProposalState.Pending;
        }

        // slither-disable-next-line timestamp
        if (block.number <= p.endBlock) {
            return ProposalState.Active;
        }

        // Voting period has ended — determine outcome
        if (p.forVotes >= quorum && p.forVotes > p.againstVotes) {
            return ProposalState.Succeeded;
        }

        return ProposalState.Defeated;
    }

    // -------------------------------------------------------------------
    //  Receive
    // -------------------------------------------------------------------

    /// @dev Allow the contract to receive ETH (needed for proposals with value).
    receive() external payable {}
}
