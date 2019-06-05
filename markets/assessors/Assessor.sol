pragma solidity ^0.5.1;

// The following is the Assessor framework. Each smart contract is an
// entity to which people can make requests, and to which people can claim to
// have fulfilled the request by supplying evidence. This evidence is then assessed
// in any number of ways:
//    - Could be objectively assessed in the contract itself
//    - Could have the contract query an API to assess it
//    - Could require third parties to approve it
//    - Could require the original poster to approve it
//    - Could require submitter to create an augur market to assess correctness
//    - Could have the claimant submit info only a successful claimant could have,
//    such as the time of day the event should come to pass (prior to it passing)

interface Assessor {

  event RequestReceived(uint bountyID, address sender);

  // a way to submit arbitrary data for an available request
  function submit(bytes calldata data) external returns(bool received, uint bountyID);

  // Tells whether this question has been satisfactorily completed
  function completed(uint bountyID) external view returns(bool completed_, address payable completer);

  // Submit a response here
  function respond(uint bountyID, bytes calldata claim) external returns (bool received);

  // View info and specifics about a bounty here. To keep this interface
  // data-type agnostic, we return the raw bytes of the bounty info, and
  // a string representing what data type the bountyInfo is - the strings
  // representing each type should correspond to solidity keywords, ie
  // "uint", "string", etc.
  function viewBountyInfo(uint bountyID) external view returns (bytes memory bountyInfo, string memory infoType);

  // Mechanism for validating a response - either by running an operation on the
  // data, making a comparison, tallying votes, etc
  // TODO solidity 0.5.x doesn't let me compile this.
  //function assess(uint bountyID, bytes memory data) internal view returns (bool);

}

// A silly example of one such assessor - guessing numbers for bounties
contract GuessMyNum is Assessor {

  struct Secret {
    uint num;
    bool guessed;
    address payable guesser;
  }
  Secret[] secrets;

  function submit(bytes memory data) public returns (bool received, uint bountyID) {
    secrets.push(Secret(bytesToUint(data, 0), false, msg.sender));
    emit RequestReceived(secrets.length - 1, msg.sender);
    return (true, secrets.length - 1);
  }

  function respond(uint bountyID, bytes memory claim) public returns (bool received) {
    require(!secrets[bountyID].guessed);
    // TODO this is the key part where we assess correctness. Maybe worth abstracting??
    secrets[bountyID].guessed = assess(bountyID, claim);
    if (secrets[bountyID].guessed)
      secrets[bountyID].guesser = msg.sender;
    return true;
  }

  function assess(uint bountyID, bytes memory claim) internal view returns (bool correct) {
    // TODO this is kinda redundant - why not compare byte arrs directly?
    return secrets[bountyID].num == bytesToUint(claim, 0);
  }

  function completed(uint bountyID) public view returns (bool completed_, address payable completer) {
    return (secrets[bountyID].guessed, secrets[bountyID].guesser);
  }

  // public for debugging purposes, will be internal
  function bytesToUint(bytes memory bs, uint start) public pure returns (uint256){
    require(bs.length >= start + 32, "slicing out of range");
    uint x;
    assembly {x := mload(add(bs, add(0x20, start)))}
    return x;
  }

  // public for debugging purposes, will be internal
  // breaks for numbers that are > 32 bytes
  function uintToBytes(uint256 x) public pure returns (bytes memory b) {
    b = new bytes(32);
    assembly { mstore(add(b, 32), x) }
    return b;
  }

  function viewBountyInfo(uint bountyID) public view returns(bytes memory bountyInfo, string memory infoType) {
    return (uintToBytes(secrets[bountyID].num), "uint");
  }

}
