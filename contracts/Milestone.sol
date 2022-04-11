// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Conflict.sol";
import "./Review.sol";
import "./ERC20.sol";
import "./States.sol";

contract Milestone {

    Conflict conflict;
    Review review;
    // address payable contractAddress = payable(msg.sender); 

    constructor (Conflict conflictContract, Review reviewContract) payable {
        conflict = conflictContract;
        review = reviewContract;
    }

    struct milestone {
        uint256 projectNumber;
        uint256 serviceNumber;
        uint256 milestoneNumber;
        string title;
        string description;
        bool exist; // allowing updates such as soft delete of milestone   
        States.MilestoneStatus status; // Defaults at none
        uint256 price;
        address payable serviceRequester; // msg.sender
        address payable serviceProvider; // defaults to address(0)
    }

    mapping (uint256 => mapping(uint256 => mapping(uint256 => milestone))) servicesMilestones; // [projectNumber][serviceNumber][milestoneNumber]

    event milestoneCreated(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, string title, string description);
    event milestoneUpdated(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, string title, string description);
    event milestoneDeleted(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber);

    uint256 milestoneTotal = 0;
    uint256 milestoneNum = 0;

/*
    Modifiers
*/

    modifier requiredString(string memory str) {
        require(bytes(str).length > 0, "A string is required!");
        _;
    }

    modifier isValidMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber){
        require(servicesMilestones[projectNumber][serviceNumber][milestoneNumber].exist, "This Milestone does not exist ya dummy!");
        _;
    }

    modifier atState(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, States.MilestoneStatus state){
        require(servicesMilestones[projectNumber][serviceNumber][milestoneNumber].status == state, "Cannot carry out this operation!");
        _;
    }

    modifier isNeither(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, address target) {
        require(servicesMilestones[projectNumber][serviceNumber][milestoneNumber].serviceRequester == payable(target) || 
                servicesMilestones[projectNumber][serviceNumber][milestoneNumber].serviceProvider == payable(target) , "Invalid service requester or provider");
        _;
    }

    modifier checkDAO(uint256 projectNumber, uint256 serviceNumber, uint256 numMilestones, address _from) {
        mapping(uint256 => milestone) storage currService = servicesMilestones[projectNumber][serviceNumber];
        bool check = false;
        for (uint8 i = 0; i < numMilestones; i++) {
            milestone storage currMilestone = currService[i];
            if (currMilestone.serviceProvider == payable(_from)) {
                check = true;
            }
        }
        require(check, "Invalid Service Provider, unable to vote");
        _;
    }

/*
    Setter Functions
*/
    function setState(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, States.MilestoneStatus state) internal {
        servicesMilestones[projectNumber][serviceNumber][milestoneNumber].status = state;
    }

