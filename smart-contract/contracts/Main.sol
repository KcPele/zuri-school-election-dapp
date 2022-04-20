// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

/** 
 * @title Zuri School Voting
 * @dev Implements voting process along with vote delegation
 */
contract ZuriSchoolVoting {

    enum Stakeholder {
       DIRECTOR,
       TEACHER,
       STUDENT
    }

    //@dev this is the voter struct that is used to hold the details of a voter
    struct Voter {
        string name;
        bool canVote;
        Stakeholder userType;
    }
    

    //@dev this is a proposal on the contract, a proposal is simply an option in an election
    struct Proposal {
        string name;   // short name (up to 32 bytes)
        uint voteCount; // number of accumulated votes
    }

    //@dev this defines a ballot struct which is used to store a single election instance
    struct Election {
        uint256 _id;
        uint256 num_choices;
        string name;
        string description;
        bool active;
        bool computed;
    }

    // @dev this is used to keep track of the count of elections
    uint256 public electionCount = 0;

    // @dev store the address of the chairperson
    address public chairperson;

    // @dev store the name of the school
    string public schoolName;

    // @dev keep track of all the registered voters on the contract
    address[] voterAddresses;

    // @dev a mapping that maps the address of a voter to the voter struct
    mapping(address => Voter) public voters;

    // @dev a mapping that keeps track of an election id to the election struct
    mapping(uint256 => Election) public elections;

    // @dev this is a mapping of mappings used to keep track of if a voter has voted in an election already
    mapping(uint256 => mapping(address=>bool)) hasVoted;

    // @dev this is used to keep track of the weight of the votes of a specific user type
    mapping(Stakeholder => uint256) weights;

    // @dev this is used to keep track of the timers for the various elections
    mapping(uint256=>uint256) timers;

    // @dev this is used to keep track of the winnig proposal for each election
    mapping(uint256=>Proposal) winners;
    
    // @dev this is a mapping to track the choices for various elections
    mapping(uint256=>Proposal[]) choices;

    


    /**
        This section covers modifiers that control access for all the different stakeholders
     */


    // @dev this is used to assert that the person calling a contract method is a student
    modifier isStudent(){
       require(voters[msg.sender].userType == Stakeholder.STUDENT, "only students can perform this operation");
       _;
    } 

    // @dev this is used to assert that the person calling a contract method is the chairperson
    modifier isChairperson(){
        require(msg.sender == chairperson, "only chairperson can perform this operation");
        _;
    }

    // @dev this is used to assert that the person calling a contract method is a teacher
    modifier isTeacher(){
        require(voters[msg.sender].userType == Stakeholder.TEACHER, "only teachers can perform this operation");
        _;
    }

    // @dev this is used to assert that the person calling a contract method is a director
    modifier isDirector(){
        require(voters[msg.sender].userType == Stakeholder.DIRECTOR, "only director can perform this operation");
        _;
    }

    // @dev this is used to assert that the person calling the method is either a director or a teacher
    modifier isDirectorOrTeacher(){
        require(
            voters[msg.sender].userType == Stakeholder.DIRECTOR || voters[msg.sender].userType == Stakeholder.TEACHER, 
            "only directors and teachers can perform this operation"
        );
        _;
    }

    // @setup for all the various events carried out on the contract. All events are declared here.
    event StudentCreated(string name, address _student);
    event DirectorCreated(string name, address _director);
    event TeacherCreated(string name, address _teacher);
    event BallotCreated(uint256 _id, string name, uint256 time);
    event voteCasted(uint256 _electionId, address _voter);
    event BallotStarted(uint256 _id, string name, uint256 time);
    event BallotStoped(uint256 _id, string name, uint256 time);



    /**
     * @notice setup voting smart contract defaults
     * @dev setup chairperson, stakeholders vote weights & school name
     * @param _schoolName name of school that owns the contract
     */
    constructor(string memory _schoolName) {
        chairperson = msg.sender;
        schoolName = _schoolName;

        _initializeStakeholdersVoteWeight(1);

        // create director voter for chairperson
        Voter memory _voter = Voter("chairperson", true, Stakeholder.DIRECTOR);
        _addVoter(msg.sender, _voter);

        emit DirectorCreated("chairperson", msg.sender);
    }

    /**
     * @notice check if address belongs to chairperson
     * @dev check if address matches stored chairperson address
     * @param _chairperson address to verify if belongs to chairperson
     * @return bool
     */
    function iamChairperson(address _chairperson) external view returns(bool){
        if(chairperson == _chairperson) { return true; }

        return false;
    }

    /**
     * @notice add a student voter to the system
     * @dev add a student voter to the system
     * @param _name name of the student
     * @param _student student wallet address
     */
    function addStudent(string memory _name, address _student) external isChairperson {
        Voter memory _voter = Voter(_name, true, Stakeholder.STUDENT);
        _addVoter(_student, _voter);

        emit StudentCreated(_name, _student);
    }

    /**
     * @notice check if address has been registered to vote
     * @dev check if address is in the list of voter addresses
     * @param _voter voter address or identifier
     * @return bool
     */
    function _isVoter(address _voter) private view returns(bool) {
        for(uint256 i = 0; i < voterAddresses.length; i++) {
            if(voterAddresses[i] == _voter) { return true; }
        }

        return false;
    }

    /**
     * @notice add a voter to the system
     * @dev add an address to our list of voters on the contract
     * @param _voter voter wallet address
     * @param _voterData voter information including name, canVote & userType
     */
    function _addVoter(address _voter, Voter memory _voterData) private {
        if (!_isVoter(_voter)) {
            voterAddresses.push(_voter);
            voters[_voter] = _voterData;
        }
    }

    /**
     * @notice set stakeholders initial vote weight
     * @dev initialize stakeholders vote weight
     * @param _weight vote weight
     */
    function _initializeStakeholdersVoteWeight(uint _weight) private {
        weights[Stakeholder.STUDENT] = _weight;
        weights[Stakeholder.TEACHER] = _weight;
        weights[Stakeholder.DIRECTOR] = _weight;
    }

    // @function used to check if two strings are equal  todo @KC


    // @function that returns details about a user whose address is passed todo @KC
    function whoami(address _voter) public view returns(string memory name, string memory usertype, bool canVote){
        string memory _usertype = "student";
        if(voters[_voter].user_type == Stakeholder.TEACHER){
            _usertype = "teacher";
        } else if(voters[_voter].user_type == Stakeholder.DIRECTOR){
            _usertype = "director";
        }

        return (voters[_voter].name, _usertype, voters[_voter].canVote);
    }



    // @function that is used to create a student voter todo @KC
 function addStudent(string memory _name, address _student) public isChairperson {
        Voter memory _voter = Voter(_name, true, Stakeholder.STUDENT);
        voters[_student]  = _voter;
        addVoter(_student);
        emit StudentCreated(_name, _student);
    }

    // @function that is used to create a teacher voter todo @KC
 function addTeacher(string memory _name, address _teacher) public isChairperson {
        Voter memory _voter = Voter(_name, true, Stakeholder.TEACHER);
        voters[_teacher]  = _voter;
        addVoter(_teacher);
        emit TeacherCreated(_name, _teacher);
    }


    // @function that is used to create a director voter todo @KC
 function addDirector(string memory _name, address _director) public isChairperson {
        Voter memory _voter = Voter(_name, true, Stakeholder.DIRECTOR);
        voters[_director]  = _voter;
        addVoter(_director);
        emit DirectorCreated(_name, _director);
    }


    // @function that is used for creating an election either by a teacher or director todo @cptMoh
    // @dev this function is used for creating an election either by a teacher or director
    function createElection(string memory _name, uint256 _num_choices, string memory _description, string[] memory _choices, uint256 numHours) public isDirectorOrTeacher {
        require(_num_choices > 1, "must have more than one choice to create election");
        require(_num_choices == _choices.length, "number of proposals must equal number of choices");
    
        uint _id = electionCount;

        uint expirationTime = block.timestamp + (numHours * (60*60));
        Election memory _election = Election(_id, _num_choices, _name, _description, false, false);
        for (uint256 i = 0; i < _num_choices; i++) {
            Proposal memory _proposal = Proposal(_choices[i], 0);
            choices[_id].push(_proposal);
        }
        timers[electionCount] = expirationTime;
        elections[_id] = _election;
        electionCount ++;
        emit BallotCreated(_id, _name, expirationTime);
    }



    // @function that is used to cast the vote of an election todo @cptMoh
    // @dev this function is used to cast the vote of an election
    function castVote(uint256 _electionId, uint256 _proposalIndex) public {
        require(elections[_electionId].active == true, "election must be active to cast a vote");
        require(elections[_electionId].computed == false, "election result has already been computed, can not cast vote");
        require(timers[_electionId] >= block.timestamp, "election period has expired can not cast vote");
        require(voters[msg.sender].canVote == true, "you must be allowed to vote to perform this operation");
        require(hasVoted[_electionId][msg.sender] == false, "you have already voted for this election");

        // cast a vote based on the weight of that specific user type
        choices[_electionId][_proposalIndex].voteCount += weights[voters[msg.sender].userType];
        hasVoted[_electionId][msg.sender] = true;

        emit voteCasted(_electionId, msg.sender);
    }



    // @function used to start an election. should only be called by chairperson todo @cptMoh
    function startElection(uint256 _electionId) public isChairperson{
        elections[_electionId].active = true;
        emit BallotStarted(_electionId, elections[_electionId].name, block.timestamp);
    }



    // @function used to stop an election. should only be called by chairpairson todo @cptMoh
    // @dev this is a function to stop an election
    function stopElection(uint256 _electionId) public isChairperson {
        elections[_electionId].active = false;
        timers[_electionId] = block.timestamp; 
        emit BallotStoped(_electionId, elections[_electionId].name, block.timestamp);
    }




    /**
     * @notice view the details of an election
     * @dev view election detailsl
     * @param _electionId the id of the election you want to view its details
     */
    function viewElection(uint256 _electionId) public view returns(string memory name, string[] memory props, bool isActive, bool isComputed){
        string[] memory proposals = new string[](choices[_electionId].length);
        for(uint256 i=0; i < choices[_electionId].length; i++){
            proposals[i] = choices[_electionId][i].name;
        } 
        return (elections[_electionId].name, proposals, elections[_electionId].active, elections[_electionId].computed);
    }




    /**
     * @notice view the stats of an ongoing or completed election
     * @dev view election statistics
     * @param _electionId the id of the election you want to view the statistics of
     */
    function viewElectionStats(uint256 _electionId) public view returns(string[] memory names, string[] memory user_types, bool[] memory canVotes, bool[] memory hasVoteds){
  
        string[] memory _names = new string[](voter_addresses.length);
        string[] memory _user_types = new string[](voter_addresses.length);
        bool[] memory _canVotes = new bool[](voter_addresses.length);
        bool[] memory _hasVoteds = new bool[](voter_addresses.length);

        for(uint256 i = 0; i < voter_addresses.length; i++){
            _names[i] = voters[voter_addresses[i]].name;
            string memory _user_type = "";
            if(voters[voter_addresses[i]].user_type == Stakeholder.STUDENT){
                _user_type = "student";
            } else if (voters[voter_addresses[i]].user_type == Stakeholder.TEACHER){
                _user_type = "teacher";
            } else {
                _user_type = "director";
            }
            _user_types[i] = _user_type;
            _canVotes[i] = voters[voter_addresses[i]].canVote;
            _hasVoteds[i] = hasVoted[_electionId][voter_addresses[i]];
        }
        return (_names, _user_types, _canVotes, _hasVoteds);
    }



     /**
     * @notice compile the results of an election, the election is automatically stopped when the result is compiled
     * @dev compile election results
     * @param _electionId the id of the election you want to compile the results for
     */
    function compileResults(uint256 _electionId) public isDirectorOrTeacher {
        stopElection(_electionId);
        elections[_electionId].computed = true;

        Proposal memory _max = choices[_electionId][0];
        for(uint256 i = 1; i < choices[_electionId].length; i++){
          if(choices[_electionId][i].voteCount > _max.voteCount){
              _max = choices[_electionId][i];
          }
        }

        winners[_electionId] = _max;
        emit BallotResultCompiled(_electionId, elections[_electionId].name, block.timestamp);
    }


    /**
     * @notice view the results of a completed election
     * @dev view results of an election
     * @param _electionId the id of the election you want to view the results for
     */
    function viewResult(uint256 _electionId) public view returns(string memory electionName, string memory proposalName, uint256 voteCount){
        require(elections[_electionId].computed == true, "results have not yet been compiled");
        return (elections[_electionId].name, winners[_electionId].name, winners[_electionId].voteCount);
    }


    /**
     * @notice manually set the weights for a particular voter type
     * @dev adjust voter type vote weights
     * @param stakeholder is the name of the voter type you want to set the weights for
     * @param weight is the value you want to set the weight to
     */
    function setWeight(string memory stakeholder, uint256 weight) public isChairperson {
        require(weight >= 0, "weights can not be less than 1");
        if(stringsEquals(stakeholder,"student")){
            weights[Stakeholder.STUDENT] = weight;
        } else if(stringsEquals(stakeholder,"teacher")){
            weights[Stakeholder.TEACHER] = weight;
        } else if(stringsEquals(stakeholder,"director")){
            weights[Stakeholder.DIRECTOR]  = weight;
        }else {
            require(false, "invalid stakeholder name entered");
        }
    }


    /**
     * @notice ban a voter from participating in elections
     * @dev ban a voter from voting
     * @param _voter the voter's wallet address
     */
    function banVoter(address _voter) public isChairperson {
        voters[_voter].canVote = false;
        emit BanVoter(voters[_voter].name, _voter);
    }



    /**
     * @notice unban a voter from participating in elections
     * @dev unban a voter from voting
     * @param _voter the voter's wallet address
     */
    function unbanVoter(address _voter) public isChairperson{
        voters[_voter].canVote = true;
        emit UnbanVoter(voters[_voter].name, _voter);
    }


}

