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

import "./OdexToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

interface IERC20D {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint);
}

interface IOdexMarket {
    function tvl() external view returns (uint);
}

contract Odex is Ownable {
    struct ODeXs {
        address marketAddress;
        address deployer;
        address token;
        address baseAsset;
        uint marketId;
        uint deployedTimestamp;
        uint minOrder;
        uint tickRounding;
        uint multiplier;
        uint buyVolume;
        uint sellVolume;
        uint baseAssetTotalVolume;
    }

    ODeXs[] public odexs;
    uint public odexCount;
    OdexToken public odexToken;
    address public odexFactory;
    mapping(address => uint) public odexLookup;
    mapping(address => string) public metadata;
    mapping(address => uint) public rewardsAssets;

    event Sell(uint marketId, address baseAsset, address token, address maker, address taker, uint amount, uint fee, uint price);
    event Buy(uint marketId, address baseAsset, address token, address maker, address taker, uint amount, uint fee, uint price);
    event ODEXDeployed(ODeXs odex);

    constructor() {
        odexToken = new OdexToken(msg.sender);
    }

    /**
     * @notice called by OdexFactory.sol each time a new market is deployed
     * @dev only OdexFactory can deploy markets and the address is set on the first deployment
     * @param _token ERC20 token address to be traded
     * @param _baseAsset ERC20 baseAsset to be traded, usually WETH or Stablecoin
     * @param _minOrder minimum order value of baseAsset for an order to be accepted
     * @param _tickRounding reduces tick size 1e5, on a six decimal stable coin = $0.1 ticks
     * @param _multiplier used for calculating token <> baseAsset conversions = 10 ** tokenDecimals;
     * @param _marketAddress contract address of newly deployed Odex market
     */
    function newMarket(address _token, address _baseAsset, uint _minOrder, uint _tickRounding, uint _multiplier, address _marketAddress, address _deployer) external {
        if (odexFactory == address(0x0)) odexFactory = msg.sender;
        require (msg.sender == odexFactory, "only odexFactory");
        uint marketId = odexs.length;
        odexLookup[_marketAddress] = marketId;
        odexs.push(ODeXs(_marketAddress, _deployer, _token, _baseAsset, marketId, uint(block.timestamp), _minOrder, _tickRounding, _multiplier, 0, 0, 0));
        odexCount = odexs.length;
        emit ODEXDeployed(odexs[marketId]);
    }

    /**
     * @notice reports total TVL across all markets
     * @return totalTVL TVL in baseAsset, assumes all baseAssets the same value
     * @dev will break as soon as baseAssets other than USD are added
     */
    function tvl() external view returns(uint totalTVL) {
        for (uint i = 0; i < odexs.length; i++)
            totalTVL += IOdexMarket(odexs[i].marketAddress).tvl();
    }

    /**
     * @notice reports total volume across all markets
     * @return totalVolume in baseAsset, assumes all baseAssets the same value
     * @dev will break as soon as baseAssets other than USD are added
     */
    function volume() external view returns(uint totalVolume) {
        for (uint i = 0; i < odexs.length; i++)
            totalVolume += odexs[i].baseAssetTotalVolume;
    }

    /**
     * @notice allows contract owner to claim tokens sent to the contract address
     * @param _tokens an array of ERC20 token addresses that are to be claimed
     */
    function claimTokens(address[] calldata _tokens) external onlyOwner {
        for (uint i = 0; i < _tokens.length; i++) {
            uint bal = IERC20D(_tokens[i]).balanceOf(address(this));
            IERC20D(_tokens[i]).transfer(msg.sender, bal);
        }
    }

    /**
     * @notice allows contract owner to set the rewards per asset
     * @param _token the address of the asset
     * @param _rewards the amount of rewards per asset
     */
    function rewardsAsset(address _token, uint _rewards) external onlyOwner {
        rewardsAssets[_token] = _rewards;
    }

    /**
     * @notice allows each address to update their own metadata
     * @param _update the new metadata string
     */
    function update(string calldata _update) external {
        metadata[msg.sender] = _update;
    }

    /**
     * @notice calculates and dispenses incentive rewards 
     * @param _asset the address of the traded asset
     * @param _fee the transaction fee
     * @param _maker the address of the maker
     * @param _taker the address of the taker
     */
    function incentive(address _asset, uint _fee, address _maker, address _taker) internal {
        if (rewardsAssets[_asset] > 0) {
            uint amount = _fee * rewardsAssets[_asset] / 1e18;
            uint bal = odexToken.balanceOf(address(this));
            if (bal > amount * 2) {
                odexToken.transfer(_maker, amount);
                odexToken.transfer(_taker, amount);
            }
        }
    }

    /**
     * @notice registers a buy order from OdexMarket.sol and settles incentives
     * @param _marketId the array index of the market in odexs
     * @param _baseAsset the address of the base asset
     * @param _token the address of the traded token
     * @param _maker the address of the maker trader
     * @param _taker the address of the taker trader
     * @param _amount the amount traded in tokens
     * @param _fee the transaction fee
     * @param _price the trading price
     */
    function buy(uint _marketId, address _baseAsset, address _token, address _maker, address _taker, uint _amount, uint _fee, uint _price) external {
        console.log(msg.sender, odexs[_marketId].marketAddress);
        require(msg.sender == odexs[_marketId].marketAddress, "not odex");
        odexs[_marketId].buyVolume += _amount;
        uint baseAssetAmount = _amount * _price / odexs[_marketId].multiplier;
        odexs[_marketId].baseAssetTotalVolume += baseAssetAmount;
        incentive(_token, _fee, _maker, _taker);
        emit Buy(_marketId, _baseAsset, _token, _maker, _taker, _amount, _fee, _price);
    }

    /**
     * @notice registers a sell order from OdexMarket.sol and settles incentives
     * @param _marketId the array index of the market in odexs
     * @param _baseAsset the address of the base asset
     * @param _token the address of the traded token
     * @param _maker the address of the maker trader
     * @param _taker the address of the taker trader
     * @param _amount the amount traded in baseAssets
     * @param _fee the transaction fee
     * @param _price the trading price
     */
    function sell(uint _marketId, address _baseAsset, address _token, address _maker, address _taker, uint _amount, uint _fee, uint _price) external {
        console.log(msg.sender, odexs[_marketId].marketAddress);
        require(msg.sender == odexs[_marketId].marketAddress, "not odex");
        odexs[_marketId].sellVolume += _amount;
        odexs[_marketId].baseAssetTotalVolume += _amount;
        incentive(_baseAsset, _fee, _maker, _taker);
        emit Sell(_marketId, _baseAsset, _token, _maker, _taker, _amount, _fee, _price);
    }
}