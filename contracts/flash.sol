// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2021 Dai Foundation
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
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/HayJoinLike.sol";
import "./interfaces/VatLike.sol";
import "./interfaces/HayLike.sol";
import "./interfaces/IERC3156FlashLender.sol";
import "./interfaces/IERC3156FlashBorrower.sol";

contract Flash is Initializable, ReentrancyGuardUpgradeable, IERC3156FlashLender {
    using SafeERC20 for HayLike;
    // --- Auth ---
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    mapping (address => uint256) public wards;
    modifier auth { require(wards[msg.sender] == 1, "Flash/not-authorized"); _; }

    // --- Data ---
    VatLike     public vat;
    HayJoinLike public hayJoin;
    HayLike     public hay;
    address     public vow;

    uint256     public  max;     // Maximum borrowable Hay  [wad]
    uint256     public  toll;    // Fee to be returned      [wad = 100%]

    uint256 private constant WAD = 10 ** 18;
    uint256 private constant RAY = 10 ** 27;
    uint256 private constant RAD = 10 ** 45;

    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event FlashLoan(address indexed receiver, address token, uint256 amount, uint256 fee);

    // --- Init ---
    function initialize(address _vat, address _hay, address _hayJoin, address _vow) external initializer {
        wards[msg.sender] = 1;
        vat = VatLike(_vat);
        hayJoin = HayJoinLike(_hayJoin);
        hay = HayLike(_hay);
        vow = _vow;

        vat.hope(_hayJoin);
        hay.approve(_hayJoin, type(uint256).max);
        emit Rely(msg.sender);
    }

    // --- Administration ---
    function file(bytes32 what, uint256 data) external auth {
        if (what == "max") {
            // Add an upper limit of 10^27 HAY to avoid breaking technical assumptions of HAY << 2^256 - 1
            require((max = data) <= RAD, "Flash/ceiling-too-high");
        } else if (what == "toll") toll = data;
        else revert("Flash/file-unrecognized-param");
        emit File(what, data);
    }

    // --- ERC 3156 Spec ---
    function maxFlashLoan(address token) external override view returns (uint256) {
        if (token == address(hay)) {
            return max;
        } else {
            return 0;
        }
    }

    function flashFee(address token, uint256 amount) external override view returns (uint256) {
        require(token == address(hay), "Flash/token-unsupported");
        return (amount * toll) / WAD;
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external override nonReentrant returns (bool) {
        require(token == address(hay), "Flash/token-unsupported");
        require(amount <= max, "Flash/ceiling-exceeded");
        require(vat.live() == 1, "Flash/vat-not-live");

        uint256 amt = amount * RAY;
        uint256 fee = (amount * toll) / WAD;
        uint256 total = amount + fee;

        vat.suck(address(this), address(this), amt);
        hayJoin.exit(address(receiver), amount);

        emit FlashLoan(address(receiver), token, amount, fee);

        require(receiver.onFlashLoan(msg.sender, token, amount, fee, data) == CALLBACK_SUCCESS, "Flash/callback-failed");

        hay.safeTransferFrom(address(receiver), address(this), total);
        hayJoin.join(address(this), total);
        vat.heal(amt);

        return true;
    }

    function accrue() external nonReentrant {
        vat.move(address(this), vow, vat.hay(address(this)));
    }
}