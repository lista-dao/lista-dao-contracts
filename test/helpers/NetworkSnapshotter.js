const { network } = require("hardhat");

class NetworkSnapshotter {
  snapshotId;
  snapshotIds;

  constructor() {
    this.snapshotId = 0;
    this.snapshotIds = [];
  }

  async revert() {
    await network.provider.send("evm_revert", [this.snapshotId]);
    return this.firstSnapshot();
  }

  async firstSnapshot() {
    this.snapshotId = await network.provider.send("evm_snapshot", []);
  }

  async newSnapshot() {
    this.snapshotIds.push(this.snapshotId);
    this.snapshotId = await network.provider.send("evm_snapshot", []);
  }

  async revertLastSnapshot() {
    if (this.snapshotIds.length === 0) {
      throw new Error("there is no registered snapshot");
    }
    const snapId = this.snapshotIds.pop();
    this.snapshotId = snapId;
    return this.revert();
  }
}

module.exports = NetworkSnapshotter;
