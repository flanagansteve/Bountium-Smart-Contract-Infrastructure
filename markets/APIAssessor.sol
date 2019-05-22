pragma solidity ^0.5.1;

import "./StringBasedMarkets.sol";

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
  // TODO consider tracking how often an API provider has lead to a successfully
  // assessed tx to display trustfulness to propsective workers AND to suggest
  // popular APIs to posters
  // TODO perhaps make a registrar of APIs and tag them by category???
  string public apiUrl;
  bool apiSet;

  // Override: require the data a user sends to have an api field
  function submit(bytes memory data) public returns (bool received, uint bountyID) {
    // TODO: convert to json string, require(has apiField)
    // then, same as always:
    super();
  }

  // Override: get the api associated with this job and request to it with
  // data:claim to make the assessment
  function assess(uint bountyID, bytes memory claim) internal view returns (bool correct) {
    // TODO get api field of bounties[bountyID]
    // TODO make a request to api field with data:claim, return response
  }
}
