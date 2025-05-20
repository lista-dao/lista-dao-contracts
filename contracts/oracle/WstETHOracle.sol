// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";
import "./interfaces/OracleInterface.sol";

contract WstETHOracle is Initializable {

  IResilientOracle public resilientOracle;
  address constant ETH_TOKEN_ADDR = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
  address constant WSTETH_TOKEN_ADDR = 0x26c5e01524d2E6280A48F2c50fF6De7e52E9611C;
  address public immutable wstETHPriceFeed;

  constructor(address _wstETHPriceFeed) {
    require(_wstETHPriceFeed != address(0), "Zero address provided");
    wstETHPriceFeed = _wstETHPriceFeed;
    _disableInitializers();
  }

  function initialize(address _resilientOracle) external initializer {
    resilientOracle = IResilientOracle(_resilientOracle);
  }

  /**
    * Returns the latest price
    */
  function peek() public view returns (bytes32, bool) {
    (
    /*uint80 roundID*/,
      int256 wstETHPrice,
    /*uint startedAt*/,
    /*uint256 updatedAt*/,
    /*uint80 answeredInRound*/
    ) = AggregatorV3Interface(wstETHPriceFeed).latestRoundData();

    return (bytes32(uint256(wstETHPrice * 1e10)), true);
  }
}
