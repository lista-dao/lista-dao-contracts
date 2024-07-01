// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IAPI3Proxy {
  function read()
  external
  view
  returns (int224 value, uint32 timestamp);
}
