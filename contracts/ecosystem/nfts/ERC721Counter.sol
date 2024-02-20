pragma solidity ^0.8.0;

import "./ERC721.sol";

abstract contract ERC721Counter is ERC721  {

    uint _counter = 0;
    mapping(address => uint[]) _creationHistory;

    function _numberMint (address _to ) internal {
        _mint(_to, _counter);
        _creationHistory[_to].push(_counter);
        _counter++;
    }

    function getTotalCount() external view returns (uint) {
        return _counter;
    }

    function getUserCreationHistory(address _user) external view returns (uint[] memory) {
        return _creationHistory[_user];
    } 
}