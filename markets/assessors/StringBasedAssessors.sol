pragma solidity ^0.5.1;

import "./Assessor.sol";

// Example simple string assessor. Currently trustful - assess() does nothing
// Users can submit a request with a string of their instructions
contract StringInstruction is Assessor {

  struct SimpleReq {
    string instructions;
    bool completed;
    address payable completer;
  }
  SimpleReq[] reqs;

  function submit(bytes memory data) public returns (bool received, uint bountyID) {
    reqs.push(SimpleReq(string(data), false, msg.sender));
    emit RequestReceived(reqs.length - 1, msg.sender);
    return (true, reqs.length - 1);
  }

  function respond(uint bountyID, bytes memory claim) public returns (bool received) {
    require(!reqs[bountyID].completed);
    // TODO this is the key part where we assess correctness. Maybe worth abstracting??
    reqs[bountyID].completed = assess(bountyID, claim);
    if (reqs[bountyID].completed)
      reqs[bountyID].completer = msg.sender;
    return true;
  }

  function assess(uint bountyID, bytes memory claim) internal view returns (bool correct) {
    // TODO how to assess their claim
    return true;
  }

  function completed(uint bountyID) public view returns (bool completed_, address payable completer) {
    return (reqs[bountyID].completed, reqs[bountyID].completer);
  }

  // public for debugging purposes, will be internal
  // from: https://ethereum.stackexchange.com/a/9152
  function stringToBytes(string memory source) public pure returns (bytes memory result) {
    result = bytes(source);
  }

  // public for debugging, will be internal
  function bytes32ToBytes(bytes32 b32) public pure returns (bytes memory b) {
    b = new bytes(32);
    assembly { mstore(add(b, 32), b32) }
    return b;
  }

  function viewBountyInfo(uint bountyID) public view returns(bytes memory bountyInfo, string memory infoType) {
    return (stringToBytes(reqs[bountyID].instructions), "string");
  }

}

// Similarly, this contract is also a trustful example with
// no assess() built yet. It lets users submit a JSON string that
// will be appropriately parsed on the front end
contract JSONInstruction is Assessor {

  struct JSONReq {
    string instructionsObject;
    bool completed;
    address payable completer;
  }
  JSONReq[] reqs;

  function submit(bytes memory data) public returns (bool received, uint bountyID) {
    reqs.push(JSONReq(string(data), false, msg.sender));
    emit RequestReceived(reqs.length - 1, msg.sender);
    return (true, reqs.length - 1);
  }

  function respond(uint bountyID, bytes memory claim) public returns (bool received) {
    require(!reqs[bountyID].completed);
    // TODO this is the key part where we assess correctness. Maybe worth abstracting??
    reqs[bountyID].completed = assess(bountyID, claim);
    if (reqs[bountyID].completed)
      reqs[bountyID].completer = msg.sender;
    return true;
  }

  function assess(uint bountyID, bytes memory claim) internal view returns (bool correct) {
    // TODO how to assess their claim
    return true;
  }

  function completed(uint bountyID) public view returns (bool completed_, address payable completer) {
    return (reqs[bountyID].completed, reqs[bountyID].completer);
  }

  // public for debugging purposes, will be internal
  // from: https://ethereum.stackexchange.com/a/9152
  function stringToBytes(string memory source) public pure returns (bytes memory result) {
    result = bytes(source);
  }

  // public for debugging, will be internal
  function bytes32ToBytes(bytes32 b32) public pure returns (bytes memory b) {
    b = new bytes(32);
    assembly { mstore(add(b, 32), b32) }
    return b;
  }

  function viewBountyInfo(uint bountyID) public view returns(bytes memory bountyInfo, string memory infoType) {
    return (stringToBytes(reqs[bountyID].instructionsObject), "jsonObj");
  }
}
