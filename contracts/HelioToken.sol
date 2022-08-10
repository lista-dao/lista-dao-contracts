// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract HelioToken is ERC20, ERC20Pausable {

    event MintedRewardsSupply(address rewardsContract, uint256 amount);

    address public rewards;

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth {
        require(usr != address(0), "HelioToken/invalid-address");
        wards[usr] = 1;
    }
    function deny(address usr) external auth {
        require(usr != address(0), "HelioToken/invalid-address");
        wards[usr] = 0;
    }
    modifier auth {
        require(wards[msg.sender] == 1, "HelioToken/not-authorized");
        _;
    }

    constructor(uint256 rewardsSupply_, address rewards_) ERC20("Helio Reward token", "HELIO"){
        wards[msg.sender] = 1;
        rewards = rewards_;
        _mint(rewards, rewardsSupply_);

        emit MintedRewardsSupply(rewards, rewardsSupply_);
    }

    function mint(address _to, uint256 _amount) external auth returns(bool) {
        require(_to != rewards, "HelioToken/rewards-oversupply");
        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) external returns(bool) {
        _burn(msg.sender, _amount);
        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
