// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import {TimeLock} from "../../contracts/upgrade/TimeLock.sol";

contract TimeLockTest is Test {
    TimeLock timeLock;

    address proposer = makeAddr("proposer");
    address executor = makeAddr("executor");
    uint256 minDelay = 100;

    function setUp() public {
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = executor;
        timeLock = new TimeLock(minDelay, proposers, executors, address(0)); // don't set admin

        assertEq(timeLock.hasRole(timeLock.PROPOSER_ROLE(), proposer), true);
        assertEq(timeLock.hasRole(timeLock.EXECUTOR_ROLE(), executor), true);
        assertEq(
            timeLock.hasRole(timeLock.TIMELOCK_ADMIN_ROLE(), address(timeLock)),
            true
        );

        // Only TIMELOCK_ADMIN_ROLE can grant roles
        assertEq(timeLock.getRoleAdmin(timeLock.PROPOSER_ROLE()), timeLock.TIMELOCK_ADMIN_ROLE());
        assertEq(timeLock.getRoleAdmin(timeLock.EXECUTOR_ROLE()), timeLock.TIMELOCK_ADMIN_ROLE());
    }

    function test_updateDelay() public {
        uint256 newDelay = 200;

        bytes memory data = abi.encodeWithSignature(
            "updateDelay(uint256)",
            newDelay
        );

        address target = address(timeLock);
        uint256 value = 0;
        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);
        uint256 _delay = 100;

        vm.startPrank(proposer);
        timeLock.schedule(target, value, data, predecessor, salt, _delay);
        vm.stopPrank();

        bytes32 id = timeLock.hashOperation(
            target,
            value,
            data,
            predecessor,
            salt
        );

        assertEq(timeLock.isOperationPending(id), true); // operation is pending

        skip(100);

        vm.startPrank(executor);
        timeLock.execute(target, value, data, predecessor, salt);
        vm.stopPrank();

        assertEq(timeLock.isOperationDone(id), true); // operation is executed
    }

    function test_grantRole() public {
        address newProposer = makeAddr("newProposer");

        bytes memory data = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            timeLock.PROPOSER_ROLE(),
            newProposer
        );

        address target = address(timeLock);
        uint256 value = 0;
        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);
        uint256 _delay = 100;

        vm.startPrank(proposer);
        timeLock.schedule(target, value, data, predecessor, salt, _delay);
        vm.stopPrank();

        bytes32 id = timeLock.hashOperation(
            target,
            value,
            data,
            predecessor,
            salt
        );

        assertEq(timeLock.isOperationPending(id), true); // operation is pending

        skip(100);

        vm.startPrank(executor);
        timeLock.execute(target, value, data, predecessor, salt);
        vm.stopPrank();

        assertEq(timeLock.isOperationDone(id), true); // operation is executed
        assertEq(timeLock.hasRole(timeLock.PROPOSER_ROLE(), newProposer), true);
    }
}