/*
    CUD Milestones
*/

    /*
        Milestone - Create
    */

    function createMilestone(uint256 projectNumber, uint256 serviceNumber, string memory title, string memory description, uint256 price) external payable
        requiredString(title)
        requiredString(description)
    {
        milestone storage newMilestone = servicesMilestones[projectNumber][serviceNumber][milestoneNum];
        newMilestone.projectNumber = projectNumber;
        newMilestone.serviceNumber = serviceNumber;
        newMilestone.milestoneNumber = milestoneNum;
        newMilestone.title = title;
        newMilestone.description = description;
        newMilestone.exist = true;
        newMilestone.status = States.MilestoneStatus.created;
        newMilestone.price = price;
        newMilestone.serviceRequester = payable(msg.sender);  

        emit milestoneCreated(projectNumber, serviceNumber, milestoneNum, title, description);

        milestoneTotal++;
        milestoneNum++;
    }


    /*
        Milestone - Read 
    */

    function readMilestoneTitle(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) external view 
        isValidMilestone(projectNumber, serviceNumber, milestoneNumber)
    returns (string memory) {
        return (servicesMilestones[projectNumber][serviceNumber][milestoneNumber].title);
    }

    /*
        Milestone - Update
    */

    function updateMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, string memory title, string memory description) external 
        // isValidMilestone(projectNumber, serviceNumber, milestoneNumber)//REMOVED FOR STACK ERROR
        atState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.created)
        requiredString(title)
        requiredString(description)
    {
        
        servicesMilestones[projectNumber][serviceNumber][milestoneNumber].title = title;
        servicesMilestones[projectNumber][serviceNumber][milestoneNumber].description = description;

        emit milestoneUpdated(projectNumber, serviceNumber, milestoneNumber, title, description);
    }

    /*
        Milestone - Delete
    */ 

    function deleteMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) external 
        isValidMilestone(projectNumber, serviceNumber, milestoneNumber)
        atState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.created)
    {
        servicesMilestones[projectNumber][serviceNumber][milestoneNumber].exist = false;        
        milestoneTotal--;
        setState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.terminated);
        emit milestoneDeleted(projectNumber, serviceNumber, milestoneNumber);


        //TRANSFER PRICE BACK TO PROJECT OWNER FROM ESCROW WALLET
    }

    /*
        Milestone - Accept
    */
    
    function acceptService(uint256 projectNumber, uint256 serviceNumber, address payable serviceProvider) external{
        // Accepts Service Contract, so all the Milestones are set to approved (locked in)
        for (uint i = 0; i < milestoneNum; i++){
            if(servicesMilestones[projectNumber][serviceNumber][i].status != States.MilestoneStatus.created ||
            servicesMilestones[projectNumber][serviceNumber][i].exist == false){ 
                continue; 
            }
            servicesMilestones[projectNumber][serviceNumber][i].serviceProvider = serviceProvider; 
            setState(projectNumber, serviceNumber, i, States.MilestoneStatus.approved);
            startNextMilestone(projectNumber, serviceNumber);
        }
    }

    /*
        Milestone - Start
    */

    function startNextMilestone(uint256 projectNumber, uint256 serviceNumber) internal {
        for (uint i = 0; i < milestoneNum; i++){
            if(servicesMilestones[projectNumber][serviceNumber][i].status == States.MilestoneStatus.approved &&
            servicesMilestones[projectNumber][serviceNumber][i].exist){ 
                startMilestone(projectNumber, serviceNumber, i);
                return ;
            }
        }
    }

    function startMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) private
        isValidMilestone(projectNumber, serviceNumber, milestoneNumber)
        atState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.approved)
    {
        setState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.started);
    }

    /*
        Milestone - Complete
    */
    function completeMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) public
        isValidMilestone(projectNumber, serviceNumber, milestoneNumber)
        atState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.started) // Must work on milestone in order
    {
        setState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.completed);
        startNextMilestone(projectNumber, serviceNumber);
    }

    /*
        Milestone - Verify milestone
    */
    function verifyMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, ERC20 erc20) public payable
        isValidMilestone(projectNumber, serviceNumber, milestoneNumber)
        atState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.completed) 
    {
        setState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.verified);

        //MAKE PAYment of price from escrow wallet to service provider 
        address payable receiver = payable(servicesMilestones[projectNumber][serviceNumber][milestoneNumber].serviceProvider);
        uint256 price = servicesMilestones[projectNumber][serviceNumber][milestoneNumber].price; 
        erc20.transfer(receiver, price);
    }

    /*
        Milestone - Review milestone
    */
    function reviewMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, address _from, string memory review_input, uint star_rating) public 
        isValidMilestone(projectNumber, serviceNumber, milestoneNumber)

    {
        milestone storage currMilestone = servicesMilestones[projectNumber][serviceNumber][milestoneNumber];
        address payable milestoneServiceProvider = currMilestone.serviceProvider;
        address payable milestoneServiceRequester = currMilestone.serviceRequester;
        require(milestoneServiceProvider == _from || milestoneServiceRequester == _from , " Invalid");
        require(currMilestone.status == States.MilestoneStatus.completed);

        if (milestoneServiceProvider == payable(_from)) {
            review.createReview(projectNumber,serviceNumber,milestoneNumber,payable(_from),milestoneServiceRequester,review_input,States.Role.serviceProvider,star_rating);
        } else {
            review.createReview(projectNumber,serviceNumber,milestoneNumber,payable(_from),milestoneServiceProvider,review_input,States.Role.serviceRequester,star_rating);
        }
    }

    /*
        Conflict - Create
    */ 
    
    function createConflict(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, string memory title, string memory description, address serviceRequester, address serviceProvider,  uint256 totalVoters) external 
        atState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.completed)
    {
        // Need to set requirement for service requestor?
        conflict.createConflict(projectNumber,serviceNumber,milestoneNumber,title,description,serviceRequester,serviceProvider,totalVoters);
        setState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.conflict);
    }

    /*
        Conflict - Update
    */

    function updateConflict(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, string memory title, string memory description) external 
        isValidMilestone(projectNumber, serviceNumber, milestoneNumber)
        atState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.conflict)
    {
        conflict.updateConflict(projectNumber,serviceNumber,milestoneNumber,title,description);
    }

    /*
        Conflict - Delete
    */ 

    function deleteConflict(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) external 
        isValidMilestone(projectNumber, serviceNumber, milestoneNumber)
        atState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.conflict)
    {
        conflict.deleteConflict(projectNumber,serviceNumber,milestoneNumber);  
        setState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.completed);
    }

    /*
        Conflict - Start Vote

    */

    function startVote(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) external
        isValidMilestone(projectNumber, serviceNumber, milestoneNumber)
        atState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.conflict)
    {
        conflict.startVote(projectNumber, serviceNumber, milestoneNumber);
    }
    
    /*
        Conflict - Vote
    */

    function voteConflict(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, address _from, uint8 vote) external 
        isValidMilestone(projectNumber, serviceNumber, milestoneNumber)
        atState(projectNumber, serviceNumber, milestoneNumber, States.MilestoneStatus.conflict)
        // checkDAO(projectNumber,serviceNumber,numMilestones,_from)
    {
        conflict.voteConflict(projectNumber,serviceNumber,milestoneNumber,_from,vote);
    }

    /*
        Conflict - Resolve payments
    */

    function resolveConflictPayment(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, ERC20 erc20) external payable
        isValidMilestone(projectNumber, serviceNumber, milestoneNumber)
    {
        uint result = conflict.getResults(projectNumber, serviceNumber, milestoneNumber);
        address payable provider = payable(servicesMilestones[projectNumber][serviceNumber][milestoneNumber].serviceProvider);
        address payable requester = payable(servicesMilestones[projectNumber][serviceNumber][milestoneNumber].serviceRequester);
        uint256 price = servicesMilestones[projectNumber][serviceNumber][milestoneNumber].price; 
        if (result == 2) {
            //service provider wins
            erc20.transfer(provider, price);
        } else {
            //split 50-50
            erc20.transfer(provider, price/2); 
            erc20.transfer(requester, price/2);
        }
    }




