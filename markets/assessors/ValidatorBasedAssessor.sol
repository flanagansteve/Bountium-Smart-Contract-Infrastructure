pragma solidity ^0.5.1;

import "./Assessor.sol";

// A very, very general starting point for assessors that use designated
// validators to judge bounties:
contract ValidatorBasedAssessor is Assessor {

  /*
   * A Validator is a user capable of judging claimed completions of jobs on this
   * Assessor, either pass/fail on a single job, or picking the best one among many
   * At a minimum, we need the address of the validator in order to keep a list
   * of who the validators are.
   */
  address payable[] public approvedValidators;
  /*
   * Setting this is a key part of implementation; do validators apply and get
   * dynamically accepted, with the contract somehow measuring their expertise?
   * Does the market operator hand pick them? Do market participants vote on them?
   * Do validators stake for acceptance? Do existing validators vote on new ones?
     * LevelK's token curated registry, or HumanityDAO's mechanism for accepting
     * humans, could be starting points
   * One day, validators could even be AI. Use the data gathered from all the
   * past validation decisions, set up an AI as a bot with an address to look
   * at jobs and make assessments, and collect passive income
   */

  /*
   * It would be highly beneficial to include other stuff, such as reputation
   * scores, a history of their submitted votes, and links to evidence of their
   * expertise in a struct. For example:
   struct Validator {
     uint reputation;
     uint[] pastJudgedBounties;
     string linkToResearchgateProfile;
   }
   * Implementers then can map addresses to Validators, iterate through the
   * address array of approved validators and do a mapping lookup to get
   * auxiliary data
   */

  /*
   * Several functions for assessors of this type should be restricted to
   * validators only:
   */
  modifier validatorsOnly() {
    bool sentByValidator = false;
    for (uint i = 0; i < approvedValidators.length; i++)
      if (approvedValidators[i] == msg.sender)
        sentByValidator = true;
    require(sentByValidator);
    _;
  }

}

// An abstract contract for an assessor that:
//   - records validators and lets new ones apply
//   - lets validators set specs on a job
//   - lets someone respond to a job, and then lets validators decide whether a
//   response meets the specs - acting as trusted third party judges
  // Implementers need to decide on:
    // How do you add validators to the list? [in constructor() or
    // applyToValidate()]
    // Does every job require the same # of validations, or does a poster decide
    // this? Or, does the job auto-complete after a certain amt of time,
    // and the validators are only called in case of dispute during the
    // grace period? [in submit()]
    // How to keep track of/weigh a validator's performance over time?
    // [in vote()]
    // Which validators can vote on which jobs - just the spec authors on
    // a job? Any validators? [in vote()]
    // If/how to reward validators [transfer back in vote(), or in custom func.
    // set some relevant global vals in constructor]
    // What format bounty.data is in? [in viewBountyInfo()]
