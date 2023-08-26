// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title ODEX Tooken Contract
 * @author dev@odex.fi
 * @notice An ERC20 token contract with staggered token sale and mint allocations
 * 
 *      _/_/_/_  /_/_/_/   /_/_/_/_/ /_/     /_/
 *    /_/   /_/ /_/   /_/ /_/         /_/ /_/
 *   /_/   /_/ /_/   /_/ /_/_/_/       /_/ 
 *  /_/   /_/ /_/   /_/ /_/         /_/ /_/
 *  /_/_/_/  /_/_/_/   /_/_/_/_/ /_/      /_/
 *       Open Decentralized Exchange
 *            https://odex.fi
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OdexToken is ERC20, Ownable {
    uint public immutable deployedTimestamp;
    uint public communityMinted;
    uint public partnerMinted;
    uint public liquidityMinted;
    uint public teamMinted;
    uint public saleMinted;
    uint public startDate;
    uint public endDate;
    uint public startPricePerToken = 0.00001 ether;
    uint public endPricePerToken = 0.000013 ether;
    uint public tokenSaleLimit = 200_000_000 * 10 ** decimals();
    bool public tokenLive;

    event CommunityMinted(address to, uint amount);
    event PartnerMinted(address to, uint amount);
    event LiquidityMinted(address to, uint amount);
    event TeamMinted(address to, uint amount);
    event PublicSale(address to, uint amount, uint ethContributed);

    /**
     * @notice Sets the contract's name, ticker and current timestamp
     *  mints initial distribution including vested team tokens in contract
     * @param _team The address to send the team's initial token grant to
     */
    constructor(address _team) ERC20("ODEX", "ODEX") {
        deployedTimestamp = block.timestamp;
        startDate = deployedTimestamp + 7 days;
        endDate = deployedTimestamp + 37 days;
        tokenLive = true;
        _mint(msg.sender, 400_000_000 * 10 ** decimals());
        _mint(_team, 50_000_000 * 10 ** decimals());
        _transferOwnership(_team);
        tokenLive = false;
    }

    /**
     * @notice Overridden function to ensure token transfers are enabled before transfer
     * @param from The address of sender
     * @param to The address of receiver
     * @param amount The amount of tokens to be transferred
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        require(tokenLive == true, "Token transfers not enabled yet");
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @notice Calculates the price for the given day
     * @param _day The day for which price is to be determined
     * @return currentPrice The calculated price for the day
     */
    function pricePerDay(uint _day) public view returns (uint) {
        uint startDay = 0;
        uint endDay = (endDate - startDate) / 1 days;
        uint timeProgress = _day - startDay;
        uint totalDuration = endDay - startDay;
        uint priceProgress = ((endPricePerToken - startPricePerToken) * timeProgress) / totalDuration;
        uint currentPrice = startPricePerToken + priceProgress;
        return currentPrice;
    }

    /**
     * @notice Get current staggered price
     * @return currentPrice Current staggered price
     */
    function staggeredPrice() public view returns (uint) {
        uint daysPassed = (block.timestamp - startDate) / 1 days;
        uint currentPrice = pricePerDay(daysPassed);
        return currentPrice;
    }

    /**
     * @notice Provides time left in seconds for the next price update and the new price
     * @return secondsLeft The time left in seconds for the next price update
     * @return nextPrice The price after next update
     */
    function nextPriceUpdate() external view returns (uint, uint) {
        uint daysPassed = (block.timestamp - startDate) / 1 days;
        uint nextUpdateTS = startDate + ((daysPassed + 1) * 1 days);
        uint secondsLeft = nextUpdateTS - block.timestamp;
        uint nextPrice = pricePerDay(daysPassed + 1);
        return (secondsLeft, nextPrice);
    }

    /**
     * @notice Allows external users to buy tokens by sending eth with transaction
     */
    function buyTokens() external payable {
        require(block.timestamp > startDate, "too soon");
        require(block.timestamp < endDate, "too late");
        require(msg.value > 0.00001 ether, "min amount in not met");
        uint _price = staggeredPrice();
        uint _amount = (msg.value * 10 ** decimals()) / _price;
        require(_amount > 0, "min amount out not met");
        require(saleMinted + _amount < tokenSaleLimit, "sold out");
        saleMinted += _amount;
        payable(owner()).transfer(msg.value); 
        tokenLive = true;
        _mint(msg.sender, _amount);
        tokenLive = false;
        emit PublicSale(msg.sender, _amount, msg.value);
    }

    /**
     * @notice Allows the owner to make token live and reclaim unsold tokens
     */
    function goLive() external onlyOwner {
        require(block.timestamp > endDate, "too soon");
        require(tokenLive == false, "already claimed");
        tokenLive = true; 
        uint unsoldTokens = tokenSaleLimit - saleMinted;
        saleMinted += unsoldTokens;
        if (unsoldTokens > 0)
            _mint(owner(), unsoldTokens);
    }

    /**
     * @notice Unlock team's tokens after a year has passed since deployment
     * @param _to The address to send the unlocked team tokens to
     * @param _amount The number of tokens to mint
     */
    function unlockTeamTokens(address _to, uint _amount) public onlyOwner {
        uint mintLimit = 50_000_000 * 10 ** decimals();
        require(teamMinted + _amount <= mintLimit, "exceeds mint limit");
        require (block.timestamp > deployedTimestamp + 365 days, "too soon");
        _mint(_to, _amount);
        emit TeamMinted(_to, _amount);
    }

    /**
     * @notice Mints tokens for community contributors
     * @param _to The address to send newly minted community tokens to
     * @param _amount The number of tokens to mint
     */
    function mintCommunity(address _to, uint _amount) public onlyOwner {
        uint mintLimit = 50_000_000 * 10 ** decimals();
        require(communityMinted + _amount <= mintLimit, "exceeds mint limit");
        communityMinted += _amount;
        _mint(_to, _amount);
        emit CommunityMinted(_to, _amount);
    }

    /**
     * @notice Mints tokens for partners
     * @param _to The address to send newly minted partner tokens to
     * @param _amount The number of tokens to mint
     */
    function mintPartner(address _to, uint _amount) public onlyOwner {
        uint mintLimit = 200_000_000 * 10 ** decimals();
        require(partnerMinted + _amount <= mintLimit, "exceeds mint limit");
        partnerMinted += _amount;
        _mint(_to, _amount);
        emit PartnerMinted(_to, _amount);
    }

    /**
     * @notice Mints tokens for liquidity on CEX/DEX
     * @param _to The address to send newly minted advisor tokens to
     * @param _amount The number of tokens to mint
     */
    function mintLiquidity(address _to, uint _amount) public onlyOwner {
        uint mintLimit = 50_000_000 * 10 ** decimals();
        require(liquidityMinted + _amount <= mintLimit, "exceeds mint limit");
        liquidityMinted += _amount;
        _mint(_to, _amount);
        emit LiquidityMinted(_to, _amount);
    }
}