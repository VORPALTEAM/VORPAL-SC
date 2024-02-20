pragma solidity ^0.8.0;

import "./common.sol";

abstract contract IBoxNFT { 
   function safeMint(address to, string memory uri ) public virtual;
   function getTotalCount () public virtual view returns (uint);
}

contract RewardSenderWithChoose is SafeMath, Ownable {
   
   address public rewardToken;
   address public gameAdmin;
   uint256 public rewardSizePart = 10000; // 100% = 1000000000
   uint256 public percentEq = 1000000000;
   uint256 public resourceRewardAmount = 100000000000000000000;
   uint256 private activeAmount = 0;
   uint256 public gameCount = 0;

   IBoxNFT public BoxNFT;

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
      address _boxNFT
   ) {
      rewardToken = _token;
      gameAdmin = _admin;
      rewardSizePart = _rewardSizePart;
      BoxNFT = IBoxNFT(_boxNFT);
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
         uint nftCount = BoxNFT.getTotalCount ();
         BoxNFT.safeMint(_winner, "Box");
              _winParams = RewardData(
                _winner,
                address(BoxNFT),
                0,
                nftCount
            );
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
