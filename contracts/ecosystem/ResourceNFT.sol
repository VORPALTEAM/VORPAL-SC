// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./nfts/ERC721Counter.sol";
import "./RandomProvider.sol";
import "./common.sol";

abstract contract ERC20Interface {
    function totalSupply() public virtual view returns (uint);
    function balanceOf(address tokenOwner) public virtual  view returns (uint balance);
    function allowance(address tokenOwner, address spender) public virtual  view returns (uint remaining);
    function transfer(address to, uint tokens) public virtual  returns (bool success);
    function approve(address spender, uint tokens) public virtual  returns (bool success);
    function transferFrom(address from, address to, uint tokens) public virtual  returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract GameResourceNFT721 is  ERC721Counter, Ownable, RandomProviderPublic {

    string[4] public races = ["Waters", "Humans", "Insects", "Lizards"];
    mapping(address => bool) minters;
    mapping(uint => uint32) tokenValueLevels;
    mapping(address => uint[]) userTokenHistory;

    constructor() {
    }

    
    function AddMinter (address _minter) external onlyOwner {
        minters[_minter] = true;
    }

    function RemoveMinter (address _minter) external onlyOwner {
        minters[_minter] = false;
    }

    function safeMint(address to, 
                      string memory uri
                      ) public  {
        require(minters[msg.sender], "Mint not permitted for sender");
        UpdateRandom();
        uint rv = this.GetRandomValue(2);
        if (rv < 10) {
            tokenValueLevels[_counter] = 2;
        }
        if (rv >= 10 && rv < 30) {
            tokenValueLevels[_counter] = 1;
        }

        if (rv >= 30) {
            tokenValueLevels[_counter] = 0;
        }
        _numberMint (to);
    }

    /* Acknow token data */

    function GetTokenLevel (uint _id) external view returns ( uint32 ) {
        require(_id < _counter, "Token is still not exists");
        return tokenValueLevels[_id];
    }

    function GetUserCreatedTokens (address _user) external view returns ( uint[] memory ) {
        return userTokenHistory[_user];
    }

}