// SPDX-License-Identifier: AGPL-3.0-or-later

/// join-5.sol -- Non-standard token adapters

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
// Copyright (C) 2018-2020 Maker Ecosystem Growth Holdings, INC.
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

import { VatLike } from "./join.sol";
import { GemJoinLike } from "./interfaces/GemJoinLike.sol";
import { GemLike } from "./interfaces/GemLike.sol";

// For a token that has a lower precision than 18 and it has decimals (like USDC)
// 2024-12-17 Taken from https://github.com/makerdao/dss-gem-joins/blob/master/src/join-5.sol

contract GemJoin5 is GemJoinLike, Initializable {
    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }
    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }
    modifier auth { require(wards[msg.sender] == 1); _; }

    VatLike public vat;
    bytes32 public ilk;
    GemLike public gem;
    uint256 public dec;
    uint256 public live;  // Active Flag

    // Events
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Join(address indexed usr, uint256 wad);
    event Exit(address indexed usr, uint256 wad);
    event Cage();
    event Uncage();

    function initialize(address vat_, bytes32 ilk_, address gem_) external initializer {
        gem = GemLike(gem_);
        dec = gem.decimals();
        require(dec < 18, "GemJoin5/decimals-18-or-higher");
        wards[msg.sender] = 1;
        live = 1;
        vat = VatLike(vat_);
        ilk = ilk_;
        emit Rely(msg.sender);
    }

    function cage() external auth {
        live = 0;
        emit Cage();
    }

    function uncage() external auth {
        live = 1;
        emit Uncage();
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "GemJoin5/overflow");
    }

    function join(address usr, uint256 amt) external {
        require(live == 1, "GemJoin5/not-live");
        uint256 wad = mul(amt, 10 ** (18 - dec));
        require(int256(wad) >= 0, "GemJoin5/overflow");
        vat.slip(ilk, usr, int256(wad));
        require(gem.transferFrom(msg.sender, address(this), amt), "GemJoin5/failed-transfer");
        emit Join(usr, amt);
    }

    function exit(address usr, uint256 amt) external {
        uint256 wad = mul(amt, 10 ** (18 - dec));
        require(int256(wad) >= 0, "GemJoin5/overflow");
        vat.slip(ilk, msg.sender, -int256(wad));
        require(gem.transfer(usr, amt), "GemJoin5/failed-transfer");
        emit Exit(usr, amt);
    }
}