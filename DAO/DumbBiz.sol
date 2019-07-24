pragma solidity ^0.5.1;

import "../util/SafeMath.sol";

// TODO add a method for publishing a bounty on the DAO's behalf
// TODO update dividend to be hack safe
contract DumbBiz {

  using SafeMath for uint;
  string public biz_name;
  // A struct representing the business's equity holders
  struct StakeHolder {
    // stake, in shares
    uint stake;
    // whether this stakeholder can call for a dividend
    bool callsDividend;
    // whether this stakeholder can dilute the equity pool
    bool canDilute;
    // whether this user can bestow privileges
    bool canBestow;
    // can modify/release a product
    bool canModifyCatalogue;
  }
  uint public totalShares;
  // the owners
  mapping(address=>StakeHolder) public owners;
  // addrs recorded
  address payable[] public ownersRegistered;
  event OwnershipModified (address byWhom);

  // The constructor founding this business
  constructor(string memory _name) public payable {
    owners[msg.sender] = StakeHolder(1, true, true, true, true);
    totalShares = 1;
    biz_name = _name;
    ownersRegistered.push(msg.sender);
  }

  // Transfers msg.sender's shares.
  function transferShares(uint sharesToTransfer, address payable recipient) public returns (bool) {
    require (contains(ownersRegistered, msg.sender));
    require (owners[msg.sender].stake >= sharesToTransfer);
    owners[msg.sender].stake -= sharesToTransfer;
    giveShares(sharesToTransfer, recipient);
    emit OwnershipModified(msg.sender);
    return true;
  }

  // Dilutes the equity pool by adding this new recipient
  function dilute(uint stake, address payable recipient) public returns (bool) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canDilute);
    totalShares+=stake;
    giveShares(stake, recipient);
    emit OwnershipModified(msg.sender);
    return true;
  }

  // gives the passed address some shares
  // if new owner, gives no permissions by default - these can be bestowed in a
  // subsequent function call
  function giveShares(uint amt, address payable rec) private {
    if (!contains(ownersRegistered, rec)) {
      owners[rec] = StakeHolder(amt, false, false, false, false);
      ownersRegistered.push(rec);
    } else {
      owners[rec].stake += amt;
    }
  }

  // give a permission out of the list:
  // 1. calling dividend
  // 2. diluting shares
  // 3. can bestow permissions to others
  // 4. can modify the catalogue
  function bestowPermission(address bestowee, uint which) public returns(bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canBestow);
    require(contains(ownersRegistered, bestowee));
    if (which == 1)
      owners[bestowee].callsDividend = true;
    else if (which == 2)
      owners[bestowee].canDilute = true;
    else if (which == 3)
      owners[bestowee].canBestow = true;
    else if (which == 4)
      owners[bestowee].canModifyCatalogue = true;
    else
      // must be a mistake or something
      return false;
    emit OwnershipModified(msg.sender);
    return true;
  }

  // tells whether an array contains the passed address. wish this was builtin
  function contains(address payable[] memory arr, address x) private pure returns(bool) {
    for (uint i = 0; i < arr.length; i++)
      if (arr[i] == x)
        return true;
    return false;
  }

  // tells whether this address is an owner
  function isOwner(address addr) public view returns (bool) {
    return contains(ownersRegistered, addr);
  }

  // Pays out a dividend to owners, in wei, in terms of wei-per-share
  // (out of TOTAL shares, not just shares already claimed)
  // Presumes:
  //   dividend >= 1 wei per share
  //   caller can calculate dividend per share this way (i can make a calc
  //   for this down the road)
  function payDividend(uint amt) public returns (bool) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].callsDividend);
    require (address(this).balance >= (amt * totalShares));
    for (uint i = 0; i <ownersRegistered.length; i++)
      ownersRegistered[i].transfer(amt * owners[ownersRegistered[i]].stake);
    return true;
  }

  // send ETH to give the biz capital
  function () external { }

}
