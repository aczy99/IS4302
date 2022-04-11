// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "./Service.sol";
import "./States.sol";

/*
    Service Requester (Project Owner)
*/
contract Project {
    
    Service service; 

    constructor(Service serviceContract) public {
        service = serviceContract;
    }
    

    struct project {
        uint256 projectNumber; 
        string title;
        string description;
        address projectOwner; // defaults to address(0) , service requester
        bool exist; // allowing update such as soft delete of project - projectNum
        States.ProjectStatus projectstatus;
    }

    uint256 public projectTotal = 0; // Counts of number of projects existing , only true exist bool
    uint256 public projectNum = 0; // Project Number/ID , value only goes up, includes both true and false exist bool
    mapping(uint256 => project) public projects;

    event projectCreated(uint256 projectNumber, string title, string description, address projectOwner);
    event projectUpdated(uint256 projectNumber, string title, string description, address projectOwner);
    event projectDeleted(uint256 projectNumber, address projectOwner);

/*
    Modifiers
*/
    modifier checkValidProject(uint256 projectNumber) {
        require(projects[projectNumber].exist, "This project has not been created yet. Please create project first");
        require(projects[projectNumber].projectstatus == States.ProjectStatus.active, "This project is no longer active.");
        _;
    }

    modifier onlyOwner(uint256 projectNumber, address user) {
        require (projects[projectNumber].projectOwner == user, "You are not authorized to edit this project as you are not the creator");
        _;
    }

    modifier atState(uint256 projectNumber, States.ProjectStatus state){
        require(projects[projectNumber].projectstatus == state, "Cannot carry out this operation!");
        _;
    }


/*
    Project Owner Functions
*/

    /*
        Project - Create 
    */
    
    function createProject(string memory title, string memory description, address _from ) public {
                
        project storage newProject = projects[projectNum];
        newProject.projectNumber = projectNum;
        newProject.title = title;
        newProject.description = description;
        newProject.projectOwner = _from;
        newProject.exist = true;
        newProject.projectstatus = States.ProjectStatus.active;

        emit projectCreated(projectNum, title, description, _from);
        projectTotal++;
        projectNum++;
    }

    /*
        Project - Read 
    */

    function readProjectTitle(uint256 projectNumber) public view 
        checkValidProject(projectNumber)
        atState(projectNumber, States.ProjectStatus.active)
        returns (string memory)  
    {
            return projects[projectNumber].title;
    }

    /*
        Project - Update (only in active state)
    */
    
    function updateProject(uint256 projectNumber, string memory title, string memory description, address _from ) public 
        checkValidProject(projectNumber)
        onlyOwner(projectNumber,_from) 
        atState(projectNumber, States.ProjectStatus.active)
    {
        projects[projectNumber].title = title;
        projects[projectNumber].description = description;

        emit projectUpdated(projectNumber, title, description, _from);
    }

    /*
        Project - Delete (only in active state)
    */
    function deleteProject(uint256 projectNumber , address _from) public 
        checkValidProject(projectNumber)
        onlyOwner(projectNumber, _from) 
        atState(projectNumber, States.ProjectStatus.active)
    {

        projects[projectNumber].exist = false;

        projectTotal --;
        setState(projectNumber, States.ProjectStatus.inactive);
        emit projectDeleted(projectNumber, _from);
    }

    /*
        Service - Create
    */

    function createService(uint256 projectNumber, string memory title, string memory description, address _from) public 
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.createService(projectNumber,title,description,payable(_from));
    }

    /*
        Service - Read
    */

    function readServiceTitle(uint256 projectNumber, uint256 serviceNumber) public view 
        atState(projectNumber, States.ProjectStatus.active)
        returns (string memory)
    {
        service.readServiceTitle(projectNumber,serviceNumber);
    }

    /*
        Service - Update
    */

    function updateService(uint256 projectNumber, uint256 serviceNumber, string memory title, string memory description, uint256 price, States.ServiceStatus status, address _from) public 
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.updateService(projectNumber,serviceNumber,title,description,payable(_from));
    }

    /*
        Service - Delete
    */

    function deleteService(uint256 projectNumber, uint256 serviceNumber, address _from) public 
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.deleteService(projectNumber,serviceNumber,payable(_from));
    }

    /*
        Service - Accept service request  
        Function for project owner to accept a contractor's service 
    */

    function acceptServiceRequest(uint256 projectNumber, uint256 serviceNumber, address _from) external 
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.acceptServiceRequest(projectNumber,serviceNumber,payable(_from));
    }

    /*
        Service - Reject service request  
        Function for project owner to reject a contractor's service 
    */

    function rejectServiceRequest(uint256 projectNumber, uint256 serviceNumber, address _from) external 
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.rejectServiceRequest(projectNumber,serviceNumber,payable(_from));   
    }

    /*
        Milestone - Create
    */

    function createMilestone(uint256 projectNumber, uint256 serviceNumber, string memory titleMilestone, string memory descriptionMilestone, address _from) public 
        onlyOwner(projectNumber,msg.sender) 
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.createMilestone(projectNumber,serviceNumber,titleMilestone,descriptionMilestone, payable(_from));
    }

    /*
        Milestone - Read
    */   

    function readMilestoneTitle(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) public view 
        atState(projectNumber, States.ProjectStatus.active)
    returns (string memory) {
        service.readMilestoneTitle(projectNumber,serviceNumber,milestoneNumber);
    }

    /*
        Milestone - Update
    */

    function updateMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, string memory titleMilestone, string memory descriptionMilestone, address _from) public 
        onlyOwner(projectNumber,msg.sender) 
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.updateMilestone(projectNumber,serviceNumber,milestoneNumber,titleMilestone,descriptionMilestone, payable(_from));
    }

    /*
        Milestone - Delete
    */ 

    function deleteMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, address _from) public 
        onlyOwner(projectNumber,msg.sender) 
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.deleteMilestone(projectNumber,serviceNumber,milestoneNumber, payable(_from));
    }    

    /*
        Conflict - Create
    */ 
    
    function createConflict(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, string memory title, string memory description, address serviceRequester, uint256 totalVoters) external
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.createConflict(projectNumber,serviceNumber,milestoneNumber,title,description,serviceRequester,totalVoters);
    }

    /*
        Conflict - Update
    */

    function updateConflict(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, string memory title, string memory description) external 
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.updateConflict(projectNumber,serviceNumber,milestoneNumber,title,description);
    }

    /*
        Conflict - Delete
    */ 

    function deleteConflict(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) external  
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.deleteConflict(projectNumber,serviceNumber,milestoneNumber);  
    }

    /*
        Conflict - Start Vote
    */
    function startVote(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) external
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.startVote(projectNumber, serviceNumber, milestoneNumber);
    }

    /*
        Conflict - Vote
    */

    function voteConflict(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, address sender, uint8 vote) external 
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.voteConflict(projectNumber,serviceNumber,milestoneNumber,sender,vote);
    }

