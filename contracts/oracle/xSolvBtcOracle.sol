// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";
import "./interfaces/OracleInterface.sol";

contract xSolvBTCOracle is Initializable {

  address public constant X_SOLV_BTC_TOKEN_ADDR = 0x1346b618dC92810EC74163e4c27004c921D446a5;

  IResilientOracle public resilientOracle; // deprecated
  address public immutable xSolvBtcPriceFeed;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor(address _xSolvBtcPriceFeed) {
    require(_xSolvBtcPriceFeed != address(0), "Zero address provided");
    xSolvBtcPriceFeed = _xSolvBtcPriceFeed;
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
      int256 xSolBtcPrice,
    /*uint startedAt*/,
    /*uint256 updatedAt*/,
    /*uint80 answeredInRound*/
    ) = AggregatorV3Interface(xSolvBtcPriceFeed).latestRoundData();

    return (bytes32(uint256(xSolBtcPrice * 1e10)), true);
  }
}
