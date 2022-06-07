pragma solidity 0.6.6;

import "@openzeppelin/contracts@3.4.0/token/ERC20/ERC20.sol"; 

contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public ERC20(name, symbol) {
        _mint(msg.sender, supply);

    }
}