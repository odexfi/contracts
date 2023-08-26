// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title ODEX Orderbook Exchange Market
 * @author dev@odex.fi
 * @notice A decentralized exchange built around a open limit order book
 * 
 *      _/_/_/_  /_/_/_/   /_/_/_/_/ /_/     /_/
 *    /_/   /_/ /_/   /_/ /_/         /_/ /_/
 *   /_/   /_/ /_/   /_/ /_/_/_/       /_/ 
 *  /_/   /_/ /_/   /_/ /_/         /_/ /_/
 *  /_/_/_/  /_/_/_/   /_/_/_/_/ /_/      /_/
 *       Open Decentralized Exchange
 *            https://odex.fi
*/

//import "hardhat/console.sol";

interface IERC20D {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IOdex {
    function buy(uint _marketId, address _baseAsset, address _token, address _maker, address _taker, uint _amount, uint _fee, uint _price) external;
    function sell(uint _marketId, address _baseAsset, address _token, address _maker, address _taker, uint _amount, uint _fee, uint _price) external;
    function odexCount() external view returns (uint);
    function newMarket(address _token, address _baseAsset, uint _minOrder, uint _tickRounding, uint _multiplier, address _marketAddress, address _deployer) external;
}

contract OdexMarket {
    uint public marketId;
    address public odex;
    address public deployer;
    address public token;
    address public baseAsset;
    uint public multiplier;
    uint public minOrder;
    uint public tickRounding;

    struct Order {
        address trader;
        uint amount;
        uint price;
    }

    Order[100] public bids;
    Order[100] public asks;

    event Bid(uint amount, uint price, address trader, uint index);
    event Ask(uint amount, uint price, address trader, uint index);
    event CancelBid(uint amount, uint price, address trader, uint index);
    event CancelAsk(uint amount, uint price, address trader, uint index);
    event Sell(uint amount, uint price, address trader, address filler, uint index);
    event Buy(uint amount, uint price, address trader, address filler, uint index);

    /**
     * @notice runs once when first deploy to set market parameters
     * @param _marketId array index in Odex
     * @param _odex address of the Odex.sol contract
     * @param _deployer address of the pool deployer that called OdexFactory.deploy()
     * @param _token ERC20 token address to be traded
     * @param _baseAsset ERC20 baseAsset to be traded, usually WETH or Stablecoin
     * @param _minOrder minimum order value of baseAsset for an order to be accepted
     * @param _tickRounding reduces tick size 1e5, on a six decimal stable coin = $0.1 ticks
     * @param _multiplier used for calculating token <> baseAsset conversions = 10 ** tokenDecimals;
     * @dev tokenDecimals used to calculate tokensToBaseAsset and baseAssetToTokens
     */
    constructor(uint _marketId, address _odex, address _deployer, address _token, address _baseAsset, uint _minOrder, uint _tickRounding, uint _multiplier) {
        marketId = _marketId;
        odex = _odex;
        deployer = _deployer;
        token = _token;
        baseAsset = _baseAsset;
        minOrder = _minOrder;
        tickRounding = _tickRounding;
        multiplier = _multiplier;
    }

    /**
     * @notice Converts token value to the base asset value
     * @param _amount The number of tokens
     * @param _price The price of each token
     * @return The equivalent value of the tokens in the base asset
     * @dev Price is lowest denomination of baseAsset per whole token 2000e6 for weth/usdc
     * tokensToBaseAsset 2e18 AmountIn * 2000e6 price / 1e18 tokenDecimals = 4000e6 baseAsset Out
     * baseAssetToTokens = 4000e6 AmountIn * 1e18 tokenDecimals / 2000e6 price = 2e18 tokens out
     * 5000000 * 1e18 / 2001000000
     */
    function tokensToBaseAsset(uint _amount, uint _price) public view returns (uint) {
        return _amount * _price / multiplier;
    }

    /**
     * @notice Converts base asset value to the token value
     * @param _amount The amount of base asset
     * @param _price The price of each token
     * @return The equivalent value of base asset in tokens
     */
    function baseAssetToTokens(uint _amount, uint _price) public view returns (uint) {
        return _amount * multiplier / _price;
    }

    /**
     * @notice Finds the lowest bid in the order book
     * @return The lowest bid amount, price, trader address, and order index in the order book
     * @dev ignores empty entries, use worseBid to find next slot
     */
    function lowestBid() public view returns (uint, uint, address, uint) {
        uint index;
        for (uint i = 0; i < bids.length; i++) {
            if (bids[i].price != 0 && (bids[i].price < bids[index].price || 
                bids[i].price == bids[index].price && bids[i].amount < bids[index].amount)) index = i;
        }
        return (bids[index].amount, bids[index].price, bids[index].trader, index);
    }

    /**
     * @notice Finds the highest bid in the order book
     * @return The highest bid amount, price, trader address, and order index in the order book
     */
    function highestBid() public view returns (uint, uint, address, uint) {
        uint index;
        for (uint i = 0; i < bids.length; i++)
            if (bids[i].price != 0 && (bids[i].price > bids[index].price || 
                bids[i].price == bids[index].price && bids[i].amount > bids[index].amount)) index = i;
        return (bids[index].amount, bids[index].price, bids[index].trader, index);
    }

    /**
     * @notice Finds the lowest ask in the order book
     * @return The lowest ask amount, price, trader address, and order index in the order book
     */
    function lowestAsk() public view returns (uint, uint, address, uint) {
        uint index;
        for (uint i = 0; i < asks.length; i++)
            if (asks[i].price != 0 && (asks[i].price < asks[index].price || 
                asks[i].price == asks[index].price && asks[i].amount > asks[index].amount)) index = i;
        return (asks[index].amount, asks[index].price, asks[index].trader, index);
    }

    /**
     * @notice Finds the highest ask in the order book
     * @return The highest ask amount, price, trader address, and order index in the order book
     */
    function highestAsk() public view returns (uint, uint, address, uint) {
        uint index;
        for (uint i = 0; i < asks.length; i++) {
            if (asks[i].price != 0 && (asks[i].price > asks[index].price || 
                asks[i].price == asks[index].price && asks[i].amount < asks[index].amount)) index = i;
        }
        return (asks[index].amount, asks[index].price, asks[index].trader, index);
    }

    /**
     * @notice Finds the lowest bid in the order book including any empty slots
     * @return The amount, price, trader address, and order index of the worst bid in the order book
     */
    function worseBid() public view returns (uint, uint, address, uint) {
        uint index;
        for (uint i = 0; i < bids.length; i++) {
            if (bids[i].amount == 0) return (0,0,address(0x0), i);
            if (bids[i].price != 0 && (bids[i].price < bids[index].price || 
                bids[i].price == bids[index].price && bids[i].amount < bids[index].amount)) index = i;
        }
        return (bids[index].amount, bids[index].price, bids[index].trader, index);
    }

    /**
     * @notice Finds the worst ask in the order book including any empty slots
     * @return The amount, price, trader address, and order index of the worst ask in the order book
     */
    function worseAsk() public view returns (uint, uint, address, uint) {
        uint index;
        for (uint i = 0; i < asks.length; i++) {
            if (asks[i].amount == 0) return (0,0,address(0x0), i);
            if (asks[i].price != 0 && (asks[i].price > asks[index].price || 
                asks[i].price == asks[index].price && asks[i].amount < asks[index].amount)) index = i;
        }
        return (asks[index].amount, asks[index].price, asks[index].trader, index);
    }

    /**
     * @notice Calculates the mid price of the order book as average of the highest bid and lowest ask
     * @return The calculated mid price
     */
    function midPrice() public view returns (uint) {
        (,uint highBid,,) = highestBid();
        (,uint lowAsk,,) = lowestAsk();
        return (highBid + lowAsk) / 2;
    }

    /**
     * @notice Calculates the bid liquidity and the lowest and highest bid prices
     * @return The total bid liquidity, the lowest and the highest bid prices
     */
    function bidLiquidity() public view returns (uint, uint, uint) {
        uint liquidity;
        uint lowestPrice;
        uint highestPrice;
        for (uint i = 0; i < bids.length; i++) {
           if (bids[i].price < lowestPrice && bids[i].price != 0) lowestPrice = bids[i].price;
           if (bids[i].price > highestPrice && bids[i].price != 0) highestPrice = bids[i].price;
           liquidity += bids[i].amount;
        }
        return (liquidity, lowestPrice, highestPrice);
    }

    /**
     * @notice Calculates the ask liquidity and the lowest and highest ask prices
     * @return The total ask liquidity, the lowest and the highest ask prices
     */
    function askLiquidity() public view returns (uint, uint, uint) {
        uint liquidity;
        uint lowestPrice;
        uint highestPrice;
        for (uint i = 0; i < asks.length; i++) {
           if (asks[i].price < lowestPrice && asks[i].price != 0) lowestPrice = asks[i].price;
           if (asks[i].price > highestPrice && asks[i].price != 0) highestPrice = asks[i].price;
           liquidity += asks[i].amount;
        }
        return (liquidity, lowestPrice, highestPrice);
    }

    /**
     * @notice Calculates the total value locked (TVL) in the contract
     * @return The calculated TVL
     */
    function tvl() external view returns (uint) {
        (uint askLiquidityAmount, uint price,) = askLiquidity();
        (uint bidLiquidityAmount,,) = bidLiquidity();
        uint askBaseAssets = tokensToBaseAsset(askLiquidityAmount, price);
        return (bidLiquidityAmount + askBaseAssets);
    }

    /**
     * @notice Returns the full order book
     * @dev tested this without structs and could potentially decrease computation time 10% by removing for loop
     * @return bidsAmount The arrays of bid amounts
     * @return bidsPrice The arrays of bid prices
     * @return bidsTrader The arrays of bid traders
     * @return asksAmount The arrays of ask amounts
     * @return asksPrice The arrays of ask prices
     * @return asksTrader The arrays of ask traders
     */
    function orderbook() public view returns (
        uint[100] memory,
        uint[100] memory,
        address[100] memory,
        uint[100] memory,
        uint[100] memory,
        address[100] memory
    ) {
        uint[100] memory bidsAmount;
        uint[100] memory bidsPrice;
        address[100] memory bidsTrader;
        uint[100] memory asksAmount;
        uint[100] memory asksPrice;
        address[100] memory asksTrader;
        for (uint i = 0; i < 100; i++) {
            bidsAmount[i] = bids[i].amount;
            bidsPrice[i] = bids[i].price;
            bidsTrader[i] = bids[i].trader;
            asksAmount[i] = asks[i].amount;
            asksPrice[i] = asks[i].price;
            asksTrader[i] = asks[i].trader;
        }
        return (bidsAmount, bidsPrice, bidsTrader, asksAmount, asksPrice, asksTrader);
    }

    /**
     * @notice place a bid limit order into the order book
     * @param _amount bid amount of base asset
     * @param _price price including multiplier
     */
    function placeBid(uint _amount, uint _price) internal {
        (uint lowAmount, uint lowPrice,,uint index) = worseBid();
        require (_amount > minOrder, "below min order");
        require (_price > lowPrice || 
            (_price == lowPrice && _amount > lowAmount), "not competitive");
        IERC20D(baseAsset).transferFrom(msg.sender, address(this), _amount);
        if (bids[index].amount > 0)
            IERC20D(baseAsset).transfer(bids[index].trader, bids[index].amount);
        bids[index] = Order(msg.sender, _amount, _price);
        emit Bid(_amount, _price, msg.sender, index);
    }

    /**
     * @notice place a ask limit order into the order book
     * @param _amount ask amount of token
     * @param _price price including multiplier
     */
    function placeAsk(uint _amount, uint _price) internal {
        uint baseAssetMinOrder = tokensToBaseAsset(minOrder, _price);
        require (_amount > baseAssetMinOrder, "below min order");
        (uint highAmount, uint highPrice,, uint index) = worseAsk();
        require (highPrice == 0 || _price < highPrice || 
            (_price == highPrice && _amount > highAmount), "not competitive");
        IERC20D(token).transferFrom(msg.sender, address(this), _amount);
        if (asks[index].amount > 0)
            IERC20D(token).transfer(asks[index].trader, asks[index].amount);
        asks[index] = Order(msg.sender, _amount, _price);
        emit Ask(_amount, _price, msg.sender, index);
    }

    /**
     * @notice fill a bid up to the amount requested
     * @param _i index of the order in bids array
     * @param _amount is base asset amount
     * @return fillAmount the amount filled in base assets
     */
    function fillBid(uint _i, uint _amount) internal returns (uint) {
        require (bids[_i].amount > 0, "missing bid");
        uint price = bids[_i].price;
        address trader = bids[_i].trader;
        uint leftOvers;
        uint fillAmount = _amount;
        if (_amount > bids[_i].amount) fillAmount = bids[_i].amount; 
        bids[_i].amount -= fillAmount;
        if (bids[_i].amount < minOrder) {
            leftOvers = bids[_i].amount;
            delete bids[_i];
        }
        uint tokenAmount = baseAssetToTokens(fillAmount, price);
        require(tokenAmount > 0, "zero tokenAmount amount");
        IERC20D(token).transferFrom(msg.sender, trader, tokenAmount);
        if (leftOvers > 0) IERC20D(baseAsset).transfer(trader, leftOvers);
        uint fee = fillAmount * 10 / 10000;
        IERC20D(baseAsset).transfer(odex, fee);
        IERC20D(baseAsset).transfer(msg.sender, fillAmount - fee);
        emit Sell(fillAmount, price, trader, msg.sender, _i);
        IOdex(odex).sell(marketId, baseAsset, token, trader, msg.sender, fillAmount, fee, price);
        return fillAmount;
    }

    /**
     * @notice fill a ask up to the amount requested
     * @param _i index of the order in asks array
     * @param _amount is token amount
     * @return fillAmount is the filled amount in tokens
     */
    function fillAsk(uint _i, uint _amount) internal returns (uint) {
        require (asks[_i].amount > 0, "missing ask");
        uint price = asks[_i].price;
        address trader = asks[_i].trader;
        uint leftOvers;
        uint fillAmount = _amount;
        if (_amount > asks[_i].amount) fillAmount = asks[_i].amount; 
        asks[_i].amount -= fillAmount;
        uint remaining = tokensToBaseAsset(asks[_i].amount, price);
        if (remaining < minOrder) {
            leftOvers = asks[_i].amount;
            delete asks[_i];
        }
        uint baseAssetAmount = tokensToBaseAsset(fillAmount, price);
        require(baseAssetAmount > 0, "zero baseAssetAmount amount");
        IERC20D(baseAsset).transferFrom(msg.sender, trader, baseAssetAmount);
        if (leftOvers > 0) IERC20D(token).transfer(trader, leftOvers);
        uint fee = fillAmount * 10 / 100000;
        IERC20D(token).transfer(odex, fee);
        IERC20D(token).transfer(msg.sender, fillAmount - fee);
        emit Buy(fillAmount, price, trader, msg.sender, _i);
        IOdex(odex).buy(marketId, baseAsset, token, trader, msg.sender, fillAmount, fee, price);
        return fillAmount;
    }

    /**
     * @notice place an order to sell an amount of the token down to a set price
     * @dev this will attempt to fill the order at makers bid prices, if no matches
     * in the order book then a new ask order will be created at _price
     * @param _amount is token amount
     * @param _price price including multiplier
     * @return filled amount in tokens that got filled
     */
    function limitOrderSell(uint _amount, uint _price) public returns (uint) {
        uint rPrice = _price / tickRounding * tickRounding;
        uint filled;
        uint tokenMinOrder = baseAssetToTokens(minOrder, _price); // manipulateable DoS?
        require(_amount > tokenMinOrder, "below min order");
        while (filled < _amount - tokenMinOrder) {
            (uint highBidAmount,uint price,,uint id) = highestBid();
            if (highBidAmount == 0) break;
            if (rPrice > price) break; // want to sell at 10 highest bid is 9
            uint baseAssetWanted = tokensToBaseAsset(_amount - filled, price);
            if (baseAssetWanted == 0) break;
            uint lowerAmount = (baseAssetWanted < highBidAmount ? baseAssetWanted : highBidAmount);
            uint executed = fillBid(id, lowerAmount);
            uint tokenAmount = baseAssetToTokens(executed, price);
            filled += tokenAmount;
        }
        uint remaining = _amount - filled;
        if (remaining > tokenMinOrder)
            placeAsk(remaining, rPrice);
        return filled;
    }

    /**
     * @notice place an order to buy an amount of the token up to a set price
     * @dev this will attempt to fill the order at makers ask prices, if no matches
     * in the order book then a new bid order will be created at _price
     * @param _amount is base asset amount
     * @param _price price including multiplier
     * @return filled amount in base asset that got filled
     */
    function limitOrderBuy(uint _amount, uint _price) public returns (uint) {
        uint rPrice = _price / tickRounding * tickRounding;
        uint filled;
        require(_amount > minOrder, "below min order");
        while (filled < _amount - minOrder) {
            (uint lowAskAmount,uint price,,uint id) = lowestAsk();
            if (lowAskAmount == 0) break;
            if (rPrice < price) break;
            uint tokensWanted = baseAssetToTokens(_amount - filled, price);
            if (tokensWanted == 0) break;
            uint lowerAmount = (tokensWanted < lowAskAmount ? tokensWanted : lowAskAmount);
            uint executed = fillAsk(id, lowerAmount);
            uint baseAssetAmount = tokensToBaseAsset(executed, price);
            filled += baseAssetAmount;
        }
        uint remaining = _amount - filled;
        if (remaining > minOrder)
            placeBid(remaining, rPrice);
        return filled;
    }

   /**
     * @notice cancels a single bid order
     * @param _i index of the order in asks array
     */
    function cancelBid(uint _i) public {
        require(bids[_i].trader == msg.sender, "not your bid");
        IERC20D(baseAsset).transfer(bids[_i].trader, bids[_i].amount);
        emit CancelBid(bids[_i].amount, bids[_i].price, bids[_i].trader, _i);
        delete bids[_i];
    }

    /**
     * @notice cancels a single ask order
     * @param _i index of the order in asks array
     */
    function cancelAsk(uint _i) public {
        require(asks[_i].trader == msg.sender, "not your ask");
        IERC20D(token).transfer(asks[_i].trader, asks[_i].amount);
        emit CancelAsk(asks[_i].amount, asks[_i].price, asks[_i].trader, _i);
        delete asks[_i];
    }

    /**
     * @notice panic and cancel all users orders
     */
    function cancelAllOrders() external {
        for (uint i = 0; i < bids.length; i++)
            if (bids[i].trader == msg.sender) cancelBid(i);
        for (uint i = 0; i < asks.length; i++)
            if (asks[i].trader == msg.sender) cancelAsk(i);
    }
}