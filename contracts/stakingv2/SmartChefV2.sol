//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';


contract SmartChefV2 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct RewardToken {
        uint256 rewardPerBlock;
        uint256 startBlock;
        uint256 accTokenPerShare; // Accumulated Tokens per share, times 1e12.
        uint256 rewardsForWithdrawal;
        bool enabled; // true - enable; false - disable
    }

    uint256 public totalStakedSupply;
    uint256 public lastRewardBlock;
    address[] public listRewardTokens;
    IERC20 stakeToken;
    uint256 public stakingEndBlock;

    mapping (address => uint256) public stakedAmount; // Info of each user staked amount
    mapping (address => mapping(address => uint256)) public rewardDebt; //user => (rewardToken => rewardDebt);
    mapping (address => RewardToken) public rewardTokens;

    event AddNewTokenReward(address token);
    event DisableTokenReward(address token);
    event ChangeTokenReward(address indexed token, uint256 rewardPerBlock, uint256 startBlock);
    event StakeToken(address indexed user, uint256 amount);
    event UnstakeToken(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(IERC20 _stakeToken, uint256 _stakingEndBlock) {
        stakeToken = _stakeToken;
        stakingEndBlock = _stakingEndBlock;
    }

    function isTokenInList(address _token) internal view returns(bool){
        address[] memory _listRewardTokens = listRewardTokens;
        bool thereIs = false;
        for(uint256 i = 0; i < _listRewardTokens.length; i++){
            if(_listRewardTokens[i] == _token){
                thereIs = true;
                break;
            }
        }
        return thereIs;
    }

    function getUserStakedAmount(address _user) public view returns(uint256){
        return stakedAmount[_user];
    }

    function getListRewardTokens() public view returns(address[] memory){
        address[] memory list = new address[](listRewardTokens.length);
        list = listRewardTokens;
        return list;
    }

    function addNewTokenReward(address _newToken, uint256 _startBlock, uint256 _rewardPerBlock) public onlyOwner {
        require(_newToken != address(0), "Address shouldn't be 0");
        require(isTokenInList(_newToken) == false, "Token is already in the list");
        listRewardTokens.push(_newToken);
        if(_startBlock == 0){
            rewardTokens[_newToken].startBlock = block.number + 1;
        } else {
            rewardTokens[_newToken].startBlock = _startBlock;
        }
        rewardTokens[_newToken].rewardPerBlock = _rewardPerBlock;
        rewardTokens[_newToken].enabled = true;

        emit AddNewTokenReward(_newToken);
    }

    function disableTokenReward(address _token) public onlyOwner {
        require(isTokenInList(_token), "Token not in the list");
        require(rewardTokens[_token].enabled, "Taken already disabled");
        updatePool();
        rewardTokens[_token].enabled = false;
        emit DisableTokenReward(_token);
    }

    function enableTokenReward(address _token, uint256 _startBlock, uint256 _rewardPerBlock) public onlyOwner {
        require(isTokenInList(_token), "Token not in the list");
        require(!rewardTokens[_token].enabled, "Reward token is enabled");
        if(_startBlock == 0){
            _startBlock = block.number + 1;
        }
        require(_startBlock >= block.number, "Start block Must be later than current");
        rewardTokens[_token].enabled = true;
        rewardTokens[_token].startBlock = _startBlock;
        rewardTokens[_token].rewardPerBlock = _rewardPerBlock;
        updatePool();

        emit ChangeTokenReward(_token, _rewardPerBlock, _startBlock);
    }

    function changeRewardPerBlock(address _token, uint256 _newRewardPerBlock) public onlyOwner {
        require(isTokenInList(_token), "Token not in the list");
        require(rewardTokens[_token].enabled, "Reward token not enabled");
        updatePool();
        rewardTokens[_token].rewardPerBlock = _newRewardPerBlock;
        emit ChangeTokenReward(_token, _newRewardPerBlock, block.timestamp);
    }

    function changeStakingEndBlock(uint256 _newStakingEndBlock) public onlyOwner {
        require(_newStakingEndBlock >= block.number, "Must be greater than current block number");
        stakingEndBlock = _newStakingEndBlock;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if(_to <= stakingEndBlock){
            return _to - _from;
        } else if(_from >= stakingEndBlock) {
            return 0;
        } else {
            return stakingEndBlock - _from;
        }
    }

    // View function to see pending Reward on frontend.
    function pendingReward(address _user) external view returns (address[] memory, uint256[] memory) {
        uint256 _stakedAmount = stakedAmount[_user];
        uint256[] memory rewards = new uint256[](listRewardTokens.length);
        if(_stakedAmount == 0){
            return (listRewardTokens, rewards);
        }
        uint256 _totalSupply = totalStakedSupply;
        uint256 _multiplier = getMultiplier(lastRewardBlock, block.number);
        uint256 _accTokenPerShare = 0;
        for(uint256 i = 0; i < listRewardTokens.length; i++){
            address curToken = listRewardTokens[i];
            RewardToken memory curRewardToken = rewardTokens[curToken];
            if (_multiplier != 0 && _totalSupply != 0 && curRewardToken.enabled == true) {
                uint256 curMultiplier;
                if(getMultiplier(curRewardToken.startBlock, block.number) < _multiplier){
                    curMultiplier = getMultiplier(curRewardToken.startBlock, block.number);
                } else {
                    curMultiplier = _multiplier;
                }
                _accTokenPerShare = curRewardToken.accTokenPerShare +
                (curMultiplier * curRewardToken.rewardPerBlock * 1e12 / _totalSupply);
            } else {
                _accTokenPerShare = curRewardToken.accTokenPerShare;
            }
            rewards[i] = (_stakedAmount * _accTokenPerShare / 1e12) - rewardDebt[_user][curToken];
        }
        return (listRewardTokens, rewards);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        uint256 multiplier = getMultiplier(lastRewardBlock, block.number);
        uint256 _totalSupply = totalStakedSupply; //Gas safe

        lastRewardBlock = block.number;

        if(multiplier == 0){
            return;
        }
        if(_totalSupply == 0){
            return;
        }
        for(uint256 i = 0; i < listRewardTokens.length; i++){
            address curToken = listRewardTokens[i];
            RewardToken memory curRewardToken = rewardTokens[curToken];
            if(curRewardToken.enabled == false || curRewardToken.startBlock >= block.number){
                continue;
            } else {
                uint256 curMultiplier;
                if(getMultiplier(curRewardToken.startBlock, block.number) < multiplier){
                    curMultiplier = getMultiplier(curRewardToken.startBlock, block.number);
                } else {
                    curMultiplier = multiplier;
                }
                uint256 tokenReward = curRewardToken.rewardPerBlock * curMultiplier;
                rewardTokens[curToken].rewardsForWithdrawal += tokenReward;
                rewardTokens[curToken].accTokenPerShare += (tokenReward * 1e12) / _totalSupply;
            }
        }
    }

    function withdrawReward() external {
        _withdrawReward();
    }

    function _updateRewardDebt(address _user) internal {
        for(uint256 i = 0; i < listRewardTokens.length; i++){
            rewardDebt[_user][listRewardTokens[i]] = stakedAmount[_user] * rewardTokens[listRewardTokens[i]].accTokenPerShare / 1e12;
        }
    }

    //SCN-01, SFR-02
    function _withdrawReward() internal {
        updatePool();
        uint256 _stakedAmount = stakedAmount[msg.sender];
        address[] memory _listRewardTokens = listRewardTokens;
        if(_stakedAmount == 0){
            return;
        }
        for(uint256 i = 0; i < _listRewardTokens.length; i++){
            RewardToken storage curRewardToken = rewardTokens[_listRewardTokens[i]];
            uint256 pending = _stakedAmount * curRewardToken.accTokenPerShare / 1e12 - rewardDebt[msg.sender][_listRewardTokens[i]];
            if(pending > 0){
                curRewardToken.rewardsForWithdrawal -= pending;
                rewardDebt[msg.sender][_listRewardTokens[i]] = _stakedAmount * curRewardToken.accTokenPerShare / 1e12;
                IERC20(_listRewardTokens[i]).safeTransfer(address(msg.sender), pending);
            }
        }
    }
    //stake tokens to the pool
    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        _withdrawReward();
        stakeToken.safeTransferFrom(msg.sender, address(this), _amount);
        stakedAmount[msg.sender] += _amount;
        totalStakedSupply += _amount;
        _updateRewardDebt(msg.sender);
        emit StakeToken(msg.sender, _amount);
    }

    // Withdraw tokens from pool
    function unstake(uint256 _amount) external nonReentrant {
        uint256 _stakedAmount = stakedAmount[msg.sender];
        require(_stakedAmount >= _amount && _amount > 0, "Wrong token amount given");
        _withdrawReward();
        stakedAmount[msg.sender] -= _amount;
        totalStakedSupply -= _amount;
        _updateRewardDebt(msg.sender);
        stakeToken.safeTransfer(msg.sender, _amount);
        emit UnstakeToken(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyUnstake() external {
        uint256 _stakedAmount = stakedAmount[msg.sender];
        totalStakedSupply -= _stakedAmount;
        delete stakedAmount[msg.sender];
        for(uint256 i = 0; i < listRewardTokens.length; i++){
            delete rewardDebt[msg.sender][listRewardTokens[i]];
        }
        stakeToken.safeTransfer(msg.sender, _stakedAmount);
        emit EmergencyWithdraw(msg.sender, _stakedAmount);
    }

    // Withdraw reward token. EMERGENCY ONLY.
    function emergencyRewardTokenWithdraw() external onlyOwner {
//        require(address(stakeToken) != _token, "Cant withdraw stake token");
//        require(IERC20(_token).balanceOf(address(this)) >= _amount, "Not enough balance");
        for(uint256 i = 0; i < listRewardTokens.length; i++){
            address _token = listRewardTokens[i];
            uint256 _amount = address(stakeToken) != _token ?
                IERC20(_token).balanceOf(address(this)) :
                IERC20(_token).balanceOf(address(this)) - totalStakedSupply;
            if(_amount > 0) IERC20(_token).safeTransfer(msg.sender, _amount);
        }
    }
}