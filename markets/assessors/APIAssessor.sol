pragma solidity ^0.5.1;

import "./StringBasedAssessors.sol";
import "../../util/StringManipulation.sol";

// This is an assessor where the market author sets an API that all jobs post
// relevant tests to (example: test ci/cl for coding jobs!), and the assessment
// mechanism communicates with the API to make its decision.
  // Note: this market type's reliability, QA, and trustlessness is obviously
  // only as good as the API its tied to. Users of these markets should be sure
  // to hold these APIs to a high standard. Since the contract's design is pretty
  // open-ended, the API could definitely be a decentralised one!
contract SharedAPIAssessor is JSONInstruction {

  string public apiUrl;
  bool apiSet;

  constructor(string memory apiUrl_) public {
    if (!apiSet)
      apiUrl = apiUrl_;
    apiSet = true;
  }

  // Override: form request to this.apiUrl (with id:bountyID and data:claim)
  // to make the assessment
  function assess(uint bountyID, bytes memory claim) internal view returns (bool correct) {
    if (!apiSet) {
      return false;
    }
    else {
      // TODO make a request to apiUrl with id:bountyID and data:claim, return response
    }
  }

}

// This is an assessor where each poster provides their own API, and the
// contract calls that.
  // Note: Obviously, the assessment of a job hinges on the job's specific API,
  // so workers should be wary and make a call on the trustworthiness of the
  // provided API.
contract SpecificAPIAssessor is JSONInstruction {

  using strings for *;

  // Override: require the data a user sends to have an api field
  // Note: This implementation requires that a post contains a field specifically
  // named 'apiUrl', case-sensitive, to be used as the oracle for assessing this job
  function submit(bytes memory data) public returns (bool received, uint bountyID) {
    // Ensure that the submitted post has an apiUrl
    string memory posting = string(data);
    // [I know that this chaining is gross but its difficult to break it out
    // into multiple lines while also converting the solidity 0.4.x examples -
    // someone else can feel free to do it if it bothers them]
    require(!posting.toSlice().copy().find("apiUrl".toSlice()).empty());
    // If so, accept it
    reqs.push(JSONReq(posting, false, msg.sender));
    emit RequestReceived(reqs.length - 1, msg.sender);
    return (true, reqs.length - 1);
  }

  // Override: get the api associated with this job and request to it with
  // data:claim to make the assessment
  function assess(uint bountyID, bytes memory claim) internal view returns (bool correct) {
    // get api field of bounties[bountyID]
    // More gross chaining - i wanna vomit
    string memory apiUrl = reqs[bountyID].instructionsObject.toSlice().copy().find("apiUrl".toSlice()).toString();
    // TODO cut off api url at next } or ,
    // TODO make a request to api field with data:claim, return response
      // But: how do you generate a request to the API ~from~ a contract?
      // is that possible? through oraclize perhaps?
      // one idea: instead of having the contract itself generating the request,
      // have the claimant make the request and supply the response output as
      // their claim - and have it signed by the api to prevent just faking output
  }
}
