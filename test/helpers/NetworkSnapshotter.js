const { network } = require("hardhat");

class NetworkSnapshotter {
  constructor() {
    this.snapshotId = 0;
  }

  async revert() {
    await network.provider.send("evm_revert", [this.snapshotId]);
    return this.snapshot();
  }

  async snapshot() {
    this.snapshotId = await network.provider.send("evm_snapshot", []);
  }
}

module.exports = NetworkSnapshotter;
