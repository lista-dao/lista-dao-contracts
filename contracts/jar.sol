// SPDX-License-Identifier: AGPL-3.0-or-later

/// jar.sol -- Hay distribution farming

// Copyright (C) 2022
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/*
   "Put rewards in the jar and close it".
   This contract lets you deposit HAYs from hay.sol and earn
   HAY rewards. The HAY rewards are deposited into this contract
   and distributed over a timeline. Users can redeem rewards
   after exit delay.
*/

contract Jar is Initializable {
    // --- Wrapper ---
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address guy) external auth { wards[guy] = 1; }
    function deny(address guy) external auth { wards[guy] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "Jar/not-authorized");
        _;
    }

    // --- Derivative ---
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;

    // --- Reward Data ---
    uint public spread;      // Distribution time     [sec]
    uint public endTime;     // Time "now" + spread   [sec]
    uint public rate;        // Emission per second   [wad]
    uint public tps;         // HAY tokens per share  [wad]
    uint public lastUpdate;  // Last tps update       [sec]
    uint public exitDelay;   // User unstake delay    [sec]
    address public HAY;      // The HAY Stable Coin

    mapping(address => uint) public tpsPaid;      // HAY per share paid
    mapping(address => uint) public rewards;      // Accumulated rewards
    mapping(address => uint) public withdrawn;    // Capital withdrawn
    mapping(address => uint) public unstakeTime;  // Time of Unstake

    uint    public live;     // Active Flag

    // --- Events ---
    event Initialized(address indexed token, uint indexed duration, uint indexed exitDelay);
    event Replenished(uint reward);
    event SpreadUpdated(uint newDuration);
    event ExitDelayUpdated(uint exitDelay);
    event Join(address indexed user, uint indexed amount);
    event Exit(address indexed user, uint indexed amount);
    event Redeem(address[] indexed user);
    event Cage();

    // --- Init ---
    function initialize(string memory _name, string memory _symbol) external initializer {
       wards[msg.sender] = 1;
        live = 1;
        name = _name;
        symbol = _symbol;
    }

    // --- Math ---
    function _min(uint a, uint b) internal pure returns (uint) {
        return a < b ? a : b;
    }

    // --- Mods ---
    modifier update(address account) {
        tps = tokensPerShare();
        lastUpdate = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            tpsPaid[account] = tps;
        }
        _;
    }

    // --- Views ---
    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(block.timestamp, endTime);
    }
    function tokensPerShare() public view returns (uint) {
        if (totalSupply <= 0 || block.timestamp <= lastUpdate) {
            return tps;
        }
        uint latest = lastTimeRewardApplicable();
        return tps + (((latest - lastUpdate) * rate * 1e18) / totalSupply);
    }
    function earned(address account) public view returns (uint) {
        uint perToken = tokensPerShare() - tpsPaid[account];
        return ((balanceOf[account] * perToken) / 1e18) + rewards[account];
    }
    function redeemable(address account) public view returns (uint) {
        return balanceOf[account] + earned(account);
    }
    function getRewardForDuration() external view returns (uint) {
        return rate * spread;
    }
    function getAPR() external view returns (uint) {
        if(spread == 0 || totalSupply == 0) {
            return 0;
        }
        return ((rate * 31536000 * 1e18) / totalSupply) * 100;
    }

    // --- Administration ---
    function initialize(address _hayToken, uint _spread, uint _exitDelay) public auth {
        require(spread == 0);
        HAY = _hayToken;
        spread = _spread;
        exitDelay = _exitDelay;
        emit Initialized(HAY, spread, exitDelay);
    }
    
    // Can be called by anybody. In order to fill the contract with additional funds
    function replenish(uint wad) external update(address(0)) {
        if (block.timestamp >= endTime) {
            rate = wad / spread;
        } else {
            uint remaining = endTime - block.timestamp;
            uint leftover = remaining * rate;
            rate = (wad + leftover) / spread;
        }
        lastUpdate = block.timestamp;
        endTime = block.timestamp + spread;

        IERC20Upgradeable(HAY).safeTransferFrom(msg.sender, address(this), wad);
        emit Replenished(wad);
    }
    function setSpread(uint _spread) external auth {
        require(block.timestamp > endTime, "Jar/rewards-active");
        require(_spread > 0, "Jar/duration-non-zero");
        spread = _spread;
        emit SpreadUpdated(_spread);
    }
    function setExitDelay(uint _exitDelay) external auth {
        exitDelay = _exitDelay;
        emit ExitDelayUpdated(_exitDelay);
    }
    function cage() external auth {
        live = 0;
        emit Cage();
    }

    // --- User ---
    function join(uint256 wad) external update(msg.sender) {
        require(live == 1, "Jar/not-live");

        balanceOf[msg.sender] += wad;
        totalSupply += wad;

        IERC20Upgradeable(HAY).safeTransferFrom(msg.sender, address(this), wad);
        emit Join(msg.sender, wad);
    }
    function exit(uint256 wad) external update(msg.sender) {
        require(live == 1, "Jar/not-live");
        require(wad > 0);

        balanceOf[msg.sender] -= wad;        
        totalSupply -= wad;
        withdrawn[msg.sender] += wad;
        unstakeTime[msg.sender] = block.timestamp + exitDelay;

        emit Exit(msg.sender, wad);
    }
    function redeemBatch(address[] memory accounts) external {
        // Target is to allow direct and on-behalf redemption
        require(live == 1, "Jar/not-live");

        for (uint i = 0; i < accounts.length; i++) {
            if (block.timestamp < unstakeTime[accounts[i]] && unstakeTime[accounts[i]] != 0)
                continue;
            
            uint _amount = rewards[accounts[i]] + withdrawn[accounts[i]];
            if (_amount > 0) {
                rewards[accounts[i]] = 0;
                withdrawn[accounts[i]] = 0;
                IERC20Upgradeable(HAY).safeTransfer(accounts[i], _amount);
            }
        }
       
        emit Redeem(accounts);
    }
}
