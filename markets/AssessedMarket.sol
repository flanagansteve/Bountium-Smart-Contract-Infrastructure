pragma solidity ^0.5.1;

// The following is a contract for establishing a marketplace that employs
// an Assessor as detailed in Assessor.sol
contract AssessedMarket {

  // the assessor the incentiviser escrows payment based on
  Assessor public oracle;
  // a mapping from bountyIDs to rewards, in wei
  mapping(uint=>uint) public bounties;

  // TODO check that this is really an ao
  constructor(Assessor _oracle) public payable {
    oracle = _oracle;
  }

  function settle(uint bountyID) public returns (bool success) {
    (bool completed, address payable completer) = oracle.completed(bountyID);
    if(!completed)
      return false;
    completer.transfer(bounties[bountyID]);
    bounties[bountyID] = 0;
    return true;
  }

  // For funding completion of the task
  function fund(uint bountyID) public payable {
    bounties[bountyID] += msg.value;
  }

  // revert random eth
  function () external payable {
    revert();
  }

}
