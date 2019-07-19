pragma solidity ^0.5.1;

import "./DumbBiz.sol";
import "../markets/AssessedMarket.sol";
import "../markets/assessors/Assessor.sol";

contract SmartBiz is DumbBiz {

  // TODO we currently have a supplyChain field of a product, AND
  // a supplyChains/supplySteps mapping. Surely these two can be consolidated

  // a product
  struct Product {
    string name;
    string description;
    string imageURL;
    bool forSale;
    uint price;
    uint ordersReceived;
    uint supplyChainLength;
    // This is a JSON-object string formatted as {
    //    'optionName' : [ 'option 1', 'option 2' etc]
    // }
    string orderOptions;
    AssessedMarket[] supplyChain;
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
    string deliveryInfo;
    // The customer's chosen options for stuff like size
    string chosenOptions;
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
    AssessedMarket incentiviser;
    uint fee;
  }
  // array of supply chains for each productID
  mapping(uint=>SupplyStep[]) public supplyChains;

  // default image url
  string defaultImg = "https://www.digitalcitizen.life/sites/default/files/styles/lst_small/public/featured/2016-08/photo_gallery.jpg";

  constructor(string memory _name) DumbBiz(_name) public  { }

  // tells whether an array contains the passed address. wish this was builtin
  function contains(address payable[] memory arr, address x) private pure returns(bool) {
    for (uint i = 0; i < arr.length; i++)
      if (arr[i] == x)
        return true;
    return false;
  }

  // Release a product for the business to sell
  function releaseProduct(string memory name, uint price) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue.push(Product(name, "No description set", defaultImg, false, price, 0, 0, "", new AssessedMarket[](0), new uint[](0)));
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
  function addSupplyStep(uint product, AssessedMarket evaluator, uint fee, string memory instructions) public returns (bool success) {
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
    supplyChains[product].push(SupplyStep(instructions, evaluator, fee));
    emit ProductModified(msg.sender, product);
    return true;
  }

  // set version options by supplying a JSON object,
  // described in the Product struct
  function addOptions(uint product, string memory options) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue[product].orderOptions = options;
    emit ProductModified(msg.sender, product);
    return true;
  }

  // order the product
  // params: productID, and info about the customer that are needed to give
  // them the product - an email addr or physical addr, for example
  // Presumes: Last step in a product's supply chain arr is the delivery one
  // TODO presumably, the customer options also impact the other supply steps -
  // if you're manufacturing the product as a certain size in step 1, then you
  // need to know the chosen size then. How do we automatically send chosenOptions
  // to the appropriate steps? Sending to them all for now
  function order(uint product, string memory chosenOptions, string memory deliveryInfo) public payable returns (bool orderPlaced, Assessor delivered, uint orderID) {
    // 1. require sufficient payment
    require(msg.value >= catalogue[product].price);
    // 2. require product.forSale
    require(catalogue[product].forSale);
    // 3. add order, place supply orders for each step in product.supplyChain, save orderIDs
    orders[product].push(Order(false, false, deliveryInfo, chosenOptions, 0, new uint[](0)));
    if (catalogue[product].supplyChain.length > 0) {
      for (uint i = 0; i < catalogue[product].supplyChain.length - 1; i++) {
        string memory thisStep = concatStrings(chosenOptions, supplyChains[product][i].description);
        // a. Submit new supply req to supplyChain[i].oracle()
        (bool received, uint bountyID) = catalogue[product].supplyChain[i].oracle().submit(
          bytes32ToBytes(stringToBytes(thisStep))
        );
        // b. save this supply request ID to this order
        orders[product][catalogue[product].ordersReceived].supplyChainBountyIDs.push(bountyID);
        // c. Fund incent at supplyChain[i] with fees[i]
        catalogue[product].supplyChain[i].fund.value(catalogue[product].fees[i])(bountyID);
      }
      // c. give last step incent the delivery info
      (bool receivedDelivery, uint deliveryID) = catalogue[product].supplyChain[
        catalogue[product].supplyChain.length - 1
      ].oracle().submit(bytes32ToBytes(stringToBytes(deliveryInfo)));
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
      Assessor(ownersRegistered[0]),
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

  // public for debugging purposes, will be internal
  function uintToBytes(uint256 x) internal pure returns (bytes memory b) {
    b = new bytes(32);
    assembly { mstore(add(b, 32), x) }
    return b;
  }

  // public for debugging purposes, will be internal
  // from: https://ethereum.stackexchange.com/a/9152
  function stringToBytes(string memory source) internal pure returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0)
      return 0x0;
    assembly { result := mload(add(source, 32)) }
  }

  // public for debugging, will be internal
  function bytes32ToBytes(bytes32 b32) internal pure returns (bytes memory b) {
    b = new bytes(32);
    assembly { mstore(add(b, 32), b32) }
    return b;
  }

  // public for debugging, will be internal
  function concatStrings(string memory _a, string memory _b) public pure returns (string memory xy) {
    bytes memory _ba = bytes(_a);
    bytes memory _bb = bytes(_b);
    string memory abcde = new string(_ba.length + _bb.length);
    bytes memory babcde = bytes(abcde);
    uint k = 0;
    for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
    for (uint i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
    return string(babcde);
  }

}
