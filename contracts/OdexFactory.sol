// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title ODEX Factory
 * @author dev@odex.fi
 * @notice Factory deployer for ODEX markets, collector of fees & distributor of incentives
 * 
 *      _/_/_/_  /_/_/_/   /_/_/_/_/ /_/     /_/
 *    /_/   /_/ /_/   /_/ /_/         /_/ /_/
 *   /_/   /_/ /_/   /_/ /_/_/_/       /_/ 
 *  /_/   /_/ /_/   /_/ /_/         /_/ /_/
 *  /_/_/_/  /_/_/_/   /_/_/_/_/ /_/      /_/
 *       Open Decentralized Exchange
 *            https://odex.fi
*/

import "./OdexMarket.sol";

contract OdexFactory {
    address public odex;
       
    constructor(address _odex) {
        odex = _odex;
    }

    /**
     * @notice deploys a new market and order book for a token/baseAsset pair
     * @dev only OdexFactory can deploy contracts because of the callback to Odex.sol
     * @param _token ERC20 token address to be traded
     * @param _baseAsset ERC20 baseAsset to be traded, usually WETH or Stablecoin
     * @param _minOrder minimum order value of baseAsset for an order to be accepted
     * @param _tickRounding reduces tick size 1e5, on a six decimal stable coin = $0.1 ticks
     * @return odexMarket contract address of newly deployed Odex market
     */
    function deploy(address _token, address _baseAsset, uint _minOrder, uint _tickRounding) public returns (address) {
        uint marketId = IOdex(odex).odexCount();
        uint tokenDecimals = IERC20D(_token).decimals();
        uint multiplier = 10 ** tokenDecimals;
        OdexMarket odexMarket = new OdexMarket(marketId, odex, msg.sender, _token, _baseAsset, _minOrder, _tickRounding, multiplier);
        IOdex(odex).newMarket(_token, _baseAsset, _minOrder, _tickRounding, multiplier, address(odexMarket), msg.sender);
        return address(odexMarket);
    }

}