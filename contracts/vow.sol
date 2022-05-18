// SPDX-License-Identifier: AGPL-3.0-or-later

/// vow.sol -- Hay settlement module

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
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
import "./interfaces/VatLike.sol";
import "./interfaces/HayJoinLike.sol";

contract Vow is Initializable {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth { require(live == 1, "Vow/not-live"); wards[usr] = 1; }
    function deny(address usr) external auth { wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "Vow/not-authorized");
        _;
    }

    // --- Data ---
    VatLike public vat;          // CDP Engine
    address public multisig;     // Surplus multisig

    mapping (uint256 => uint256) public sin;  // debt queue
    uint256 public Sin;   // Queued debt            [rad]
    uint256 public Ash;   // On-auction debt        [rad]

    uint256 public wait;  // Flop delay             [seconds]
    uint256 public dump;  // Flop initial lot size  [wad]
    uint256 public sump;  // Flop fixed bid size    [rad]

    address public hayJoin; // Stablecoin address
    uint256 public hump;    // Surplus buffer      [rad]

    uint256 public live;  // Active Flag

    address public hay;  // Hay token
    
    using SafeERC20Upgradeable for IERC20Upgradeable;
    // --- Init ---
    function initialize(address vat_, address _hayJoin, address multisig_) external initializer {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        hayJoin = _hayJoin;
        multisig = multisig_;
        vat.hope(hayJoin);
        live = 1;
    }

    // --- Math ---
    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }

    // --- Administration ---
    function file(bytes32 what, uint data) external auth {
        if (what == "hump") hump = data;
        else revert("Vow/file-unrecognized-param");
    }
    function file(bytes32 what, address data) external auth {
        if (what == "multisig") multisig = data;
        else if (what == "hayjoin") { 
            vat.nope(hayJoin);
            hayJoin = data;
            vat.hope(hayJoin);
        }
        else if (what == "hay") hay = data;
        else if (what == "vat") vat = VatLike(data);
        else revert("Vow/file-unrecognized-param");
    }

    // Debt settlement
    function heal(uint rad) external {
        require(rad <= vat.hay(address(this)), "Vow/insufficient-surplus");
        require(rad <= vat.sin(address(this)), "Vow/insufficient-debt");
        vat.heal(rad);
    }

    // Feed stablecoin to vow
    function feed(uint wad) external {
        IERC20Upgradeable(hay).safeTransferFrom(msg.sender, address(this), wad);
        IERC20Upgradeable(hay).safeApprove(hayJoin, wad);
        HayJoinLike(hayJoin).join(address(this), wad);
    }
    // Send surplus to multisig
    function flap() external {
        require(vat.hay(address(this)) >= vat.sin(address(this)) + hump, "Vow/insufficient-surplus");
        uint rad = vat.hay(address(this)) - (vat.sin(address(this)) + hump);
        uint wad = rad / 1e27;
        HayJoinLike(hayJoin).exit(multisig, wad);
    }

    function cage() external auth {
        live = 0;
        Sin = 0;
        Ash = 0;
        vat.heal(min(vat.hay(address(this)), vat.sin(address(this))));
    }

    function uncage() external auth {
        live = 1;
    }
}