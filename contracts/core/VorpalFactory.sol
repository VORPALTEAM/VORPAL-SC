pragma solidity =0.5.16;

import "@openzeppelin/contracts@2.5.0/token/ERC20/IERC20.sol";
import "../interfaces/IVorpalFactory.sol";
import "./VorpalPair.sol";

contract VorpalFactory is IVorpalFactory {
    bytes32 constant public INIT_CODE_HASH = keccak256(abi.encodePacked(type(VorpalPair).creationCode));

    address public feeTo;

    address[] public allPairs;
    mapping(address => mapping(address => address)) public getPair;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor() public {
        feeTo = msg.sender; 
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'Biswap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Biswap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Biswap: PAIR_EXISTS'); // single check is sufficient
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
}
