pragma solidity ^0.6.6;

contract Ownable {
    
    // All veriables will be here
    address owner;

    // constructor is run upon contract being deployed and is only run once
    constructor() {
        owner = msg.sender;
    }

    // Modifiers are used to store a specific parameters that will be called
    // multiple times in a contract. Allowing you to only have to write it once.
    modifier onlyOwner() {
        require(msg.sender == owner, "YOU MUST BE THE OWNER TO DO THAT. SORRY!");
        _;
    }
}

