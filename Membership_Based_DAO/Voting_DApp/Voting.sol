//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

//v1 . Write a Solidity function that implements a simple voting system. Each address should be allowed to vote only once.
//v2 . gonna add a member functionality too, like become a member of the DAO by paying some membership fee then only you can vote! Also there will be a fixed voting period given by the proposal starter. 
//v3. multi-signature implementation for self-destruct. Requires at least 3 members and the admin/owner to sign-off so that the contract can be destroyed. Plus there will be a time delay too, for around 3 days to make sure everyone has enough time to think about their decisions.

contract Voting{
    //state variables
    address payable public owner;
    uint256 public proposalId;
    uint256 public minMembershipFee;
    uint256 public totalMembers;
    uint256 public QUORUM;
    uint256 public approvals = 0;
    uint256 private Delay = 3 days;

    //events
    event newMember(address newMember);
    event proposalCreated(address starter, string description, uint256 votingPeriod);
    event voted(uint256 _proposalId, address voter, bool voteInFavor);
    event membershipFeeUpdated(uint256 newFee);
    event quorumUpdated(uint256 _newQuorum);
    event selfDestructApproved (address approver, uint256 timeStamp);
    event selfDestructRemoveApproval (address disapprover, uint256 timeStamp);

    constructor() {
        owner = payable( msg.sender );
        proposalId = 0;
        minMembershipFee = 1 ether;
        totalMembers = 0;
        QUORUM = 3;
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "You are not the owner!");
        _;
    }

    modifier onlyMember(){
        require(isMember[msg.sender], "You are not a member!");
        _;
    }

    //structure for Proposals
    struct Proposal{
        address payable starter;
        string description;
        uint256 votingPeriod;
        uint256 votesFavor;
        uint256 votesAgainst;
        uint256 noOfVoters;
        bool isApproved;
        bool isFinalized;
    }
    
    //mappings
    mapping (address => bool) isMember;
    mapping (uint256 => Proposal) proposals;
    mapping (uint256 => mapping(address => bool)) hasVoted;
    mapping (address => bool) hasApproved; //approval for self-destruct

    
    function getContractBalance() public view returns(uint256){
        return address(this).balance;
    }

    //----------------------------------------GAIN MEMBERSHIP FUNCTION---------------------------------------
    function becomeMember() payable public{
        require( msg.value >= minMembershipFee, "Please pay a minimum fee to become a member");
        require( !isMember[msg.sender], "You are already a member!");

        isMember[msg.sender] = true;
        totalMembers++;

        emit newMember(msg.sender);
    }
    //---------------------------------------MEMBER FUNCTIONS------------------------------------------------
    // Members can:
    // 1. Create Proposals
    // 2. Vote on Proposals
    // 3. Approve for self-desctruct
    // 4. Remove approval for self-destruct
    //---------------------------------------CREATE PROPOSALS------------------------------------------------
    function createProposal(string memory _description, uint256 _VotingPeriod) public onlyMember{
        require(_VotingPeriod >= 1, "Voting period should be positive");
        uint256 period = block.timestamp + _VotingPeriod;
        proposals[proposalId] = Proposal({
        starter: payable(msg.sender),
        description: _description,
        votingPeriod: period,
        votesFavor: 0,
        votesAgainst: 0,
        noOfVoters: 0,
        isApproved: false,
        isFinalized: false
        });
        proposalId++;
        emit proposalCreated(msg.sender, _description, period);
    }

    //---------------------------------------------VOTE------------------------------------------------------
    function vote(uint256 _proposalId, bool voteInFavor) public onlyMember{
        Proposal storage proposal = proposals[_proposalId];

        //also check if the proposal id is even valid or not...
        require(_proposalId < proposalId, "Invalid Proposal");
        //check if the voting period is still going on...
        require(proposal.votingPeriod > block.timestamp, "Voting period has already passed");
        //check if the person has already voted...
        require(!hasVoted[_proposalId][msg.sender], "This user has already voted");

        if (voteInFavor) {
            proposal.votesFavor++;
        }
        else{
            proposal.votesAgainst++;
        }
        proposal.noOfVoters++; 
        //also, noOfVoters are also equal to total votes, so didn't add a separate parameter for it
        hasVoted[_proposalId][msg.sender] = true;

        emit voted( _proposalId, msg.sender, voteInFavor);
    }
    //-------------------------------GIVING APPROVAL FOR SELF DESTRUCT---------------------------------------
    function giveApproval() public onlyMember{
        require(!hasApproved[msg.sender], "You have already approved for self-destruct");
        hasApproved[msg.sender] = true;
        approvals++ ;
        emit selfDestructApproved(msg.sender, block.timestamp);
    }

    //------------------------------REMOVING APPROVAL FOR SELF - DESTRUCT------------------------------------
    function removeApproval() public onlyMember{
        require(hasApproved[msg.sender], "You haven't approved it yet.");
        hasApproved[msg.sender] = false;
        approvals-- ;
        emit selfDestructRemoveApproval(msg.sender, block.timestamp);
    }

    //------------------------------------------OWNER FUNCTIONS----------------------------------------------
    //only Owner can:
    // 1. update Membership Fee
    // 2. finalizeProposals
    // 3. delistProposals 
    // 4. call the self destruct after the approval of at least 3 members
    // 5. update Quorums, i.e. least number of approvals for self-destruct
    // 6. withdraw all funds, also requires the approval of QUORUM

    function updateMembershipFee(uint256 _newFee) public onlyOwner {
        minMembershipFee = _newFee;
        emit membershipFeeUpdated(_newFee);
    }

    function finalizeProposal(uint256 _proposalId) public onlyOwner(){
        Proposal storage proposal = proposals[_proposalId];
        
        //check if its already finalized...
        require(!proposal.isFinalized, "Proposal is already finalized");
        //also check if the proposal id is even valid or not...
        require(_proposalId < proposalId, "Invalid Proposal");
        //check if the voting period is still going on...
        require(block.timestamp > proposal.votingPeriod, "Voting period has not passed yet!");
        proposal.isApproved = proposal.votesFavor > proposal.votesAgainst;
        proposal.isFinalized = true;
    }

    function destroyContract() public onlyOwner {
        require(approvals >= QUORUM, "Self-destruct not approved. Minimum quorum must be met!");
        selfdestruct(payable(owner));
    }

    function updateQuorum(uint256 _newQuorum) public onlyOwner{
        assert(_newQuorum >= 3); //at least a minimum of 3 members should always give approval for self-destruct, then only will the admin be allowed to destroy the contract permanently.
        QUORUM = _newQuorum;
        emit quorumUpdated(_newQuorum);
    }

    function withdrawAllFunds() public onlyOwner{
        require(approvals >= QUORUM, "You cannot withdraw all funds. Minimum quorum must be met!");
        uint256 totalBalance = address(this).balance;
        owner.transfer(totalBalance);
    }
}