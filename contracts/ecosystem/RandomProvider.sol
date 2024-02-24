pragma solidity ^0.8.4;

abstract contract RandomProvider {

    uint256 private hash = 0;

   function UpdateRandom() internal {
         hash = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
    }

    function GetRandomValue (uint32 _depth) external view returns (uint) {
        uint _randomPercent = hash % (10 ** _depth);
        return _randomPercent;
    }

}

abstract contract RandomProviderPublic {

    uint256 private hash = 0;

   function UpdateRandom() public {
         hash = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
    }

    function GetRandomValue (uint32 _depth) external view returns (uint) {
        uint _randomPercent = hash % (10 ** _depth);
        return _randomPercent;
    }

}