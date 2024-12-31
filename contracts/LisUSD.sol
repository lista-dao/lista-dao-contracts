// SPDX-License-Identifier: AGPL-3.0-or-later

/// LisUSD.sol -- Lista Stablecoin ERC-20 Token

// Copyright (C) 2017, 2018, 2019 dbrock, rain, mrchico

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
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

// FIXME: This contract was altered compared to the production version.
// It doesn't use LibNote anymore.
// New deployments of this contract will need to include custom events (TO DO).

contract LisUSD is Initializable, IERC20MetadataUpgradeable {
    enum Role {
        NONE, // 0
        MINTER, // 1
        MANAGER, // 2
        ADMIN // 3
    }

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address guy, uint role) external onlyAdmin {
        require(role > 0 && role <= uint(type(Role).max), "LisUSD/invalid-role");
        wards[guy] = role;
    }
    function deny(address guy) external onlyAdmin { wards[guy] = 0; }

    modifier onlyMinter() {
        require(wards[msg.sender] == uint(Role.MINTER), "LisUSD/not-authorized-minter");
        _;
    }

    modifier onlyManager() {
        require(wards[msg.sender] == uint(Role.MANAGER), "LisUSD/not-authorized-manager");
        _;
    }

    modifier onlyAdmin() {
        require(wards[msg.sender] == uint(Role.ADMIN) || msg.sender == DEFAULT_ADMIN, "LisUSD/not-authorized-admin");
        _;
    }

    // --- ERC20 Data ---
    string  public constant name     = "Lista USD";
    string  public symbol;
    string  public constant version  = "1";
    uint8   public constant decimals = 18;
    uint256 public totalSupply;

    mapping (address => uint)                      public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;
    mapping (address => uint)                      public nonces;

    uint256 public supplyCap;

    event SupplyCapSet(uint256 oldCap, uint256 newCap);

    // --- EIP712 niceties ---
    bytes32 public DOMAIN_SEPARATOR;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
    bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

    // default admin is TimeLock contract
    address public constant DEFAULT_ADMIN = 0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253;

    function initialize(uint256 chainId_, string memory symbol_, uint256 supplyCap_) external initializer {
        wards[msg.sender] = 1;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            chainId_,
            address(this)
        ));
        symbol = symbol_;
        supplyCap = supplyCap_;
    }

    // --- Token ---
    function transfer(address dst, uint wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }
    function transferFrom(address src, address dst, uint wad) public returns (bool) {
        require(src != address(0), "LisUSD/transfer-from-zero-address");
        require(dst != address(0), "LisUSD/transfer-to-zero-address");
        require(balanceOf[src] >= wad, "LisUSD/insufficient-balance");
        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad, "LisUSD/insufficient-allowance");
            allowance[src][msg.sender] -= wad;
        }
        balanceOf[src] -= wad;
        balanceOf[dst] += wad;
        emit Transfer(src, dst, wad);
        return true;
    }
    function mint(address usr, uint wad) external onlyMinter {
        require(usr != address(0), "LisUSD/mint-to-zero-address");
        require(totalSupply + wad <= supplyCap, "LisUSD/cap-reached");
        balanceOf[usr] += wad;
        totalSupply    += wad;
        emit Transfer(address(0), usr, wad);
    }
    function burn(address usr, uint wad) external {
        require(usr != address(0), "LisUSD/burn-from-zero-address");
        require(balanceOf[usr] >= wad, "LisUSD/insufficient-balance");
        if (usr != msg.sender && allowance[usr][msg.sender] != type(uint256).max) {
            require(allowance[usr][msg.sender] >= wad, "LisUSD/insufficient-allowance");
            allowance[usr][msg.sender] -= wad;
        }
        balanceOf[usr] -= wad;
        totalSupply    -= wad;
        emit Transfer(usr, address(0), wad);
    }
    function approve(address usr, uint wad) external returns (bool) {
        _approve(msg.sender, usr, wad);

        emit Approval(msg.sender, usr, wad);
        return true;
    }

    // --- Alias ---
    function push(address usr, uint wad) external {
        transferFrom(msg.sender, usr, wad);
    }
    function pull(address usr, uint wad) external {
        transferFrom(usr, msg.sender, wad);
    }
    function move(address src, address dst, uint wad) external {
        transferFrom(src, dst, wad);
    }

    // --- Approve by signature ---
    function permit(address holder, address spender, uint256 nonce, uint256 expiry,
                    bool allowed, uint8 v, bytes32 r, bytes32 s) external
    {
        bytes32 digest =
            keccak256(abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH,
                                     holder,
                                     spender,
                                     nonce,
                                     expiry,
                                     allowed))
        ));

        require(holder != address(0), "LisUSD/invalid-address-0");
        require(holder == ecrecover(digest, v, r, s), "LisUSD/invalid-permit");
        require(expiry == 0 || block.timestamp <= expiry, "LisUSD/permit-expired");
        require(nonce == nonces[holder]++, "LisUSD/invalid-nonce");
        uint wad = allowed ? type(uint256).max : 0;
        allowance[holder][spender] = wad;
        emit Approval(holder, spender, wad);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "LisUSD/approve-from-zero-address");
        require(spender != address(0), "LisUSD/approve-to-zero-address");

        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance[owner][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance[owner][spender];
        require(currentAllowance >= subtractedValue, "LisUSD/decreased-allowance-below-zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function setSupplyCap(uint256 wad) public onlyManager {
        require(wad >= totalSupply, "LisUSD/more-supply-than-cap");
        uint256 oldCap = supplyCap;
        supplyCap = wad;
        emit SupplyCapSet(oldCap, supplyCap);
    }

    function updateDomainSeparator(uint256 chainId_) external onlyManager {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            chainId_,
            address(this)
        ));
    }
}
