// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract USD is ERC20, Ownable {
    constructor() ERC20("Goerli USD Token", "gUSD") {
        _mint(msg.sender, 10000000 * 10 ** decimals());
    }

    function decimals() public pure override returns (uint8) {
		return 6;
	}

    function mint(address _to, uint _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}