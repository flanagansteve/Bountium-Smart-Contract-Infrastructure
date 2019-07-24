pragma solidity ^0.5.1;

import "./DumbBiz.sol";

contract InventorylessSmartBiz is DumbBiz {

  // In a dropshipping business, there are no stocked products,
  // so we will instead let an owner set arbitrary options
  // for a product as a string, receive arbitrary chosen options
  // as a string, and place the order with those options - making this
  // business only a middlemanning vehicle for a customer to several
  // supply markets

  // a product
  struct Product {
    string name;
    string description;
    string imageURL;
    bool forSale;
    uint price;
    uint ordersReceived;
    // This is a JSON-object string formatted as {
    //    'optionName' : [ 'option 1', 'option 2' etc]
    // }
    string orderOptions;
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
    // The customer's chosen options for stuff like size, and
    // at a minimum, delivery info in the deliveryInfo field
    string orderInfo;
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
    catalogue.push(Product(name, "No description set", defaultImg, false, price, 0, ""));
    emit ProductReleased(msg.sender, catalogue.length - 1);
    return true;
  }

  // Release a product with set fields
  function releaseProduct(
      string memory name,
      string memory description,
      string memory imageURL,
      bool list,
      uint price,
      string memory orderOptions
    ) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue.push(Product(name, description, imageURL, list, price, 0, orderOptions));
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

  // set version options by supplying a JSON object,
  // described in the Product struct
  function addOptions(uint product, string memory options) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue[product].orderOptions = options;
    emit ProductModified(msg.sender, product);
    return true;
  }

  // set all the fields of a product
  function setProduct(
      uint product,
      string memory name,
      string memory description,
      string memory imageURL,
      bool list,
      uint price,
      string memory orderOptions
    ) public returns (bool success) {
    require(contains(ownersRegistered, msg.sender));
    require(owners[msg.sender].canModifyCatalogue);
    catalogue[product] = Product(name, description, imageURL, list, price, 0, orderOptions);
    emit ProductReleased(msg.sender, catalogue.length - 1);
    return true;
  }

  // order the product
  // params: productID - the product to buy
  //         orderInfo - info about the customer that are needed to give
  //                     them the product, as a JSON object. Includes config
  //                     selection (ie picking shirt size) and delivery info
  // Presumes:
  //   - orderInfo is a JSON object string, with no whitespace following the
  //   end bracket }. If this is not true, the bounty will be malformed
  //   - similarly, presumes the instructions for each supply step are properly
  //   formatted JSON object strings too
  function order(uint product, string memory orderInfo) public payable returns (bool orderPlaced, Assessor delivered, uint orderID) {
    // 1. require sufficient payment
    require(msg.value >= catalogue[product].price);
    // 2. require product.forSale
    require(catalogue[product].forSale);
    // 3. add order, place supply orders for each step in product.supplyChain, save orderIDs
    //    To simplify, we give the entire order info to each supply step even if not
    //    each one requires it.
    orders[product].push(Order(false, false, orderInfo, 0, new uint[](0)));
    if (supplyChains[product].length > 0) {
      for (uint i = 0; i < supplyChains[product].length; i++) {
        // a. Submit new supply req to supplyChain[i].oracle()
        (bool received, uint bountyID) = supplyChains[product][i].incentiviser.oracle().submit(
          bytes(craftBountyJSON(supplyChains[product][i].description, orderInfo))
        );
        // b. save this supply request ID to this order
        orders[product][catalogue[product].ordersReceived].supplyChainBountyIDs.push(bountyID);
        // c. Fund incent at supplyChain[i] with fees[i]
        supplyChains[product][i].incentiviser.fund.value(supplyChains[product][i].fee)(bountyID);
      }
    }
    // 4. increment number of orders
    catalogue[product].ordersReceived++;
    // 5. emit
    emit OrderReceived(product, catalogue[product].ordersReceived - 1);
    // 6. return true + last incentiviser in list as delivered + orderIDs
    if (supplyChains[product].length != 0)
      return (
        true,
        supplyChains[product][supplyChains[product].length - 1].incentiviser.oracle(),
        catalogue[product].ordersReceived - 1
      );
    return (
      true,
      // return a dummy assessment oracle to satisfy return stmt
      Assessor(ownersRegistered[0]),
      catalogue[product].ordersReceived - 1
    );
  }

  // Forms a bounty that includes high-level instructions applicable
  // to all orders of a product that tells a supplier what to do with
  // specific order info, and then the order specific info. For example,
  // perhaps it could be:
  //   { "General Instructions": "Print a shirt with logo found at
  //                              imgur.com/abcde.jpg and deliver it
  //                              to the listed address below",
  //     "Order-Specific Instructions" : "48 Sutton Road, Needham, MA" }
  function craftBountyJSON(string memory genInstr, string memory specInstr) public pure returns (string memory result) {
    return concatStrings("{\"General Instructions\":\"",
      concatStrings(genInstr,
        concatStrings("\",\"Order-Specific Instructions\":\"",
          concatStrings(specInstr, "\"}")
        )
      )
    );
  }

  // pay out all completed supply chain steps for an order
  function paySuppliersForOrder(uint product, uint orderID) public {
    // 1. TODO should we permission this?
    // 2. iterate through steps in supply chain, call settle for each one
    for (uint i = 0; i < supplyChains[product].length; i++) {
      (bool success) = supplyChains[product][i].incentiviser.settle(
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
    require(supplyChains[product].length > step);
    for (uint i = 0; i < catalogue[product].ordersReceived; i++) {
      (bool success) = supplyChains[product][step].incentiviser.settle(
        orders[product][i].supplyChainBountyIDs[step]
      );
      // 3. TODO mark this as successful if success
    }
  }

  function checkOrderStatus(uint product, uint orderID) public view returns(uint stepsCompleted) {
    uint out;
    for (uint i = 0; i < supplyChains[product].length; i++) {
      (bool completed, address payable completer) = supplyChains[product][i].incentiviser.oracle().completed(
        orders[product][orderID].supplyChainBountyIDs[i]
      );
      if (completed)
        out++;
    }
    return out;
  }

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
