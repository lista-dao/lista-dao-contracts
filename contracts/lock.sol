// SPDX-License-Identifier: AGPL-3.0-or-later

/// lock.sol -- center for all cages

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

interface CageLike {
    function cage() external;
    function uncage() external;
}
interface HelioTokenLike {
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
}

contract Lock is Initializable{
    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    modifier auth {
        require(wards[msg.sender] == 1, "Lock/not-authorized");
        _;
    }

    // --- Data ---
    CageLike public vat;
    CageLike public dog;
    CageLike public vow;
    CageLike public spot;
    CageLike public hayJoin;
    HelioTokenLike public helioToken;
    CageLike public jar;

    uint256  public live;  // Active Flag

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Cage();
    event Uncage();

    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);

    // --- Init ---
    function initialize() external initializer {
        wards[msg.sender] = 1;
        live = 1;
    }

    // --- Administration ---
    function file(bytes32 what, address data) external auth {
        require(live == 1, "Lock/not-live");
        if (what == "vat")  vat = CageLike(data);
        else if (what == "dog")   dog = CageLike(data);
        else if (what == "vow")   vow = CageLike(data);
        else if (what == "spot") spot = CageLike(data);
        else if (what == "hayJoin") hayJoin = CageLike(data);
        else if (what == "helioToken") helioToken = HelioTokenLike(data);
        else if (what == "jar") jar = CageLike(data);
        else revert("Lock/file-unrecognized-param");
        emit File(what, data);
    }

    // --- Locking ---
    function lockDown() external auth {
        require(live == 1, "Lock/not-live");
        live = 0;
        vat.cage();
        dog.cage();
        vow.cage();
        spot.cage();
        hayJoin.cage();
        if(helioToken.paused() != true) helioToken.pause();
        jar.cage();
    }
    function lock(bytes32 what) external auth {
        require(live == 1, "Lock/not-live");
        if (what == "vat")  vat.cage();
        else if (what == "dog")   dog.cage();
        else if (what == "vow")   vow.cage();
        else if (what == "spot") spot.cage();
        else if (what == "hayJoin") hayJoin.cage();
        else if (what == "helioToken") { if(helioToken.paused() != true) helioToken.pause(); }
        else if (what == "jar") jar.cage();
        else revert("Lock/file-unrecognized-param");
    }
    function lockExternals() external auth {
        require(live == 1, "Lock/not-live");
        if(helioToken.paused() != true) helioToken.pause();
        jar.cage();
    }
    function lockCore() external auth {
        require(live == 1, "Lock/not-live");
        vat.cage();
        dog.cage();
        vow.cage();
        spot.cage();
        hayJoin.cage();
    }

    // --- Unlocking ---
    function unlockAll() external auth {
        require(live == 1, "Lock/not-live");
        vat.uncage();
        dog.uncage();
        vow.uncage();
        spot.uncage();
        hayJoin.uncage();
        if(helioToken.paused() == true) helioToken.unpause();
        jar.uncage();
    }
    function unlock(bytes32 what) external auth {
        require(live == 1, "Lock/not-live");
        if (what == "vat")  vat.uncage();
        else if (what == "dog")   dog.uncage();
        else if (what == "vow")   vow.uncage();
        else if (what == "spot") spot.uncage();
        else if (what == "hayJoin") hayJoin.uncage();
        else if (what == "helioToken") if(helioToken.paused() == true) helioToken.unpause();
        else if (what == "jar") jar.uncage();
        else revert("Lock/file-unrecognized-param");
    }
    function unlockExternals() external auth {
        require(live == 1, "Lock/not-live");
        if(helioToken.paused() == true) helioToken.unpause();
        jar.uncage();
    }
    function unlockCore() external auth {
        require(live == 1, "Lock/not-live");
        vat.uncage();
        dog.uncage();
        vow.uncage();
        spot.uncage();
        hayJoin.uncage();
    }

    function cage() external auth {
        live = 0;
        emit Cage();
    }
    function uncage() external auth {
        live = 1;
        emit Uncage();
    }
}