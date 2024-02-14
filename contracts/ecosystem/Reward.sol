pragma solidity ^0.8.0;

import "./common.sol";

contract RewardSender is SafeMath, Ownable {
   
   address public rewardToken;
   address public gameAdmin;
   uint256 public rewardSizePart = 10000; // 100% = 1000000000
   uint256 public percentEq = 1000000000;
   uint256 private activeAmount = 0;

   mapping(address => uint) balances;
   mapping(address => uint) rewardCount;

   constructor(
      address _admin,
      address _token,
      uint256 _rewardSizePart
   ) {
      rewardToken = _token;
      gameAdmin = _admin;
      rewardSizePart = _rewardSizePart;
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

   function noteWinner (address _winner) external onlyAdmin {
      uint256 rewardSize = (activeAmount * rewardSizePart) / percentEq;
      balances[_winner] += rewardSize;
      activeAmount -= rewardSize;
      rewardCount[_winner] += 1;
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
}
