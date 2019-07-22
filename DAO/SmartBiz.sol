pragma solidity ^0.5.1;

import "./DumbBiz.sol";
import "../markets/AssessedMarket.sol";
import "../markets/assessors/Assessor.sol";

// This implementation presumes:
//   - suppliers are responsible for claiming payment on their own
//   - business owner can hold inventory
//       - further, meaning that delivery info isnt passed to bounties
//       but tracked internally through orders[]
//       - also means that a customer can't query for order status
//       since not every order is being done per single unit
// For a version that does do per-unit and inventory-less business,
// see InventorylessSmartBiz
contract SmartBiz is DumbBiz {

  // a high-level, abstract idea of a product
  struct Product {
    // self-explanatory details
    string name;
    string description;
    string imageURL;
    bool forSale;
    uint price;
    // the configurable aspects of this product
    string[] orderOptions;
  }
  // the products in the catalogue, ordered by productID
  Product[] public catalogue;
  event ProductReleased(address byWhom, uint productID);
  event ProductModified(address byWhom, uint productID);

  // a specifically configured product with
  // all info necessary to manufacture
  struct StockedProduct {
    // the specifically configured fields of this stock
    string[] configs;
    // how many we have for sale right now
    uint inStock;
    // the inventory level below which we should reorder
    uint reorderThreshold;
    // the amount to restock for when a restock is triggered
    uint reorderSize;
    // how many purchases have been made of this product all time
    uint ordersReceived;
  }
  // Actually configured products that customers can order,
  // mapped by parent abstract product
  mapping(uint=>StockedProduct[]) public purchasableCatalogue;
  event StockedProductReleased(address byWhom, uint productID, uint stockedID);
  event StockedProductModified(address byWhom, uint productID, uint stockedID);

  // So, in summary, a front-end will present the catalogue
  // in the first screen as a high-level overview of what you
  // can buy, and the ordering screen will present the available
  // configurations queried from purchasableCatalogue

  // an order
  struct Order {
    string deliveryInstructions;
    bool complete;
    bool suppliersPaid;
    uint stepsCompleted;
    // The specific stocked product this is for
    uint whichVersion;
  }
  // array of orders for each purchasableCatalogue
  mapping(uint=>Order[]) public orders;
  event OrderReceived(uint productID, uint stockedID, uint orderID);

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
    catalogue.push(Product(name, "No description set", defaultImg, false, price, new string[](0)));
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
    for (uint i = 0; i < supplyChains[product].length; i++)
      totalFees += supplyChains[product][i].fee;
    require(totalFees + fee <= catalogue[product].price);
    // 3. add to list of supply chains
    supplyChains[product].push(SupplyStep(instructions, evaluator, fee));
    emit ProductModified(msg.sender, product);
    return true;
  }

  // Add a configurable aspect of the product, like "size"
  function addOption(uint product, string memory option) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue[product].orderOptions.push(option);
    emit ProductModified(msg.sender, product);
    return true;
  }

  // Release a specific version of the product, with configured inventory
  function releasePurchasableProduct(
      uint parentProduct,
      uint reorderSize,
      uint reorderThreshold) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    string[] memory defaultConfigs = new string[](2);
    for (uint i = 0; i < catalogue[parentProduct].orderOptions.length; i++)
      defaultConfigs[i] = "default";
    purchasableCatalogue[parentProduct].push(StockedProduct(defaultConfigs, 0, reorderThreshold, reorderSize, 0));
    emit StockedProductReleased(msg.sender, parentProduct, purchasableCatalogue[parentProduct].length - 1);
    return true;
  }

  // Add specific configs to a purchasable product
  function addConfig(uint parentProduct, uint stockedTarget, uint whichConfig, string memory value) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    purchasableCatalogue[parentProduct][stockedTarget].configs[whichConfig] = value;
    emit StockedProductModified(msg.sender, parentProduct, stockedTarget);
    return true;
  }

  // order the product
  // params: productID, and info about the customer that are needed to give
  // them the product - an email addr or physical addr, for example
  function order(uint product, uint stockedTarget, string memory deliveryInfo) public payable returns (bool orderPlaced, Assessor delivered, uint orderID) {
    // 1. require sufficient payment
    require(msg.value >= catalogue[product].price);
    // 2. require product.forSale
    require(catalogue[product].forSale);
    // 3. add order, and if necessary, place supply orders for
    // a restock each step in product.supplyChain, save orderIDs
    orders[product].push(Order(deliveryInfo, false, false, 0, stockedTarget));
    purchasableCatalogue[product][stockedTarget].inStock--;
    if (purchasableCatalogue[product][stockedTarget].inStock <
        purchasableCatalogue[product][stockedTarget].reorderThreshold)
      restock(product, stockedTarget);
    // 4. increment number of orders
    purchasableCatalogue[product][stockedTarget].ordersReceived++;
    // 5. emit
    emit OrderReceived(product, stockedTarget, purchasableCatalogue[product][stockedTarget].ordersReceived - 1);
    // 6. return true + last incentiviser in list as delivered + orderIDs
    if (supplyChains[product].length != 0)
      return (
        true,
        supplyChains[product][supplyChains[product].length - 1].incentiviser.oracle(),
        purchasableCatalogue[product][stockedTarget].ordersReceived - 1
      );
    return (
      true,
      // return a dummy assessment oracle to satisfy return stmt
      Assessor(ownersRegistered[0]),
      purchasableCatalogue[product][stockedTarget].ordersReceived - 1
    );
  }

  // Presumes: Last step in a product's supply chain arr is the delivery one
  function restock(uint product, uint stockedTarget) internal {
    // TODO add amount field to reorder bounties
    if (supplyChains[product].length > 0) {
      // iterate through supply chain and place a bounty with each instruction
      for (uint i = 0; i < supplyChains[product].length; i++) {
        // TODO add fields of
        //   catalogue[product].orderOptions[0... end] : purchasableCatalogue.configs[0... end]
        // to each supply step bounty info
        // Currently just placing description for bounty and ignoring versioning:
        // a. Submit new supply req to supplyChain[i].oracle()
        (bool received, uint bountyID) = supplyChains[product][i].incentiviser.oracle().submit(
          bytes32ToBytes(stringToBytes(supplyChains[product][i].description))
        );
        // b. Fund incent at supplyChain[i] with fees[i]
        supplyChains[product][i].incentiviser.fund.value(
            supplyChains[product][i].fee
        )(bountyID);
      }
    }
    // Update the inStock, presuming successful completion of supply bounties
    purchasableCatalogue[product][stockedTarget].inStock += purchasableCatalogue[product][stockedTarget].reorderSize;
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
  function concatStrings(string memory _a, string memory _b) internal pure returns (string memory xy) {
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
