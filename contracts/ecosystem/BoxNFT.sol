pragma solidity ^0.8.0;

import "./nfts/ERC721Counter.sol";
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
        UpdateRandom();
        uint rv = this.GetRandomValue(2);
        boxInfo memory currentBoxInfo;
            if (rv <= 10) {
              currentBoxInfo = boxInfo(
                address(LaserNFT),
                LaserNFT.getTotalCount(),
                0,
                true
              );
              LaserNFT.safeMint(msg.sender, "VorpalLaserToken");
           }
           if (rv > 10 && rv <= 100) {
             currentBoxInfo = boxInfo(
                address(VRPReward),
                0,
                tokenRewardSize,
                true
             );
             VRPReward.Mint(tokenRewardSize, msg.sender);
           }
           if (rv > 25 && rv <= 40) {
             currentBoxInfo = boxInfo(
                address(Spore),
                0,
                tokenRewardSize,
                true
             );
             Spore.Mint(tokenRewardSize, msg.sender);
           }
           if (rv > 40 && rv <= 55) {
             currentBoxInfo = boxInfo(
                address(Spice),
                0,
                tokenRewardSize,
                true
             );
             Spice.Mint(tokenRewardSize, msg.sender);
           }
           if (rv > 55 && rv <= 70) {
             currentBoxInfo = boxInfo(
                address(Metal),
                0,
                tokenRewardSize,
                true
             );
             Metal.Mint(tokenRewardSize, msg.sender);
           }
           if (rv > 70 && rv <= 85) {
             currentBoxInfo = boxInfo(
                address(Biomass),
                0,
                tokenRewardSize,
                true
             );
             Biomass.Mint(tokenRewardSize, msg.sender);
           }
           if (rv > 85 && rv < 100) {
             currentBoxInfo = boxInfo(
                address(Carbon),
                0,
                tokenRewardSize,
                true
             );
             Carbon.Mint(tokenRewardSize, msg.sender);
           }
           boxData[_boxId] = currentBoxInfo;
    }

    function getBoxInfo (uint _boxId) external view returns (boxInfo memory) {
        return boxData[_boxId];
    }
     
}    