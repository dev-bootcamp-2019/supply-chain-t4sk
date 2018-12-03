pragma solidity ^0.4.13;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SupplyChain.sol";

contract TestSupplyChain {
    // Let Truffle fund this contract
    uint public initialBalance = 1 ether;

    SupplyChain supplyChain;
    Account buyer;
    Account seller;

    function () public payable {}

    function beforeEach() public {
        supplyChain = new SupplyChain();
        buyer = new Account(address(supplyChain));
        seller = new Account(address(supplyChain));

        address(buyer).transfer(0.01 ether);
        address(seller).transfer(0.01 ether);

        seller.addItem("test", 1);
    }

    // Test for failing conditions in this contracts
    // test that every modifier is working

    // buyItem

    // test for failure if user does not send enough funds
    function testBuyItemInsufficientFunds() public {
        (,,uint price,,,) = supplyChain.fetchItem(0);
        bool result = buyer.testBuyItem(0, price - 1);

        Assert.isFalse(result, "Insufficient funds should throw");
    }

    // test for purchasing an item that is not for Sale
    function testBuyItemNotForSale() public {
        buyer.buyItem(0);

        (,,uint price, uint state,,) = supplyChain.fetchItem(0);
        Assert.equal(state, 1, "State should be Sold");

        bool result = buyer.testBuyItem(0, price);

        Assert.isFalse(result, "buyItem should throw");
    }

    // shipItem

    // test for calls that are made by not the seller
    function testShipItemNotSeller() public {
        buyer.buyItem(0);
        Account nonSeller = new Account(address(supplyChain));

        (,,, uint state, address _seller,) = supplyChain.fetchItem(0);
        Assert.equal(state, 1, "State should be Sold");
        Assert.isTrue(
            _seller != address(nonSeller),
            "Non seller should be different from seller"
        );

        bool result = nonSeller.testShipItem(0);

        Assert.isFalse(result, "shipItem should throw if called by non seller");
    }

    // test for trying to ship an item that is not marked Sold
    function testShipItemNotSold() public {
        (,,, uint state, address _seller,) = supplyChain.fetchItem(0);
        Assert.isTrue(state != 1, "State should not be Sold");
        Assert.isTrue(_seller == address(seller), "Not seller");

        bool result = seller.testShipItem(0);

        Assert.isFalse(result, "shipItem should throw if state != Sold");
    }

    // receiveItem

    // test calling the function from an address that is not the buyer
    function testReceiveItemNotBuyer() public {
        buyer.buyItem(0);
        seller.shipItem(0);

        Account nonBuyer = new Account(address(supplyChain));

        (,,, uint state,, address _buyer) = supplyChain.fetchItem(0);
        Assert.isTrue(state == 2, "State should be Shipped");
        Assert.isTrue(
            _buyer != address(nonBuyer),
            "Non buyer should be different from buyer"
        );

        bool result = nonBuyer.testReceiveItem(0);

        Assert.isFalse(
            result,
            "receiveItem should throw if called by non buyer"
        );
    }

    // test calling the function on an item not marked Shipped
    function testReceiveItemNotShipped() public {
        buyer.buyItem(0);

        (,,, uint state,, address _buyer) = supplyChain.fetchItem(0);
        Assert.isTrue(state != 2, "State should not be Shipped");
        Assert.isTrue(_buyer == address(buyer), "Not buyer");

        bool result = buyer.testReceiveItem(0);

        Assert.isFalse(result, "receiveItem should throw if state != Shipped");
    }
}

contract Account {
    SupplyChain supplyChain;

    constructor(address _supplyChain) public {
        supplyChain = SupplyChain(_supplyChain);
    }

    function () payable public {}

    function addItem(string _name, uint _price) public {
        supplyChain.addItem(_name, _price);
    }

    function buyItem(uint sku) public {
        (,,uint price,,,) = supplyChain.fetchItem(0);
        supplyChain.buyItem.value(price)(sku);
    }

    function testBuyItem(uint sku, uint value) public returns (bool) {
        return address(supplyChain).call.value(value)(
            abi.encodeWithSignature(
                "buyItem(uint256)", sku
            )
        );
    }

    function shipItem(uint sku) public {
        supplyChain.shipItem(sku);
    }

    function testShipItem(uint sku) public returns (bool) {
        return address(supplyChain).call(
            abi.encodeWithSignature(
                "shipItem(uint256)", sku
            )
        );
    }

    function testReceiveItem(uint sku) public returns (bool) {
        return address(supplyChain).call(
            abi.encodeWithSignature(
                "receiveItem(uint256)", sku
            )
        );
    }
}
