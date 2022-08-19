pragma solidity 0.6.6;

import "@openzeppelin/contracts@3.4.0/access/Ownable.sol"; 
import "./lib/SafeMath.sol";
import "./lib/EnumerableSet.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IVorpalFactory.sol"; 
import "./interfaces/IVorpalPair.sol";

interface IVorpalToken is IERC20 {
    function mint(address to, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external override returns (bool);
}

interface IVorpalNFT {
    function accrueRB(address user, uint256 amount) external;
    function tokenFreeze(uint256 tokenId) external;
    function tokenUnfreeze(uint256 tokenId) external;
    function getRB(uint256 tokenId) external view returns(uint256);
    function getInfoForStaking(uint256 tokenId) external view returns(address tokenOwner, bool stakeFreeze, uint256 robiBoost);
}

interface ITreasury {
    function transfer(address to, uint256 value) external returns (bool);
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() public {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}


contract SwapFeeRewardWithRB is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _whitelist;

       struct PairsList {
        address pair;
        uint256 percentReward;
        bool enabled;
    }

    address public factory;
    address public router;
    address public market;
    address public auction;
    bytes32 public INIT_CODE_HASH;
    uint256 public maxMiningAmount = 100000000 ether;
    uint256 public maxMiningInPhase = 5000 ether;
    uint256 public maxAccruedRBInPhase = 5000 ether;

    uint256 public currentPhase = 1;
    uint256 public currentPhaseRB = 1;
    uint256 public totalMined = 0;
    uint256 public totalAccruedRB = 0;
    uint256 public rbWagerOnSwap = 1500; //Wager of RB
    uint256 public rbPercentMarket = 10000; // (div 10000)
    uint256 public rbPercentAuction = 10000; // (div 10000)
    address public treasury;
    IOracle public oracle;
    IVorpalNFT public VorpalNFT;
    address public targetToken;
    address public targetRBToken;
    uint256 public defaultFeeDistribution = 90;

    mapping(address => uint256) public nonces;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) public pairOfPid;

    //percent of distribution between feeReward and robiBoost [0, 90] 0 => 90% feeReward and 10% robiBoost; 90 => 100% robiBoost
    //calculate: defaultFeeDistribution (90) - feeDistibution = feeReward
    mapping(address => uint256) public feeDistribution;

    PairsList[] public pairsList;

    event Withdraw(address userAddress, uint256 amount);
    event Rewarded(address account, address input, address output, uint256 amount, uint256 quantity);
    //BNF-01, SFR-01
    event NewRouter(address);
    event NewFactory(address);
    event NewMarket(address);
    event NewPhase(uint256);
    event NewPhaseRB(uint256);
    event NewAuction(address);
    event NewVorpalNFT(IVorpalNFT);
    event NewOracle(IOracle);

    modifier onlyRouter() {
        require(msg.sender == router, "SwapFeeReward: caller is not the router");
        _;
    }

    modifier onlyMarket() {
        require(msg.sender == market, "SwapFeeReward: caller is not the market");
        _;
    }

    modifier onlyAuction() {
        require(msg.sender == auction, "SwapFeeReward: caller is not the auction");
        _;
    }

