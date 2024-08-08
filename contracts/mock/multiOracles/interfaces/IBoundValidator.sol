pragma solidity ^0.8.10;
interface BoundValidatorInterfaceTestnet {
  function validatePriceWithAnchorPrice(
    address asset,
    int256 reporterPrice,
    int256 anchorPrice
  ) external view returns (bool);
}