contract ValidatorsPassJobs is ValidatorBasedAssessor {

  struct Bounty {
    // Whether the job is available for attempting:
    bool available;
    // The data relevant to a job may be of any format - let the presentation
    // layer decipher it:
    bytes data;
    // The total votes needed to make a decision about a response's quality
    // Some implementations may set this automatically in submit, or let the
    // poster send this as a field of "bytes calldata data"
    uint quorum;
    // Whether the job was finished:
    bool completed;
    // Who finished it (if unfinished, this is the poster's address):
    address payable completer;
    // Optional - notes/specs/tests that validators can put on a job for
    // transparency on how they'll be judging:
    bytes[] validatorSpecs;
    address payable[] specAuthors;
    // The current response:
    bytes response;
    // The validators' opinions on the job:
    bool[] votes;
  }
  Bounty[] public bounties;

  /*
   * Several functions that mutate a bounty/manage its completion status or work
   * with validators should only be accessible to the poster
   */
  modifier posterMutation(uint bountyID) {
    // Do not mutate a bounty once its been completed
    require(!bounties[bountyID].completed);
    // Ensure sender is poster
    require(bounties[bountyID].completer == msg.sender);
    _;
  }

  /*
   * Several functions should be called with an ID for a bounty that exists
   */
  modifier existingBounties(uint bountyID) {
    require(bounties.length > bountyID && bountyID >= 0);
    _;
  }

  // @Override this to set global field for quorum if you choose, and to
  // potentially instantiate some initially chosen validators
  // [obviously can't declare this in abstract contract - here for clarity]
  // constructor() public;

  // @Override this
  // Candidate validators call this function, and the function either:
  //  - performs some check on applicationData to decide immediately
  //  - records the application, allowing the contract to make the decision at
  //  a later date (perhaps after aggregating votes from some group)
  function applyToValidate(bytes memory applicationData) public;

  // @Override this to manage whether the poster sets bounty.quorum, or whether
  // there's a standard quorum across the market
  function submit(bytes calldata data) external existingBounties(bountyID) returns(bool received, uint bountyID) {
    bounties.push(Bounty(false, data, 0, false, msg.sender, new bytes[](0), new address payable[](0), "", new bool[](0)));
    emit RequestReceived(bounties.length - 1, msg.sender);
    return (true, bounties.length - 1);
  }

  // Add specifations/qualifiers/tests that validators deem to represent
  // the posters needs
  function addSpec(uint bountyID, bytes memory spec) public validatorsOnly existingBounties(bountyID) {
    require(!bounties[bountyID].completed);
    bounties[bountyID].validatorSpecs.push(spec);
    bounties[bountyID].specAuthors.push(msg.sender);
  }

  // @Override this to manage how validators' vote history gets recorded and
  // weighed. Currently, history is just ignored, but this still works
  // @Override this to manage which validators can vote on which jobs
  function vote(uint bountyID, bool approved) public validatorsOnly existingBounties(bountyID) {
    // Only let this job's spec authors vote on this job:
    // [remove to let any validators vote on this job]
    require(contains(bounties[bountyID].specAuthors, msg.sender));
    require(!bounties[bountyID].completed);
    bounties[bountyID].votes.push(approved);
    if (bounties[bountyID].votes.length >= bounties[bountyID].quorum) {
      bounties[bountyID].completed = countVotes(bountyID);
      bounties[bountyID].available = false;
    }
    // Here, you would reflect the quality of this vote somehow on the validator,
    // and most likely put it in their history
  }

  // @Override this if you don't want to use a simple majority to validate
  function countVotes(uint bountyID) internal view returns (bool correct) {
    uint votesFor;
    for (uint i = 0; i < bounties[bountyID].votes.length; i++)
      if (bounties[bountyID].votes[i])
        votesFor++;
    return votesFor > (bounties[bountyID].quorum / 2);
  }

  // make the job available - jobs are unavailable by default so that the post
  // has time to first receive specs from validators, allowing the poster to
  // come back and make it available if the specs meet their needs
  // @Override this if you wish to set specific conditions for a job's availability
  // - perhaps letting the poster reject specs that they don't feel match
  // their needs, or perhaps automatically making a job available upon a certain
  // number of specs being received
  function markAvailable(uint bountyID) public posterMutation(bountyID) existingBounties(bountyID) {
    bounties[bountyID].available = true;
  }

  // A poster that does this is obviously forfeiting rights to dispute/
  // any validation opinions that are yet to come
  function markComplete(uint bountyID) public posterMutation(bountyID) existingBounties(bountyID) {
    bounties[bountyID].completed = true;
  }

  // Store a response from someone claiming to complete a job
  function respond(uint bountyID, bytes memory claim) public existingBounties(bountyID) returns (bool received) {
    require(bounties[bountyID].available);
    require(!bounties[bountyID].completed);
    bounties[bountyID].response = claim;
    return true;
  }

  // tells whether an array contains the passed address. wish this was builtin
  function contains(address payable[] memory arr, address x) private pure returns(bool) {
    for (uint i = 0; i < arr.length; i++)
      if (arr[i] == x)
        return true;
    return false;
  }

  // Whether a job has been assessed as completed
  function completed(uint bountyID) public view existingBounties(bountyID) returns (bool completed_, address payable completer) {
    return (bounties[bountyID].completed, bounties[bountyID].completer);
  }

  // @Override this to set a data type - i have had success using json
  // with pitterpatter. the bytes of data represent a json string
  function viewBountyInfo(uint bountyID) public view returns (bytes memory bountyInfo, string memory infoType);

}

// This is for a market in which the poster is the validator - provides quals/
// tests, and has the only say in if & when the money gets released. Useful
// for B2B Software contracts, formalising a hiring company's expectations
// and providing an immutable reference when time comes to pay
contract PosterPassesJobs is ValidatorsPassJobs {

  function submit(bytes calldata data) external existingBounties(bountyID) returns(bool received, uint bountyID) {
    // Quorum is 1 for all posts on this market since only the poster can vote
    bounties.push(Bounty(false, data, 1, false, msg.sender, new bytes[](0), new address payable[](0), "", new bool[](0)));
    emit RequestReceived(bounties.length - 1, msg.sender);
    // Push the poster to the validator arr [but they can only add specs, and
    // therefore vote, on their own post]
    approvedValidators.push(msg.sender);
    return (true, bounties.length - 1);
  }

  // Here, a poster can put their qualification info/tests as "spec"
  function addSpec(uint bountyID, bytes memory spec) public validatorsOnly existingBounties(bountyID) {
    require (!bounties[bountyID].completed);
    // Only the poster can add a spec:
    require (bounties[bountyID].completer == msg.sender);
    bounties[bountyID].validatorSpecs.push(spec);
    bounties[bountyID].specAuthors.push(msg.sender);
    // Since only the poster interacts with the job, we can also make it available:
    bounties[bountyID].available = true;
  }

}

// Similar to the above, this one instead lets jobs receive multiple responses
// and lets validators pick the best one
contract ValidatorsPickWinner is ValidatorBasedAssessor {

  // Coming soon!

}
