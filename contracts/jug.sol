// SPDX-License-Identifier: AGPL-3.0-or-later

/// jug.sol -- Hay Lending Rate

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

// FIXME: This contract was altered compared to the production version.
// It doesn't use LibNote anymore.
// New deployments of this contract will need to include custom events (TO DO).

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./hMath.sol";
import "./interfaces/JugLike.sol";
import "./interfaces/VatLike.sol";

contract Jug is JugLike, Initializable {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth { wards[usr] = 1; }
    function deny(address usr) external auth { wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "Jug/not-authorized");
        _;
    }

    // --- Data ---
    struct Ilk {
        uint256 duty;  // Collateral-specific, per-second stability fee contribution [ray]
        uint256  rho;  // Time of last drip [unix epoch time]
    }

    mapping (bytes32 => Ilk) public ilks;
    VatLike                  public vat;   // CDP Engine
    address                  public vow;   // Debt Engine
    uint256                  public base;  // Global, per-second stability fee contribution [ray]

    // --- Init ---
    function initialize(address vat_) external initializer {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
    }

    // --- Math ---
    function _add(uint x, uint y) internal pure returns (uint z) {
        unchecked {
            z = x + y;
            require(z >= x);
        }
    }
    function _diff(uint x, uint y) internal pure returns (int z) {
        unchecked {
            z = int(x) - int(y);
            require(int(x) >= 0 && int(y) >= 0);
        }
    }
    function _rmul(uint x, uint y) internal pure returns (uint z) {
        unchecked {
            z = x * y;
            require(y == 0 || z / y == x);
            z = z / hMath.ONE;
        }
    }

    // --- Administration ---
    function init(bytes32 ilk) external auth {
        Ilk storage i = ilks[ilk];
        require(i.duty == 0, "Jug/ilk-already-init");
        i.duty = hMath.ONE;
        i.rho  = block.timestamp;
    }
    function file(bytes32 ilk, bytes32 what, uint data) external auth {
        require(block.timestamp == ilks[ilk].rho, "Jug/rho-not-updated");
        if (what == "duty") ilks[ilk].duty = data;
        else revert("Jug/file-unrecognized-param");
    }
    function file(bytes32 what, uint data) external auth {
        if (what == "base") base = data;
        else revert("Jug/file-unrecognized-param");
    }
    function file(bytes32 what, address data) external auth {
        if (what == "vow") vow = data;
        else revert("Jug/file-unrecognized-param");
    }

    // --- Stability Fee Collection ---
    function drip(bytes32 ilk) external returns (uint rate) {
        require(block.timestamp >= ilks[ilk].rho, "Jug/invalid-now");
        (, uint prev,,,) = vat.ilks(ilk);
        rate = _rmul(hMath.rpow(_add(base, ilks[ilk].duty), block.timestamp - ilks[ilk].rho, hMath.ONE), prev);
        vat.fold(ilk, vow, _diff(rate, prev));
        ilks[ilk].rho = block.timestamp;
    }
}
