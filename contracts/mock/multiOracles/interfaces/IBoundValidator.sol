interface BoundValidatorInterfaceTestnet {
  function validatePriceWithAnchorPrice(
    address asset,
    int256 reporterPrice,
    int256 anchorPrice
  ) external view returns (bool);
}
