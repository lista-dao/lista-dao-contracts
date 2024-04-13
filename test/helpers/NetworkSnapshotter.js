"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NetworkSnapshotter = void 0;
const hardhat_1 = require("hardhat");
class NetworkSnapshotter {
    snapshotId;
    snapshotIds;
    constructor() {
        this.snapshotId = 0;
        this.snapshotIds = [];
    }
    async revert() {
        await hardhat_1.network.provider.send("evm_revert", [this.snapshotId]);
        return this.firstSnapshot();
    }
    async firstSnapshot() {
        this.snapshotId = await hardhat_1.network.provider.send("evm_snapshot", []);
    }
    async newSnapshot() {
        if (this.snapshotId)
            this.snapshotIds.push(this.snapshotId);
        this.snapshotId = await hardhat_1.network.provider.send("evm_snapshot", []);
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
exports.NetworkSnapshotter = NetworkSnapshotter;
module.exports = NetworkSnapshotter;
