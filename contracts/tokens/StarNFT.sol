// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

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

library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

contract StarNFT721 is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    address public plasmaToken;
    uint[] public lifeTimeByLevel = [0, 4380, 2190, 730]; 
    uint[] public levelMaxFuel = [0, 25000000000000000, 200000000000000000, 2400000000000000000];
    uint[] public levelMinPlanets = [0, 1, 10, 25];
    uint[] public levelMaxPlanets = [0, 5, 25, 50];
    uint[] public levelMinMass = [0, 10000, 50000, 100000];
    uint[] public levelMaxMass = [0, 50000, 100000, 250000];
    string[4] public races = ["Waters", "Humans", "Insects", "Lizards"];

    struct StarParams {
        string name;
        bool isLive;
        uint creation;  // timestamp
        uint updated;
        uint32 level;
        uint fuel;
        uint levelUpFuel;
        uint fuelSpendings; // per hour
        uint habitableZoneMin;
        uint habitableZoneMax;
        uint planetSlots;
        uint mass;
        string race;
        uint[3] coords;
    }

    Counters.Counter public _tokenIdCounter;
    mapping(uint256 => StarParams) private _params;

    constructor(
       address _plasma
      ) ERC721(
        "VorpalMetaverseStar", "STAR"
        ) {
            plasmaToken = _plasma;
        }

    /* Temporary data for tests */

    function CalcCreationCost (uint32 level) public view returns (uint) {
        uint tokenNum = _tokenIdCounter.current();
        if (tokenNum < 10) {
            tokenNum = 10;
        }
        uint cost = 100000000000000000 * 2^(tokenNum / 10) * 4^(level - 1);
        return cost;
    }

    function GetTotalStarCount () public view returns (uint) {
        return _tokenIdCounter.current();
    }

    function IsRaceExists (string memory _race) public view returns (bool) {
        bool isTrueRace = false;

        for (uint256 i = 0; i < races.length; i++) {
            if (keccak256(bytes(races[i])) == keccak256(bytes(_race))) {
                 isTrueRace = true;
            }
        }
        if (!isTrueRace) {
            revert("Entered race not exists");
        }

        return isTrueRace;
    }

    function safeMint(address to, 
                      string memory uri, 
                      string memory _name,
                      string memory _race,
                      uint coordX,
                      uint coordY,
                      uint coordZ
                      ) public {
        require(IsRaceExists(_race), "Race not exists!");
        uint cost = CalcCreationCost(1);
        uint lifeTime = lifeTimeByLevel[1]; // 6 months in hours
        TransferHelper.safeTransferFrom(plasmaToken, msg.sender, address(this), cost);
        uint256 hash = uint256(keccak256(abi.encode(blockhash(block.number))));
        uint randomPercent = hash % 100;
        uint _planetSlots = levelMinPlanets[1] + ((levelMaxPlanets[1] - levelMinPlanets[1]) * (randomPercent / 100));
        uint mass = levelMinMass[1] + ((levelMaxMass[1] - levelMinMass[1]) * (randomPercent / 100));
        StarParams memory _newStar;

        _newStar = StarParams(
            _name,
            true,
            block.timestamp,  // timestamp
            block.timestamp,
            1,
            cost,
            0,
            cost / lifeTime, // per hour
            3,
            5,
            _planetSlots,
            mass,
            _race,
            [coordX, coordY, coordZ]
        );

        uint256 tokenId = _tokenIdCounter.current();
        _params[tokenId] = _newStar;
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function GetStarParams (uint256 tokenId) public view returns (StarParams memory) {
          return _params[tokenId];
    }

    function UpdateStarLifecycle (uint256 tokenId) external {
         uint time = block.timestamp;
         uint lifehours = (time - _params[tokenId].updated) / 3600;
         uint totalSpendings = _params[tokenId].fuelSpendings * lifehours;
         _params[tokenId].updated = time;

         if (totalSpendings >= _params[tokenId].fuel) {
             _params[tokenId].isLive = false;
         } else {
             _params[tokenId].fuel -= totalSpendings;
         }

    }

    function UpdateStarFuel (uint256 tokenId, uint fuel) external {
        require(_params[tokenId].isLive == true, "Star is already dead");
        TransferHelper.safeTransferFrom(plasmaToken, msg.sender, address(this), fuel);
        uint newFuel = _params[tokenId].fuel + fuel;
        uint maxFuel = levelMaxFuel[_params[tokenId].level];
        if ( newFuel > maxFuel) {
            newFuel = maxFuel;
        }
        _params[tokenId].fuel = newFuel;
    }

    function UpdateStarLevelFuel (uint256 tokenId, uint fuel) external {
        require(_params[tokenId].isLive == true, "Star is already dead");
        TransferHelper.safeTransferFrom(plasmaToken, msg.sender, address(this), fuel);
        _params[tokenId].levelUpFuel += fuel;
    }

    function IncreaseStarLevel ( uint256 tokenId ) external {
        require(_params[tokenId].isLive == true, "Star is already dead");
        require(this.ownerOf(tokenId) == msg.sender, "Caller is not a star owner");
        uint32 newLevel = _params[tokenId].level + 1;
        uint cost = CalcCreationCost (newLevel);
        if ( newLevel > 3 ) {
            revert("High levels not allowed in demo version");
        }
        if ( _params[tokenId].levelUpFuel < cost) {
            revert("Not enough balance to increase level");
        }

        _params[tokenId].level = newLevel;
        _params[tokenId].fuel += _params[tokenId].levelUpFuel;
        _params[tokenId].levelUpFuel = 0;
        _params[tokenId].updated = block.timestamp;
        _params[tokenId].fuelSpendings = cost / lifeTimeByLevel[newLevel];
        _params[tokenId].habitableZoneMin +=2;
        _params[tokenId].habitableZoneMax +=3;

        uint256 hash = uint256(keccak256(abi.encode(blockhash(block.number))));
        uint randomPercent = hash % 100;

        uint newPlanetSlots = levelMinPlanets[newLevel] + ((levelMaxPlanets[newLevel] - levelMinPlanets[newLevel]) * (randomPercent / 100));
        _params[tokenId].planetSlots = newPlanetSlots;

        uint mass = levelMinMass[newLevel] + ((levelMaxMass[newLevel] - levelMinMass[newLevel]) * (randomPercent / 100));
        _params[tokenId].mass = mass;
    }

}