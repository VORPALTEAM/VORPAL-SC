pragma solidity ^0.8.0;

import "./common.sol";
import "./RandomProvider.sol";

abstract contract ILaserNFT { 
   function safeMint(address to, string memory uri ) public virtual;
   function GetTotalTokenCount () public virtual view returns (uint);
   function GetTokenLevel (uint _id) external virtual view returns ( uint32 );
}

contract RewardSenderWithChoose is SafeMath, Ownable, RandomProvider {
   
   address public rewardToken;
   address public gameAdmin;
   uint256 public rewardSizePart = 10000; // 100% = 1000000000
   uint256 public percentEq = 1000000000;
   uint256 public resourceRewardAmount = 100000000000000000000;
   uint256 private activeAmount = 0;
   uint256 public gameCount = 0;

   IERC20 public Spore;
   IERC20 public Spice;
   IERC20 public Metal;
   IERC20 public Biomass;
   IERC20 public Carbon;
   ILaserNFT public LaserNFT;

   struct RewardData {
      address winner;
      address rewardAddress;
      uint256 rewardAmount;
      uint256 rewardId;
   }

   mapping(address => uint) private balances;
   mapping(address => uint) private rewardCount;
   mapping(address => uint256[]) private userWinHistory;
   mapping(uint => RewardData) private rewards;

   constructor(
      address _admin,
      address _token,
      uint256 _rewardSizePart,
      address _spore,
      address _spice,
      address _metal,
      address _biomass,
      address _carbon,
      address _laserNFT
   ) {
      rewardToken = _token;
      gameAdmin = _admin;
      rewardSizePart = _rewardSizePart;
      Spore = IERC20(_spore);
      Spice = IERC20(_spice);
      Metal = IERC20(_metal);
      Biomass = IERC20(_biomass);
      Carbon = IERC20(_carbon);
      LaserNFT = ILaserNFT(_laserNFT);
   }

   modifier onlyAdmin() {
        require(gameAdmin == _msgSender(), "Caller is not have enough rights");
        _;
    }

   function PullPrizeFund (uint256 _amount) external {
     TransferHelper.safeTransferFrom(rewardToken, msg.sender, address(this), _amount);
     activeAmount += _amount;
   }
   
   function setAdmin (address _newAdmin) external onlyOwner {
       gameAdmin = _newAdmin;
   }

   function updateRewardSizePart (uint256 _newRewardSizePart) external onlyOwner {
       rewardSizePart = _newRewardSizePart;
   }

   function noteWinner (address _winner, bool _rewardRandom ) external onlyAdmin {
      RewardData memory _winParams;
      rewardCount[_winner] += 1;
      gameCount += 1;
      userWinHistory[_winner].push(gameCount);
      
      if (!_rewardRandom) {
        uint256 rewardSize = (activeAmount * rewardSizePart) / percentEq;
        balances[_winner] += rewardSize;
        activeAmount -= rewardSize;
        _winParams = RewardData(
           _winner,
           rewardToken,
           rewardSize,
           0
        );
      } else {
        UpdateRandom();
        uint256 rv = this.GetRandomValue(2);

           if (rv <= 10) {
              uint nftCount = LaserNFT.GetTotalTokenCount ();
              LaserNFT.safeMint(_winner, "VorpalLaserToken");
              _winParams = RewardData(
                _winner,
                address(LaserNFT),
                0,
                nftCount
              );
           }
           if (rv > 10 && rv <= 25) {
             uint256 rewardSize = (activeAmount * rewardSizePart) / percentEq;
             balances[_winner] += rewardSize;
             activeAmount -= rewardSize;
             _winParams = RewardData(
                _winner,
                rewardToken,
                rewardSize,
                0
             );
           }
           if (rv > 25 && rv <= 40) {
             Spore.Mint(resourceRewardAmount, _winner);
             _winParams = RewardData(
                _winner,
                address(Spore),
                resourceRewardAmount,
                0
             );
           }
           if (rv > 40 && rv <= 55) {
             Spice.Mint(resourceRewardAmount, _winner);
             _winParams = RewardData(
                _winner,
                address(Spice),
                resourceRewardAmount,
                0
             );
           }
           if (rv > 55 && rv <= 70) {
             Metal.Mint(resourceRewardAmount, _winner);
             _winParams = RewardData(
                _winner,
                address(Metal),
                resourceRewardAmount,
                0
             );
           }
           if (rv > 70 && rv <= 85) {
             Biomass.Mint(resourceRewardAmount, _winner);
             _winParams = RewardData(
                _winner,
                address(Biomass),
                resourceRewardAmount,
                0
             );
           }
           if (rv > 85 && rv < 100) {
             Carbon.Mint(resourceRewardAmount, _winner);
             _winParams = RewardData(
                _winner,
                address(Carbon),
                resourceRewardAmount,
                0
             );
           }
        rewards[gameCount] = _winParams;
      }
   }

   function withdrawRewards () external {
      require(balances[msg.sender] > 0, 'Caller has a zero balance');
      TransferHelper.safeTransfer(rewardToken, msg.sender, balances[msg.sender]);
      balances[msg.sender] = 0;
   }

   function balanceOf (address _user) external view returns (uint) {
      return balances[_user];
   }

   function getUserWinsCount (address _user) external view returns (uint) {
      return rewardCount[_user];
   }

   function getUserWinHistory (address _user) external view returns (uint256[] memory) {
      return userWinHistory[_user];
   }

   function getGameCount () external view returns (uint) {
      return gameCount;
   }

   function getVictoryData (uint _winId) external view returns (RewardData memory) {
      return rewards[_winId];
   }

}
