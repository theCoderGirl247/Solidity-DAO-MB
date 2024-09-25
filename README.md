# MEMBERSHIP BASED DAO

This Solidity smart contract implements a DAO-based Voting System with various features such as membership management, proposal voting, multi-signature governance for contract self-destruction, and ownership transfer. It allows members to participate in governance activities by creating proposals, voting, and contributing to the DAO.

## Key Features:

Membership-based Voting:

Users must become members by paying a membership fee (minimum of 1 ETH) before they can vote on proposals or participate in the DAO.
Membership is stored in a list and tracked through mappings.

Proposal System:

Members can create proposals with a description and a voting period.
Other members can vote either in favor or against the proposal. Each member can only vote once per proposal.
After the voting period ends, proposals are either approved or rejected based on the vote count.

Contributions to DAO:

Members can make contributions to the DAO, and these contributions are recorded for future reference.

Self-Destruct Mechanism:

The contract has a multi-signature self-destruct mechanism.
A minimum of 3 members (quorum) and the admin/owner must approve the self-destruction.
There’s a 3-day delay after initiating self-destruct to give members time to reconsider or cancel approvals.

Ownership Transfer:

The contract owner can transfer ownership to another member. This ensures continuity of control over the contract.

### Functional Breakdown:

Membership Management:

Members pay a fee to join.
A list of members is maintained.
Membership is required for proposal creation, voting, and approvals.

Proposal Creation and Voting:

Members can create proposals with a custom voting period.
Voting is restricted to members, and each member can vote only once on a proposal.
Proposals can be finalized only after the voting period ends, and only by the owner.

Self-Destruction and Multi-Sig Approval:

The owner can initiate contract destruction, but it requires multi-sig approval from at least 3 members and a time delay.
Members can approve or withdraw approval for self-destruction.
The owner can cancel destruction during the waiting period.

Ownership and Governance:

The owner can update the membership fee and quorum size for destruction approval.
Proposals can be delisted (removed) if they become inactive.
Ownership of the contract can be transferred to another member, ensuring flexibility in governance.

Funds Management:

Members can contribute funds, which are stored in the contract.
The owner can withdraw all funds but only after approvals meet the quorum.

This contract is designed for decentralized governance, allowing members to actively participate in decision-making, proposal creation, and voting while ensuring the integrity of the contract through multi-signature approvals and ownership transferability.