    constructor(
        address _factory,
        address _router,
        bytes32 _INIT_CODE_HASH,
        address _treasury,
        IOracle _Oracle,
        IVorpalNFT _VorpalNFT,
        address _targetToken,
        address _targetRBToken

    ) public {
        factory = _factory;
        router = _router;
        INIT_CODE_HASH = _INIT_CODE_HASH;
        treasury = _treasury;
        oracle = _Oracle;
        targetToken = _targetToken;
        VorpalNFT = _VorpalNFT;
        targetRBToken = _targetRBToken;
    }

    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, "VorpalSwapFactory: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "VorpalSwapFactory: ZERO_ADDRESS");
    }

    function pairFor(address tokenA, address tokenB) public view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint256(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                INIT_CODE_HASH
            ))));
    }

    function getSwapFee(address tokenA, address tokenB) internal view returns (uint256 swapFee) {
        swapFee = uint256(1000).sub(IVorpalPair(pairFor(tokenA, tokenB)).swapFee());
    }

    function setPhase(uint256 _newPhase) public onlyOwner returns (bool){
        currentPhase = _newPhase;
        emit NewPhase(_newPhase);
        return true;
    }

    function setPhaseRB(uint256 _newPhase) public onlyOwner returns (bool){
        currentPhaseRB = _newPhase;
        emit NewPhaseRB(_newPhase);
        return true;
    }

    function checkPairExist(address tokenA, address tokenB) public view returns (bool) {
        address pair = pairFor(tokenA, tokenB);
        PairsList storage pool = pairsList[pairOfPid[pair]];
        if (pool.pair != pair) {
            return false;
        }
        return true;
    }

    function feeCalculate(address account, address input, address output, uint256 amount)
    public
    view
    returns(
        uint256 feeReturnInVorpal,
        uint256 feeReturnInUSD,
        uint256 robiBoostAccrue
    )
    {

        uint256 pairFee = getSwapFee(input, output);
        address pair = pairFor(input, output);
        PairsList memory pool = pairsList[pairOfPid[pair]];
        if (pool.pair != pair || pool.enabled == false || !isWhitelist(input) || !isWhitelist(output)) {
            feeReturnInVorpal = 0;
            feeReturnInUSD = 0;
            robiBoostAccrue = 0;
        } else {
            (uint256 feeAmount, uint256 rbAmount) = calcAmounts(amount, account);
            uint256 fee = feeAmount.div(pairFee);
            uint256 quantity = getQuantity(output, fee, targetToken);
            feeReturnInVorpal = quantity.mul(pool.percentReward).div(100);
            robiBoostAccrue = getQuantity(output, rbAmount.div(rbWagerOnSwap), targetRBToken);
            feeReturnInUSD = getQuantity(targetToken, feeReturnInVorpal, targetRBToken);
        }
    }

    function swap(address account, address input, address output, uint256 amount) public onlyRouter returns (bool) {
        if (!isWhitelist(input) || !isWhitelist(output)) {
            return false;
        }
        address pair = pairFor(input, output);
        PairsList memory pool = pairsList[pairOfPid[pair]];
        if (pool.pair != pair || pool.enabled == false) {
            return false;
        }
        uint256 pairFee = getSwapFee(input, output);
        (uint256 feeAmount, uint256 rbAmount) = calcAmounts(amount, account);
        uint256 fee = feeAmount.div(pairFee);
        rbAmount = rbAmount.div(rbWagerOnSwap);
        //SFR-05
        _accrueRB(account, output, rbAmount);

        uint256 quantity = getQuantity(output, fee, targetToken);
        quantity = quantity.mul(pool.percentReward).div(100);
        if (maxMiningAmount >= totalMined.add(quantity)) {
            if (totalMined.add(quantity) <= currentPhase.mul(maxMiningInPhase)) {
                _balances[account] = _balances[account].add(quantity);
                emit Rewarded(account, input, output, amount, quantity);
            }
        }
        return true;
    }

    function calcAmounts(uint256 amount, address account) internal view returns(uint256 feeAmount, uint256 rbAmount){
        feeAmount = amount.mul(defaultFeeDistribution.sub(feeDistribution[account])).div(100);
        rbAmount = amount.sub(feeAmount);
    }

    function accrueRBFromMarket(address account, address fromToken, uint256 amount) public onlyMarket {
        //SFR-05
        amount = amount.mul(rbPercentMarket).div(10000);
        _accrueRB(account, fromToken, amount);
    }

    function accrueRBFromAuction(address account, address fromToken, uint256 amount) public onlyAuction {
        //SFR-05
        amount = amount.mul(rbPercentAuction).div(10000);
        _accrueRB(account, fromToken, amount);
    }

    //SFR-05
    function _accrueRB(address account, address output, uint256 amount) private {
        uint256 quantity = getQuantity(output, amount, targetRBToken);
        if (quantity > 0) {
            //SFR-06
            totalAccruedRB = totalAccruedRB.add(quantity);
            if(totalAccruedRB <= currentPhaseRB.mul(maxAccruedRBInPhase)){
                VorpalNFT.accrueRB(account, quantity);
            }
        }
    }

    function rewardBalance(address account) public view returns (uint256){
        return _balances[account];
    }

    function permit(address spender, uint256 value, uint8 v, bytes32 r, bytes32 s) private {
        bytes32 message = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(spender, value, nonces[spender]++))));
        address recoveredAddress = ecrecover(message, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == spender, "SwapFeeReward: INVALID_SIGNATURE");
    }

    function withdraw(uint8 v, bytes32 r, bytes32 s) public nonReentrant returns (bool){
        require(maxMiningAmount > totalMined, "SwapFeeReward: Mined all tokens");
        uint256 balance = _balances[msg.sender];
        require(totalMined.add(balance) <= currentPhase.mul(maxMiningInPhase), "SwapFeeReward: Mined all tokens in this phase");
        permit(msg.sender, balance, v, r, s);
        if (balance > 0) {
            _balances[msg.sender] = _balances[msg.sender].sub(balance);
            totalMined = totalMined.add(balance);
            //SFR-04
            if(treasury.transfer(msg.sender, balance)){
                emit Withdraw(msg.sender, balance);
                return true;
            }
        }
        return false;
    }

    function getQuantity(address outputToken, uint256 outputAmount, address anchorToken) public view returns (uint256) {
        uint256 quantity = 0;
        if (outputToken == anchorToken) {
            quantity = outputAmount;
        } else if (IVorpalFactory(factory).getPair(outputToken, anchorToken) != address(0) && checkPairExist(outputToken, anchorToken)) {
            quantity = IOracle(oracle).consult(outputToken, outputAmount, anchorToken);
        } else {
            uint256 length = getWhitelistLength();
            for (uint256 index = 0; index < length; index++) {
                address intermediate = getWhitelist(index);
                if (IVorpalFactory(factory).getPair(outputToken, intermediate) != address(0) && IVorpalFactory(factory).getPair(intermediate, anchorToken) != address(0) && checkPairExist(intermediate, anchorToken)) {
                    uint256 interQuantity = IOracle(oracle).consult(outputToken, outputAmount, intermediate);
                    quantity = IOracle(oracle).consult(intermediate, interQuantity, anchorToken);
                    break;
                }
            }
        }
        return quantity;
    }

    function addWhitelist(address _addToken) public onlyOwner returns (bool) {
        require(_addToken != address(0), "SwapMining: token is the zero address");
        return EnumerableSet.add(_whitelist, _addToken);
    }

    function delWhitelist(address _delToken) public onlyOwner returns (bool) {
        require(_delToken != address(0), "SwapMining: token is the zero address");
        return EnumerableSet.remove(_whitelist, _delToken);
    }

    function getWhitelistLength() public view returns (uint256) {
        return EnumerableSet.length(_whitelist);
    }

    function isWhitelist(address _token) public view returns (bool) {
        return EnumerableSet.contains(_whitelist, _token);
    }

    function getWhitelist(uint256 _index) public view returns (address){
        //SFR-06
        require(_index <= getWhitelistLength().sub(1), "SwapMining: index out of bounds");
        return EnumerableSet.at(_whitelist, _index);
    }

    function setRouter(address newRouter) public onlyOwner {
        require(newRouter != address(0), "SwapMining: new router is the zero address");
        router = newRouter;
        //BNF-01, SFR-01
        emit NewRouter(newRouter);
    }

    function setMarket(address _market) public onlyOwner {
        require(_market != address(0), "SwapMining: new market is the zero address");
        market = _market;
        //BNF-01, SFR-01
        emit NewMarket(_market);
    }

    function setAuction(address _auction) public onlyOwner {
        require(_auction != address(0), "SwapMining: new auction is the zero address");
        auction = _auction;
        //BNF-01, SFR-01
        emit NewAuction(_auction);
    }

    function setVorpalNFT(IVorpalNFT _VorpalNFT) public onlyOwner {
        require(address(_VorpalNFT) != address(0), "SwapMining: new VorpalNFT is the zero address");
        VorpalNFT = _VorpalNFT;
        //BNF-01, SFR-01
        emit NewVorpalNFT(_VorpalNFT);
    }

    function setOracle(IOracle _oracle) public onlyOwner {
        require(address(_oracle) != address(0), "SwapMining: new oracle is the zero address");
        oracle = _oracle;
        //BNF-01, SFR-01
        emit NewOracle(_oracle);
    }

    function setFactory(address _factory) public onlyOwner {
        require(_factory != address(0), "SwapMining: new factory is the zero address");
        factory = _factory;
        //BNF-01, SFR-01
        emit NewFactory(_factory);
    }

    function setInitCodeHash(bytes32 _INIT_CODE_HASH) public onlyOwner {
        INIT_CODE_HASH = _INIT_CODE_HASH;
    }

    function pairsListLength() public view returns (uint256) {
        return pairsList.length;
    }

    function addPair(uint256 _percentReward, address _pair) public onlyOwner {
        require(_pair != address(0), "_pair is the zero address");
        pairsList.push(
            PairsList({
        pair : _pair,
        percentReward : _percentReward,
        enabled : true
        })
        );
        //SFR-06
        pairOfPid[_pair] = pairsListLength().sub(1);

    }

    function setPair(uint256 _pid, uint256 _percentReward) public onlyOwner {
        pairsList[_pid].percentReward = _percentReward;
    }

    function setPairEnabled(uint256 _pid, bool _enabled) public onlyOwner {
        pairsList[_pid].enabled = _enabled;
    }

    function setRobiBoostReward(uint256 _rbWagerOnSwap, uint256 _percentMarket, uint256 _percentAuction) public onlyOwner {
        rbWagerOnSwap = _rbWagerOnSwap;
        rbPercentMarket = _percentMarket;
        rbPercentAuction = _percentAuction;
    }

    function setFeeDistribution(uint256 newDistribution) public {
        require(newDistribution <= defaultFeeDistribution, "Wrong fee distribution");
        feeDistribution[msg.sender] = newDistribution;
    }

}