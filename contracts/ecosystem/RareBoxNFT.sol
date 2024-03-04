pragma solidity ^0.8.0;

import "./ERC721Counter.sol";
import "./RandomProvider.sol";
import "./common.sol";

abstract contract ILaserNFT { 
   function safeMint(address to, string memory uri ) public virtual;
   function getTotalCount () public virtual view returns (uint);
   function GetTokenLevel (uint _id) external virtual view returns ( uint32 );
}

contract BoxNFT is ERC721Counter, Ownable, RandomProviderPublic {
     
    struct boxInfo {
       address rewardAddress;
       uint rewardId;
       uint256 rewardAmount;
       bool isPaid;
    }

    mapping(address => bool) minters;
    mapping(uint => boxInfo) boxData;

    ILaserNFT public LaserNFT;

    uint tokenRewardSize = 1000000000000000000000;

    constructor(
      address _laserNFT
   ) {
      LaserNFT = ILaserNFT(_laserNFT);
   }  

   function AddMinter (address _minter) external onlyOwner {
        minters[_minter] = true;
    }

    function RemoveMinter (address _minter) external onlyOwner {
        minters[_minter] = false;
    }

    function UpdateTokenRewardSize (uint _newSize)external onlyOwner {
         tokenRewardSize = _newSize;
    }

    function safeMint(address to, 
                      string memory uri
                      ) public  {
        require(minters[msg.sender], "Mint not permitted for sender");
        _numberMint (to);
    }

    function openBox(uint _boxId) external {
        require(_boxId < _counter, "Box is still not minted");
        require(this.ownerOf(_boxId) == msg.sender, "Caller is not a box owner");
        require(!boxData[_boxId].isPaid, "Box is already opened");
         boxInfo memory currentBoxInfo;
         currentBoxInfo = boxInfo(
                address(LaserNFT),
                LaserNFT.getTotalCount(),
                0,
                true
              );
         boxData[_boxId] = currentBoxInfo;
         LaserNFT.safeMint(msg.sender, "VorpalLaserToken");
    }

    function getBoxInfo (uint _boxId) external view returns (boxInfo memory) {
        return boxData[_boxId];
    }
     
}    