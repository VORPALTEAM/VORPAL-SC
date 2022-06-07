pragma solidity =0.5.16;

import "@openzeppelin/contracts@2.5.0/token/ERC20/IERC20.sol";
import "./interfaces/IVorpalFactory.sol";
import "./VorpalPair.sol";

contract VorpalFactory is IVorpalFactory {
    bytes32 constant public INIT_CODE_HASH = keccak256(abi.encodePacked(type(VorpalPair).creationCode));

    address public feeTo;
    address public feeToSetter;
    
    address[] public allPairs;
    mapping(address => mapping(address => address)) public getPair;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
         feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "Vorpal: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Vorpal: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "Vorpal: PAIR_EXISTS"); // single check is sufficient
        bytes memory bytecode = type(VorpalPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IVorpalPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

     function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'Biswap: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'Biswap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setDevFee(address _pair, uint8 _devFee) external {
        require(msg.sender == feeToSetter, 'Biswap: FORBIDDEN');
        require(_devFee > 0, 'Biswap: FORBIDDEN_FEE');
        VorpalPair(_pair).setDevFee(_devFee);
    }
    
    function setSwapFee(address _pair, uint32 _swapFee) external {
        require(msg.sender == feeToSetter, 'Biswap: FORBIDDEN');
        VorpalPair(_pair).setSwapFee(_swapFee);
    }
}
