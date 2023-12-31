// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    constructor(string memory _name, string memory _ticker) ERC20(_name, _ticker) {
        _mint(msg.sender, 10000000 * 10 ** decimals());
    }

    function mint(address _to, uint _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}