/*
    Getter Helper Functions
*/

    function getProjectOwner(uint256 projectId) public view returns(address) {
        projects[projectId].projectOwner;
    }

/*
    Setter Functions
*/

    function setState(uint256 projectId, States.ProjectStatus state) internal {
        projects[projectId].projectstatus = state;
    }

/*
    Service provider Functions
*/

    /*
        Service - Request to start service 
        Function for contractor to request to start a service 
    */
    
    function takeServiceRequest(uint256 projectNumber, uint256 serviceNumber, address _from) public  
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.takeServiceRequest(projectNumber, serviceNumber, payable(_from)); 
    }

    /*
        Service - Complete service request
    */

    function completeServiceRequest(uint256 projectNumber, uint256 serviceNumber, address _from) external  
        atState(projectNumber, States.ProjectStatus.active)
    {
        service.completeServiceRequest(projectNumber, serviceNumber, payable(_from));      
    }

 
    /*
        Milestone - Complete 
    */
    function completeMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) external 
        atState(projectNumber, States.ProjectStatus.active)
    {
        // To report the completion of the milestone
        service.completeMilestone(projectNumber, serviceNumber, milestoneNumber);
    }

    /*
        Milestone - Verify 
    */
    function verifyMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber) external 
        atState(projectNumber, States.ProjectStatus.active)
    {
        // To report the completion of the milestone
        service.verifyMilestone(projectNumber, serviceNumber, milestoneNumber);
    }

    /*
        Review - Create
    */

    function reviewMilestone(uint256 projectNumber, uint256 serviceNumber, uint256 milestoneNumber, address _from, string memory review_input, uint star_rating) public {
        service.reviewMilestone(projectNumber,serviceNumber,milestoneNumber,_from,review_input,star_rating);
    }

    /*
        Review - Getter Provider Stars
    */

    function getAvgServiceProviderStarRating(uint256 projectNumber, uint256 serviceNumber) public view returns (uint256) {
        return service.getAvgServiceProviderStarRating(projectNumber,serviceNumber);
    }

    /*
        Review - Getter Requester Stars
    */

    function getAvgServiceRequesterStarRating(uint256 projectNumber, uint256 serviceNumber) public view returns (uint256) {
        return service.getAvgServiceRequesterStarRating(projectNumber,serviceNumber);
    }

}