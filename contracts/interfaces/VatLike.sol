// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface VatLike {
    function init(bytes32 ilk) external;

    function hope(address usr) external;

    function rely(address usr) external;

    function move(address src, address dst, uint256 rad) external;

    function behalf(address bit, address usr) external;

    function frob(bytes32 i, address u, address v, address w, int dink, int dart) external;

    function flux(bytes32 ilk, address src, address dst, uint256 wad) external;

    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);

    function gem(bytes32, address) external view returns (uint256);

    function usb(address) external view returns (uint256);

    function urns(bytes32, address) external view returns (uint256, uint256);

    function file(bytes32, bytes32, uint) external;
}