pragma solidity ^0.8.0;

import "./ERC721Counter.sol";
import "./RandomProvider.sol";
import "./common.sol";

abstract contract ILaserNFT { 
   function safeMint(address to, string memory uri, uint32 _level ) public virtual;
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
    mapping(uint => bool) usedNumbers;
    mapping(uint => boxInfo) boxData;

    IERC20 public Spore;
    IERC20 public Spice;
    IERC20 public Metal;
    IERC20 public Biomass;
    IERC20 public Carbon;
    IERC20 public VRPReward;
    ILaserNFT public LaserNFT;

    uint tokenRewardSize = 1000000000000000000000;

    constructor(
      address _spore,
      address _spice,
      address _metal,
      address _biomass,
      address _carbon,
      address _rewardVRP,
      address _laserNFT
   ) {
      Spore = IERC20(_spore);
      Spice = IERC20(_spice);
      Metal = IERC20(_metal);
      Biomass = IERC20(_biomass);
      Carbon = IERC20(_carbon);
      VRPReward = IERC20(_rewardVRP);
      LaserNFT = ILaserNFT(_laserNFT);
   }  

   function AddMinter (address _minter) external onlyOwner {
        minters[_minter] = true;
    }

    function RemoveMinter (address _minter) external onlyOwner {
        minters[_minter] = false;
    }

    function IsMinter (address _minter) external view returns (bool) {
      return minters[_minter];
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

    function openBox(uint _boxId, uint _random) external {
        require(_boxId < _counter, "Box is still not minted");
        require(this.ownerOf(_boxId) == msg.sender, "Caller is not a box owner");
        require(!boxData[_boxId].isPaid, "Box is already opened");
        require(!usedNumbers[_random], "Value is already used");
        // UpdateRandom();
        usedNumbers[_random] = true; 
        uint rv = _random % 100;
        boxInfo memory currentBoxInfo;
            if (rv <= 10) {
              boxInfo memory currentBoxInfo;
              currentBoxInfo = boxInfo(
                address(LaserNFT),
                LaserNFT.getTotalCount(),
                0,
                true
              );
              boxData[_boxId] = currentBoxInfo;
              uint32 laserlevel = uint32(rv % 3);
              LaserNFT.safeMint(msg.sender, "VorpalLaserToken", laserlevel);
           }
           if (rv > 10 && rv <= 25) {
             currentBoxInfo = boxInfo(
                address(VRPReward),
                0,
                tokenRewardSize,
                true
             );
             boxData[_boxId] = currentBoxInfo;
             VRPReward.Mint(tokenRewardSize, msg.sender);
           }
           if (rv > 25 && rv <= 40) {
             currentBoxInfo = boxInfo(
                address(Spore),
                0,
                tokenRewardSize,
                true
             );
             boxData[_boxId] = currentBoxInfo;
             Spore.Mint(tokenRewardSize, msg.sender);
           }
           if (rv > 40 && rv <= 55) {
             currentBoxInfo = boxInfo(
                address(Spice),
                0,
                tokenRewardSize,
                true
             );
             boxData[_boxId] = currentBoxInfo;
             Spice.Mint(tokenRewardSize, msg.sender);
           }
           if (rv > 55 && rv <= 70) {
             currentBoxInfo = boxInfo(
                address(Metal),
                0,
                tokenRewardSize,
                true
             );
             boxData[_boxId] = currentBoxInfo;
             Metal.Mint(tokenRewardSize, msg.sender);
           }
           if (rv > 70 && rv <= 85) {
             currentBoxInfo = boxInfo(
                address(Biomass),
                0,
                tokenRewardSize,
                true
             );
             boxData[_boxId] = currentBoxInfo;
             Biomass.Mint(tokenRewardSize, msg.sender);
           }
           if (rv > 85 && rv < 100) {
             currentBoxInfo = boxInfo(
                address(Carbon),
                0,
                tokenRewardSize,
                true
             );
             boxData[_boxId] = currentBoxInfo;
             Carbon.Mint(tokenRewardSize, msg.sender);
           }
    }

    function getBoxInfo (uint _boxId) external view returns (boxInfo memory) {
        return boxData[_boxId];
    }
     
}    