/*
    Getter Helper Functions
*/

    function getResults(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) public view returns (uint) {
        return conflict.getResults(projectNumber,serviceNumber,milestoneNumber);

        //If contractor wins, pay contractor full price. If contractor loses, pay contracto half price and pay service requester half price. 
    }

    function getConflictStatus(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) public view returns ( States.ConflictStatus ) {
        return conflict.getConflictStatus(projectNumber,serviceNumber,milestoneNumber);
    }

    function getVotesCollected(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) public view returns (uint256) {
        return conflict.getVotesCollected(projectNumber,serviceNumber,milestoneNumber);
    }

    function getVotesforRequester(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) public view returns (uint256) {
        return conflict.getVotesforRequester(projectNumber,serviceNumber,milestoneNumber);
    }

    function getMilestonePrice(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) public view returns (uint256) {
        return servicesMilestones[projectNumber][serviceNumber][milestoneNumber].price;
    }

    function getVotesforProvider(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) public view returns (uint256) {
        return conflict.getVotesforProvider(projectNumber,serviceNumber,milestoneNumber);
    }

    // Star Rating getters
    function getAvgServiceProviderStarRating(uint256 projectNumber, uint256 serviceNumber) public view returns (uint256) {
        return review.getAvgServiceProviderStarRating(projectNumber,serviceNumber);
    }

    // Star Rating getters
    function getAvgServiceRequesterStarRating(uint256 projectNumber, uint256 serviceNumber) public view returns (uint256) {
        return review.getAvgServiceRequesterStarRating(projectNumber,serviceNumber);
    }

}