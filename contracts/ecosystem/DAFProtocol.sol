pragma solidity ^0.8.0;

import "./common.sol";

abstract contract IReward {
    function PullPrizeFund (uint256 _amount) external virtual;
}

contract VorpalDAFProtocol is Ownable {

    IERC20 private _vrp;
    IReward private _reward;

    address public vrpToken;
    address public rewarder;
    address public minersProtocol;
    uint256 public lastUpdateBlock;
    uint256 public mintPerBlock = 1000000000000000000000;
    uint256 private adminBalance;
    string[] public federations = ['Humans', 'Insects', 'Waters', 'Lizards'];

    mapping (address => string) userFederation;
    mapping (string => uint256) federationBalances;
    mapping (string => address) federationAdmins;

    constructor( address _vrpToken, address _rewardSender, uint256 _amountPerBlock) {
        _vrp = IERC20(_vrpToken);
        _reward = IReward(_rewardSender);
        rewarder = _rewardSender;
        vrpToken = _vrpToken;
        lastUpdateBlock = block.number;
    }

    function UpdateTokenAmount () external {
        uint256 blockCount = block.number - lastUpdateBlock;
        uint256 mintAmount = mintPerBlock * blockCount;
        _vrp.Mint(mintAmount, address(this));
        uint256 nowAllowed = _vrp.allowance(address(this), rewarder);
        _vrp.approve(rewarder, nowAllowed + mintAmount);
        _reward.PullPrizeFund((mintAmount * 400 * 50) / 1000000);
        adminBalance += (mintAmount * 400 * 950) / 1000000;
        uint256 federationIncome = mintAmount * 150 / 1000;
        federationBalances[federations[0]] += federationIncome;
        federationBalances[federations[1]] += federationIncome;
        federationBalances[federations[2]] += federationIncome;
        federationBalances[federations[3]] += federationIncome;
    }


    function IsNoFederation (address _user) public view returns (bool) {
        return (bytes(userFederation[_user]).length == 0);
    }

    function AppointFederationAdmin (string memory _federation, address _admin) external onlyOwner {
        require(this.IsFederationExists(_federation), "Incorrect federation name");
        federationAdmins[_federation] = _admin;
    }

    function WithdrawAdminTokens (address _to) external onlyOwner {
        require(adminBalance > 0, "Nothing to withdraw");
        TransferHelper.safeTransfer(vrpToken, _to, adminBalance);
        adminBalance = 0;
    }

    function WithdrawFederationTokens (string memory _federation, address _to) external {
        require(this.IsFederationExists(_federation), "Incorrect federation name");
        require(federationAdmins[_federation] == msg.sender, "No rights to action");
        require(adminBalance > 0, "Nothing to withdraw");
        TransferHelper.safeTransfer(vrpToken, _to, federationBalances[_federation]);
        federationBalances[_federation] = 0;
    }

    function IsFederationExists (string memory _federation) public view returns (bool) {
        bool isTrueFederation = false;

        for (uint256 i = 0; i < federations.length; i++) {
            if (keccak256(bytes(federations[i])) == keccak256(bytes(_federation))) {
                 isTrueFederation = true;
            }
        }

        return isTrueFederation;
    }

    function GetUserFederation (address _user) external view returns (string memory) {
        return userFederation[_user];
    }

    function GetFederationAdmin (string memory _federation) external view returns (address) {
        require(this.IsFederationExists(_federation), "Incorrect federation name");
        return federationAdmins[_federation];
    }

    function EnterFederation (string memory _federation) external {
        require(this.IsFederationExists(_federation), "Incorrect federation name");
        require(this.IsNoFederation(msg.sender), "User already in federation");
        userFederation[msg.sender] = _federation;
    }

    function ExitFederation () external { 
        userFederation[msg.sender] = "";
    }
    
}
