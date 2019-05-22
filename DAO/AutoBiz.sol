pragma solidity ^0.5.1;

import "../markets/AssessorFramework.sol";
import "../standards/SafeMath.sol";

contract AutoBiz {

  using SafeMath for uint;
  string public biz_name;
  // A struct representing the business's equity holders
  struct StakeHolder {
    // their name (input "" if anonymous)
    string name;
    // stake, in shares
    uint stake;
    // whether this stakeholder can call for a dividend
    bool callsDividend;
    // whether this stakeholder can dilute the equity pool
    bool canDilute;
    // whether this user can bestow priveleges
    bool canBestow;
    // can modify/release a product
    bool canModifyCatalogue;
    // whether this stakeholder is on the board
    // (The authority of the board is left to the user)
    bool board;
  }
  // the owners
  mapping(address=>StakeHolder) public owners;
  // equity currently taken up, in shares
  uint public equityTaken;
  // total share count
  uint public totalShares;
  // addrs recorded
  address payable[] public ownersRegistered;
  event OwnershipModified (address byWhom);

  // a product
  struct Product {
    string name;
    string description;
    string imageURL;
    bool forSale;
    uint price;
    uint ordersReceived;
    uint supplyChainLength;
    AssessmentIncentiviser[] supplyChain;
    uint[] fees;
  }
  // the products in the catalogue, ordered by productID
  Product[] public catalogue;
  event ProductReleased (address byWhom, uint productID);
  event ProductModified (address byWhom, uint productID);
  event OrderReceived(uint productID, uint orderID);

  // an order
  struct Order {
    bool complete;
    bool suppliersPaid;
    string customerData;
    uint stepsCompleted;
    // ids for various supply orders in producing the product of this specific order
    uint[] supplyChainBountyIDs;
  }
  // array of orders for each productID
  mapping(uint=>Order[]) public orders;

  // the array of supply chain steps for each productID
  // an individual step in the supply chain
  struct SupplyStep {
    string description;
    AssessmentIncentiviser incentiviser;
    uint fee;
  }
  mapping(uint=>SupplyStep[]) public supplyChains;

  // default image url
  string defaultImg = "https://www.digitalcitizen.life/sites/default/files/styles/lst_small/public/featured/2016-08/photo_gallery.jpg";

  // The constructor founding this business
  constructor(uint equityToSender, uint _totalShares, string memory _name) public payable {
    require(equityToSender <= _totalShares);
    owners[msg.sender] = StakeHolder("", equityToSender, true, true, true, true, true);
    equityTaken = equityToSender;
    totalShares = _totalShares;
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
    equityTaken+=stake;
    giveShares(stake, recipient);
    emit OwnershipModified(msg.sender);
    return true;
  }

  // gives a new stake, presuming not all shares have been given out
  function giveUnallocatedShares(uint shares, address payable recipient) public returns(bool) {
    require(contains(ownersRegistered, msg.sender));
    // giving unallocated is in effect equivalent to diluting
    require(owners[msg.sender].canDilute);
    if (equityTaken + shares < totalShares) {
      equityTaken+=shares;
      giveShares(shares, recipient);
      emit OwnershipModified(msg.sender);
      return true;
    } else {
      return false;
    }
  }

  // gives the passed address some shares
  // if new owner, gives no permissions by default - these can be bestowed in a
  // subsequent function call
  function giveShares(uint amt, address payable rec) private {
    if (!contains(ownersRegistered, rec)) {
      owners[rec] = StakeHolder("", amt, false, false, false, false, false);
      ownersRegistered.push(rec);
    } else {
      owners[rec].stake += amt;
    }
  }

  // set your name
  function setMyName(string memory name_) public returns (bool) {
    require(contains(ownersRegistered, msg.sender));
    owners[msg.sender].name = name_;
    emit OwnershipModified(msg.sender);
    return true;
  }

  // give a permission out of the list:
  // 1. calling dividend
  // 2. diluting shares
  // 3. can bestow permissions to others
  // 4. can modify the catalogue
  // 5. is a board member
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
    else if (which == 5)
      owners[bestowee].board = true;
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
    require (address(this).balance >= (amt * equityTaken));
    for (uint i = 0; i <ownersRegistered.length; i++)
      ownersRegistered[i].transfer(amt * owners[ownersRegistered[i]].stake);
    return true;
  }

  // Release a product for the business to sell
  function releaseProduct(string memory name, uint price) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue.push(Product(name, "No description set", defaultImg, false, price, 0, 0, new AssessmentIncentiviser[](0), new uint[](0)));
    emit ProductReleased(msg.sender, catalogue.length - 1);
    return true;
  }

  // set the description for a product
  function addDescription(uint product, string memory description_) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue[product].description = description_;
    emit ProductModified(msg.sender, product);
    return true;
  }

  // set the imageURL for a product
  function addImageUrl(uint product, string memory imageURL_) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue[product].imageURL = imageURL_;
    emit ProductModified(msg.sender, product);
    return true;
  }

  // change the price of the product at index product
  function changePrice(uint product, uint newPrice) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue[product].price = newPrice;
    emit ProductModified(msg.sender, product);
    return true;
  }

  // list a product as available for sale
  function listProduct(uint product) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue[product].forSale = true;
    emit ProductModified(msg.sender, product);
    return true;
  }

  // delist a product, do not let people purchase it
  function delistProduct(uint product) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue[product].forSale = false;
    emit ProductModified(msg.sender, product);
    return true;
  }

  // add a step in the supply chain to the product
  // TODO we should ensure the addr passed to this is an incentiviser
  function addSupplyStep(uint product, AssessmentIncentiviser evaluator, uint fee) public returns (bool success) {
    // 1. require auth
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    // 2. require total fees <= price
    uint totalFees = 0;
    for (uint i = 0; i < catalogue[product].fees.length; i++)
      totalFees += catalogue[product].fees[i];
    require(totalFees + fee <= catalogue[product].price);
    // 3. add to product structs supply chain
    catalogue[product].supplyChain.push(evaluator);
    catalogue[product].fees.push(fee);
    catalogue[product].supplyChainLength++;
    // 4. add to list of supply chains
    // TODO take in string description of step
    supplyChains[product].push(SupplyStep("", evaluator, fee));
    emit ProductModified(msg.sender, product);
    return true;
  }

  // order the product
  // params: productID, and info about the customer that are needed to give
  // them the product - an email addr or physical addr, for example
  // Presumes: Last step in a product's supply chain arr is the delivery one
  function order(uint product, string memory customerInfo) public payable returns (bool orderPlaced, AssessmentOracle delivered, uint orderID) {
    // 1. require sufficient payment
    require(msg.value >= catalogue[product].price);
    // 2. require product.forSale
    require(catalogue[product].forSale);
    // 3. add order, place supply orders for each step in product.supplyChain, save orderIDs
    orders[product].push(Order(false, false, customerInfo, 0, new uint[](0)));
    if (catalogue[product].supplyChain.length > 0) {
      for (uint i = 0; i < catalogue[product].supplyChain.length - 1; i++) {
        // a. Submit new supply req to supplyChain[i].oracle()
        (bool received, uint bountyID) = catalogue[product].supplyChain[i].oracle().submit(
          // data submitted to the supply chain (excluding last) is just orderID...
          uintToBytes(catalogue[product].ordersReceived)
        );
        // b. save this supply request ID to this order
        orders[product][catalogue[product].ordersReceived].supplyChainBountyIDs.push(bountyID);
        // c. Fund incent at supplyChain[i] with fees[i]
        catalogue[product].supplyChain[i].fund.value(catalogue[product].fees[i])(bountyID);
      }
      // c. give last step incent the customers info
      (bool receivedDelivery, uint deliveryID) = catalogue[product].supplyChain[
        catalogue[product].supplyChain.length - 1
      ].oracle().submit(bytes32ToBytes(stringToBytes(customerInfo)));
      orders[product][catalogue[product].ordersReceived].supplyChainBountyIDs.push(deliveryID);
      catalogue[product].supplyChain[
        catalogue[product].supplyChain.length - 1
      ].fund.value(catalogue[product].fees[catalogue[product].fees.length - 1])(deliveryID);
    }
    // 4. increment number of orders
    catalogue[product].ordersReceived++;
    // 5. emit
    emit OrderReceived(product, catalogue[product].ordersReceived - 1);
    // 6. return true + last incentiviser in list as delivered + orderIDs
    if (catalogue[product].supplyChain.length != 0)
      return (
        true,
        catalogue[product].supplyChain[catalogue[product].supplyChain.length - 1].oracle(),
        catalogue[product].ordersReceived - 1
      );
    return (
      true,
      // return a dummy assessment oracle to satisfy return stmt
      AssessmentOracle(ownersRegistered[0]),
      catalogue[product].ordersReceived - 1
    );
  }

  // pay out all completed supply chain steps for an order
  function paySuppliersForOrder(uint product, uint orderID) public {
    // 1. TODO should we permission this?
    // 2. iterate through steps in supply chain, call settle for each one
    for (uint i = 0; i < catalogue[product].supplyChain.length; i++) {
      (bool success) = catalogue[product].supplyChain[i].settle(
        orders[product][orderID].supplyChainBountyIDs[i]
      );
      if (success)
        orders[product][orderID].stepsCompleted++;
    }
    if (orders[product][orderID].stepsCompleted == orders[product][orderID].supplyChainBountyIDs.length) {
      orders[product][orderID].complete = true;
      orders[product][orderID].suppliersPaid = true;
    }
  }

  // pay out a supplier all his due payment for his supply step in a products
  // supply chain
  function paySupplier(uint product, uint step) public {
    // 1. TODO should we only pay orders completed by msg.sender?
      // we would do this by, in each iteration of the for loop,
      // calling catalogue.supplyChain[step].oracle().completed(orderID) and
      // seeing if its msg.sender - if so, call settle
      // Pro: People can't force payment to you if you don't want it?
      // Con: Inconvenient if biz owner cannot pay out to a supplier
    // 2. Iterate through orders and pay the supplier in the indicated step
    require(catalogue[product].supplyChain.length > step);
    for (uint i = 0; i < catalogue[product].ordersReceived; i++) {
      (bool success) = catalogue[product].supplyChain[step].settle(
        orders[product][i].supplyChainBountyIDs[step]
      );
      // 3. TODO mark this as successful if success
    }
  }

  function checkOrderStatus(uint product, uint orderID) public view returns(uint stepsCompleted) {
    uint out;
    for (uint i = 0; i < catalogue[product].supplyChain.length; i++) {
      (bool completed, address payable completer) = catalogue[product].supplyChain[i].oracle().completed(
        orders[product][orderID].supplyChainBountyIDs[i]
      );
      if (completed)
        out++;
    }
    return out;
  }

  // send ETH to give the biz capital
  function () external { }

  // public for debugging purposes, will be internal
  function uintToBytes(uint256 x) public pure returns (bytes memory b) {
    b = new bytes(32);
    assembly { mstore(add(b, 32), x) }
    return b;
  }

  // public for debugging purposes, will be internal
  // from: https://ethereum.stackexchange.com/a/9152
  function stringToBytes(string memory source) public pure returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0)
      return 0x0;
    assembly { result := mload(add(source, 32)) }
  }

  // public for debugging, will be internal
  function bytes32ToBytes(bytes32 b32) public pure returns (bytes memory b) {
    b = new bytes(32);
    assembly { mstore(add(b, 32), b32) }
    return b;
  }

}
