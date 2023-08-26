# Odex

A novel decentralized spot exchange using a limit order book

```shell
npm install
npx hardhat node --fork https://eth-goerli.alchemyapi.io/v2/apikey
npx hardhat test --network local
```


## Additional view functions
```
function bidders() external view returns (address[100] memory) {
    address[100] memory traders;
    for (uint i = 0; i < bids.length; i++)
        traders[i] = bids[i].trader;
    return traders;
}

function askers() external view returns (address[100] memory) {
    address[100] memory traders;
    for (uint i = 0; i < asks.length; i++)
        traders[i] = asks[i].trader;
    return traders;
}

function bidPrices() external view returns (uint[100] memory) {
    uint[100] memory prices;
    for (uint i = 0; i < bids.length; i++)
        prices[i] = bids[i].price;
    return prices;
}

function askPrices() external view returns (uint[100] memory) {
    uint[100] memory prices;
    for (uint i = 0; i < asks.length; i++)
        prices[i] = asks[i].price;
    return prices;
}

function bidAmounts() public view returns (uint[100] memory) {
    uint[100] memory amounts;
    for (uint i = 0; i < bids.length; i++)
        amounts[i] = bids[i].amount;
    return amounts;
}

function askAmounts() public view returns (uint[100] memory) {
    uint[100] memory amounts;
    for (uint i = 0; i < asks.length; i++)
        amounts[i] = asks[i].amount;
    return amounts;
}

function aggregateBids() public view returns (uint[6] memory, uint[6] memory) {
    uint[6] memory bidsAmount;
    uint[6] memory bidsPrice;
    
    for (uint i = 0; i < bids.length; i++) {
        if (bids[i].price == 0) continue;
        uint highPriceIndex = 8;
        for (uint i2 = 0; i2 < bidsPrice.length; i2++) {
            if (bidsPrice[i2] == 0) {
                highPriceIndex = i2;
                break;
            } else if (bids[i].price >= bidsPrice[i2] && 
                (highPriceIndex == 8 || bids[i].price >= bidsPrice[highPriceIndex])) {
                highPriceIndex = i2;
            }
        }
        if (highPriceIndex < 8) {
            if (bidsPrice[highPriceIndex] != bids[i].price) {
                bidsPrice[highPriceIndex] = bids[i].price;
                bidsAmount[highPriceIndex] = bids[i].amount;
            } else {
                bidsAmount[highPriceIndex] += bids[i].amount;
            }
        }
    }
    return (bidsAmount, bidsPrice);
}

function aggregateAsks() public view returns (uint[6] memory, uint[6] memory) {
    uint[6] memory asksAmount;
    uint[6] memory asksPrice;
    
    for (uint i = 0; i < asks.length; i++) {
        if (asks[i].price == 0) continue;
        uint lowPriceIndex = 8;
        for (uint i2 = 0; i2 < asksPrice.length; i2++) {
            if (asksPrice[i2] == 0) {
                lowPriceIndex = i2;
                break;
            } else if (asks[i].price <= asksPrice[i2] && 
                (lowPriceIndex == 8 || asks[i].price <= asksPrice[lowPriceIndex])) {
                lowPriceIndex = i2;
            }
        }
        if (lowPriceIndex < 8) {
            if (asksPrice[lowPriceIndex] != asks[i].price) {
                asksPrice[lowPriceIndex] = asks[i].price;
                asksAmount[lowPriceIndex] = asks[i].amount;
            } else {
                asksAmount[lowPriceIndex] += asks[i].amount;
            }
        }
    }
    return (asksAmount, asksPrice);
}

    function viewBids() public view returns (uint[100] memory, uint[100] memory, address[100] memory) {
        uint[100] memory bidsAmount;
        uint[100] memory bidsPrice;
        address[100] memory bidsTrader;
        for (uint i = 0; i < 100; i++) {
            bidsPrice[i] = bids[i].price;
            bidsAmount[i] = bids[i].amount;
            bidsTrader[i] = bids[i].trader;
        }
        return (bidsAmount, bidsPrice, bidsTrader);
    }

    function viewAsks() public view returns (uint[100] memory, uint[100] memory, address[100] memory) {
        uint[100] memory asksAmount;
        uint[100] memory asksPrice;
        address[100] memory asksTrader;
        for (uint i = 0; i < 100; i++) {
            asksPrice[i] = asks[i].price;
            asksAmount[i] = asks[i].amount;
            asksTrader[i] = asks[i].trader;
        }
        return (asksAmount, asksPrice, asksTrader);
    }

```