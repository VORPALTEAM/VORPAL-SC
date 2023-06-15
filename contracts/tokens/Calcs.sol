// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Calcs {
    uint256 private hash = 0;
    uint[] public lifeTimeByLevel = [0, 4380, 2190, 730]; 
    uint[] public levelMaxFuel = [0, 25000000000000000, 200000000000000000, 2400000000000000000];
    uint[] public levelMinPlanets = [0, 1, 10, 25];
    uint[] public levelMaxPlanets = [0, 5, 25, 50];
    uint[] public levelMinMass = [0, 10000, 50000, 100000];
    uint[] public levelMaxMass = [0, 50000, 100000, 250000];
    string[4] public races = ["Waters", "Humans", "Insects", "Lizards"];

    function UpdateHash() external {
         hash = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
    }

    function RandomPercent() external view returns (uint) {
        uint randomPercent = hash % 100;
        return randomPercent;
    }
    
    function GetRandomPlanetSlots (uint level) external view returns (uint) {
        uint _randomPercent = hash % 100;
        uint _slots = ((levelMinPlanets[level] * 100) + ((levelMaxPlanets[level] - levelMinPlanets[level]) * _randomPercent)) / 100;
        return _slots;
    }

    function GetRandomPlanetMass (uint level) external view returns (uint) {
        uint _randomPercent = hash % 100;
        uint _slots = ((levelMinMass[level] * 100) + ((levelMaxMass[level] - levelMinMass[level]) * _randomPercent)) / 100;
        return _slots;
    }
}