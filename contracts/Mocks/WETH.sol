// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WETH is ERC20, Ownable {
    constructor() ERC20('Wrapped Ether', 'WETH') {
        _mint(msg.sender, 10000000 * 10 ** decimals());
    }

    function mint(address _to, uint _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint wad) public {
        require(balanceOf(msg.sender) >= wad, "not enough weth");
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
    }
    
}