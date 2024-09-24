//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

//v1. Write a Solidity function that implements a simple voting system. Each address should be allowed to vote only once.
//v2. gonna add a member functionality too, like become a member of the DAO by paying some membership fee then only you can vote! Also there will be a fixed voting period given by the proposal starter. 
//v3. multi-signature implementation for self-destruct. Requires at least 3 members and the admin/owner to sign-off so that the contract can be destroyed. Plus there will be a time delay too, for around 3 days to make sure everyone has enough time to think about their decisions and they can cancel it too.
//v4. We will also have an ownership transfer function, that will make some another person the owner.
//v5. members can also contribute to the DAO

contract Voting{
    //state variables
    address payable public owner;
    address[] public memberList;
    uint256 public proposalId;
    uint256 public minMembershipFee;
    uint256 public totalMembers;
    uint256 public QUORUM;
    uint256 public approvals = 0;
    uint256 private destructionTimestamp;
    uint256 private destructionDelay = 3 days;
    bool public isDestructionInitiated = false;

    //events
    event newMember(address newMember);
    event proposalCreated(address starter, string description, uint256 votingPeriod);
    event voted(uint256 _proposalId, address voter, bool voteInFavor);
    event selfDestructApproved (address approver, uint256 timeStamp);
    event selfDestructRemoveApproval (address disapprover, uint256 timeStamp);
    event addContribution (address _contributor, uint256 _contribution);
    event proposalFinalized(uint256 _proposalId, bool _isApproved);
    event proposalDelisted(uint256 _proposalId);
    event membershipFeeUpdated(uint256 newFee);
    event quorumUpdated(uint256 _newQuorum);
    event newOwner( address _newOwner );

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

    receive() external payable { }

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
    mapping (address => uint256) contribution;
    mapping (uint256 => mapping(address => bool)) hasVoted;
    mapping (address => bool) hasApproved; //approval for self-destruct

    
    function fetchContractBalance() public view returns(uint256){
        return address(this).balance;
    }

    function fetchProposalbyId(uint256 _proposalId) public view returns(Proposal memory){
        require(_proposalId < proposalId, "Invalid proposal ID");
        return proposals[_proposalId];
    }

    function fetchAllMembers() public view returns (address[] memory) {
        require(totalMembers > 0, "There are no members yet!");
        return memberList;
    }

    //----------------------------------------GAIN MEMBERSHIP FUNCTION---------------------------------------
    function becomeMember() payable public{
        require( msg.value >= minMembershipFee, "Please pay a minimum fee to become a member");
        require( !isMember[msg.sender], "You are already a member!");

        isMember[msg.sender] = true;
        totalMembers++;

        // Add member address to the member list
        memberList.push(msg.sender);

        // Refund the excess fee
        uint256 excessFee = msg.value - minMembershipFee;
        if (excessFee > 0) {
            payable(msg.sender).transfer(excessFee);
        }

        emit newMember(msg.sender);
    }
    //---------------------------------------MEMBER FUNCTIONS------------------------------------------------
    // Members can:--->>>
    // 1. Create Proposals ✅
    // 2. Vote on Proposals ✅
    // 3. Give Approval ✅
    // 4. Remove approval ✅
    // 5. Contribute to DAO ✅
    //---------------------------------------CREATE PROPOSALS------------------------------------------------
    function createProposal(string memory _description, uint256 _votingPeriod) public onlyMember{
        require(_votingPeriod >= 1, "Voting period should be positive");
        require(_votingPeriod <= 30, "Give a reasonable voting period");
        uint256 period = block.timestamp + _votingPeriod;
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
    //-----------------------------------CONTRIBUTE----------------------------------------------------------
    function contribute() public payable onlyMember{
        require( msg.value > 0, "You cannot add zero contributions");
        contribution[msg.sender] += msg.value;
        emit addContribution( msg.sender, msg.value);
    }
    //------------------------------------------OWNER FUNCTIONS----------------------------------------------
    //only Owner can:
    // 1. update Membership Fee ✅
    // 2. finalizeProposals ✅
    // 3. delistProposals ✅
    // 4. call the self destruct✅
    // 5. cancel destruction ✅ 
    // 6. update Quorums ✅
    // 7. withdraw all funds ✅
    // 8. Transfer Ownership ✅
    //----------------------------------------------UPDATE MEMBERSHIP FEE------------------------------------
    function updateMembershipFee(uint256 _newFee) public onlyOwner {
        minMembershipFee = _newFee;
        emit membershipFeeUpdated(_newFee);
    }
    //--------------------------------------------FINALIZE PROPOSAL------------------------------------------
    function finalizeProposal(uint256 _proposalId) public onlyOwner(){
        Proposal storage proposal = proposals[_proposalId];
        
        //check if its already finalized...
        require(!proposal.isFinalized, "Proposal is already finalized");
        //also check if the proposal id is even valid or not...
        require(_proposalId < proposalId, "Invalid Proposal");
        //check if the voting period is still going on...
        require(block.timestamp > proposal.votingPeriod, "Voting period has not passed yet!");
        //there should be at least one voter...
        require(proposal.noOfVoters > 0, "There should be at least one vote to finalize proposal");
        
        proposal.isApproved = proposal.votesFavor > proposal.votesAgainst;
        proposal.isFinalized = true;
        
        emit proposalFinalized(_proposalId, proposal.isApproved);
    }
    //--------------------------------------------DELIST PROPOSAL--------------------------------------------
    function delistProposal(uint _proposalId) public onlyOwner{
        //<---This function is basically for the scenario when a proposal has become dormant, i.e. no activity has been observed for it, like if no one has voted on it and the voting period has passed, that prop. should be delisted---->//

        Proposal storage proposal = proposals[_proposalId];
        
        //also check if the proposal id is even valid or not...
        require(_proposalId < proposalId, "Invalid Proposal ID!");
        //check if its already finalized...
        require(!proposal.isFinalized, "Cannot delist a finalized proposal!");
        //also check if there are some voters.....
        require(proposal.noOfVoters == 0, "Cannot delist a contract that has voters!");
        //also check if voting is still going on...
        require(proposal.votingPeriod < block.timestamp, "Voting period is still going on!");
        
        // If all conditions are met, we can remove the proposal
        delete proposals[_proposalId];

        emit proposalDelisted(_proposalId);
    }
    //--------------------------------------------DESTROY CONTRACT-------------------------------------------
    function initiateDestruction( ) external onlyOwner {
        require(!isDestructionInitiated, "Destruction process already initiated.");
        destructionTimestamp = block.timestamp + destructionDelay;
        isDestructionInitiated = true;
    }

    function destroyContract( ) external onlyOwner {
        require(isDestructionInitiated, "Destruction has not been initiated!");
        require(approvals >= QUORUM, "Self-destruct not approved. Minimum quorum must be met!");
        require(block.timestamp >= destructionTimestamp, "Destroy delay not met!");
        selfdestruct(payable(owner));
    }
    //------------------------------------------CANCEL DESTRUCTION-------------------------------------------
    function cancelDestruction( ) external onlyOwner {
        require(isDestructionInitiated, "Destruction has not been initiated!");
        // Reset the destruction state
        destructionTimestamp = 0;
        isDestructionInitiated = false;
    }
    //-------------------------------------------UPDATE QUORUM-----------------------------------------------
    function updateQuorum(uint256 _newQuorum) public onlyOwner{
        assert(_newQuorum >= 3); //at least a minimum of 3 members should always give approval for self-destruct, then only will the admin be allowed to destroy the contract permanently.
        QUORUM = _newQuorum;
        emit quorumUpdated(_newQuorum);
    }
    //-------------------------------------------WITHDRAW ALL FUNDS------------------------------------------
    function withdrawAllFunds() public onlyOwner{
        require(approvals >= QUORUM, "You cannot withdraw all funds. Minimum quorum must be met!");
        uint256 totalBalance = address(this).balance;
        owner.transfer(totalBalance);
    }
    //-----------------------------------------TRANSFER OWNERSHIP--------------------------------------------
    function transferOwnership( address _newOwner) public onlyOwner{
        require(isMember[_newOwner], "This is not a member. Only members can become owners");
        require(_newOwner != owner,  "You are already the owner!");
        owner = payable(_newOwner);
        emit newOwner(_newOwner);
    }
}