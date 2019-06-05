pragma solidity ^0.5.1;

import "../markets/assessors/AssessorFramework.sol";

// TODO add search by name, purpose, and evaluator
// a registrar of bounty markets. this will make it easier for
// autobiz owners to find an appropriate and active incentiviser,
// and make bounty discovery easy for suppliers. can fetch one via
// markets(id), or via searching by keyword
contract Registrar {

  struct RegisteredMarket {
    AssessmentIncentiviser market;
    address submitter;
    string name;
    string purpose;
    string evaluationDescription;
    string[] keywords;
    // ik this is redundant, but its useful for getMarketByKeyword
    uint id;
  }
  RegisteredMarket[] public markets;
  uint public marketsRegistered;

  // TODO how to prevent repeats? should we?
  // TODO should we ensure that a particular person gets to submit the market?
  // or can anyone? that person will then have total control of assigning keywords
  // to it
  // TODO we should check that the address supplied really is an AssessIncent
  // TODO do we allow any and all names? repeat names?
  function registerMarket(AssessmentIncentiviser market_, string memory purpose_, string memory name_, string memory ed_) public returns (bool success, uint marketID) {
    markets.push(RegisteredMarket(market_, msg.sender, name_, purpose_, ed_, new string[](0), marketsRegistered));
    marketsRegistered++;
    return (true, marketsRegistered - 1);
  }

  // TODO how to prevent spam? should we limit keywords?
  // TODO should we let people look up address or name?
  // TODO who gets to add keywords? anyone? only submitter?
  function addKeyword(uint whichMarket, string memory newKeyword) public returns (bool success) {
    require(msg.sender == markets[whichMarket].submitter);
    markets[whichMarket].keywords.push(newKeyword);
    return true;
  }

  function getMarketByKeyword(string memory keyword) public view returns (address[] memory markets_) {
    bool[] memory haskw = new bool[](marketsRegistered);
    uint found = 0;
    for (uint i = 0; i < marketsRegistered; i++) {
      haskw[i] = contains(markets[i].keywords, keyword);
      found++;
    }
    address[] memory output_arr = new address[](found);
    for (uint k = 0; k < output_arr.length; k++)
      if(haskw[k])
        output_arr[k] = address(markets[k].market);
    return output_arr;
  }

   // tells whether an array contains the passed str. wish this was builtin
  function contains(string[] memory arr, string memory x) private pure returns(bool) {
    for (uint i = 0; i < arr.length; i++)
      if (keccak256(bytes(arr[i])) == keccak256(bytes(x)))
        return true;
    return false;
  }
}
