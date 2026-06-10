// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vesting} from "../src/Vesting.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract VestingTest is Test {
    Vesting public vesting;
    MockERC20 public token;

    address public beneficiary = makeAddr("beneficiary");
    address public deployer = makeAddr("deployer");
    uint256 public constant TOTAL_AMOUNT = 1_000_000 * 1e18; // 1 million tokens

    /// @notice Deploy vesting contract and mint tokens to it
    function setUp() public {
        vm.prank(deployer);
        token = new MockERC20("Test Token", "TST");

        vm.prank(deployer);
        vesting = new Vesting(beneficiary, address(token), TOTAL_AMOUNT);

        // Mint 1 million tokens to the vesting contract
        token.mint(address(vesting), TOTAL_AMOUNT);
    }

    /// @notice Test initial state after deployment
    function test_InitialState() public view {
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.totalAmount(), TOTAL_AMOUNT);
        assertEq(vesting.released(), 0);
        assertEq(vesting.vestedAmount(), 0);
        assertEq(vesting.releasable(), 0);
        assertEq(token.balanceOf(address(vesting)), TOTAL_AMOUNT);
    }

    /// @notice During cliff (months 1-12), nothing should be releasable
    function test_NoReleaseDuringCliff() public {
        // Warp 6 months into the future
        vm.warp(block.timestamp + 180 days);
        assertEq(vesting.vestedAmount(), 0);
        assertEq(vesting.releasable(), 0);

        // Warp to just before cliff ends (11 months 29 days)
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() - 1 days);
        assertEq(vesting.vestedAmount(), 0);
        assertEq(vesting.releasable(), 0);
    }

    /// @notice At the exact end of cliff, vesting just starts (month 13 begins)
    function test_VestingStartsAfterCliff() public {
        // Warp to exactly the end of cliff
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() + 1);
        // After 1 second into vesting period, tiny amount vested
        uint256 vested = vesting.vestedAmount();
        assertGt(vested, 0);
        assertLt(vested, TOTAL_AMOUNT / 24);
    }

    /// @notice After 1 month into vesting (month 13), ~1/24 should be vested
    function test_OneMonthAfterCliff() public {
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() + 30 days);
        uint256 vested = vesting.vestedAmount();
        uint256 expected = (TOTAL_AMOUNT * 30 days) / vesting.VESTING_DURATION();
        assertApproxEqAbs(vested, expected, 1);
    }

    /// @notice After 12 months into vesting (month 24), ~12/24 = 50% should be vested
    function test_HalfVested() public {
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() + 365 days);
        uint256 vested = vesting.vestedAmount();
        uint256 expected = TOTAL_AMOUNT / 2;
        // Allow small rounding difference
        assertApproxEqAbs(vested, expected, 1e18);
    }

    /// @notice After full vesting period, 100% should be vested
    function test_FullyVested() public {
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() + vesting.VESTING_DURATION());
        assertEq(vesting.vestedAmount(), TOTAL_AMOUNT);
        assertEq(vesting.releasable(), TOTAL_AMOUNT);
    }

    /// @notice Beyond full vesting, still 100% vested (no extra)
    function test_BeyondFullVesting() public {
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() + vesting.VESTING_DURATION() + 1000 days);
        assertEq(vesting.vestedAmount(), TOTAL_AMOUNT);
    }

    /// @notice Release tokens to beneficiary
    function test_Release() public {
        // Warp to 50% vested (after cliff + 365 days of vesting)
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() + 365 days);

        uint256 releasableBefore = vesting.releasable();
        assertGt(releasableBefore, 0);

        uint256 beneficiaryBalanceBefore = token.balanceOf(beneficiary);

        vesting.release();

        assertEq(token.balanceOf(beneficiary), beneficiaryBalanceBefore + releasableBefore);
        assertEq(vesting.released(), releasableBefore);
        assertEq(vesting.releasable(), 0);
    }

    /// @notice Release reverts when nothing to release
    function test_ReleaseRevertsWhenNothingToRelease() public {
        // Still in cliff period
        vm.expectRevert("Nothing to release");
        vesting.release();
    }

    /// @notice Multiple releases over time
    function test_MultipleReleases() public {
        // After cliff + 1 month, release first batch
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() + 30 days);
        vesting.release();
        uint256 firstRelease = vesting.released();
        assertGt(firstRelease, 0);

        // After cliff + 6 months, release second batch
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() + 180 days);
        uint256 releasableBefore = vesting.releasable();
        vesting.release();
        uint256 secondRelease = vesting.released();
        assertEq(secondRelease - firstRelease, releasableBefore);

        // After cliff + 24 months (fully vested), release remaining
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() + vesting.VESTING_DURATION());
        vesting.release();
        assertEq(vesting.released(), TOTAL_AMOUNT);
        assertEq(token.balanceOf(beneficiary), TOTAL_AMOUNT);
    }

    /// @notice Anyone can call release (not just beneficiary)
    function test_AnyoneCanRelease() public {
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() + vesting.VESTING_DURATION());

        address randomCaller = makeAddr("random");
        vm.prank(randomCaller);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), TOTAL_AMOUNT);
    }

    /// @notice Simulate month-by-month vesting: each month ~1/24 of total unlocks
    function test_MonthByMonthSimulation() public {
        // cliffEnd = start + 12 months, vestingEnd = cliffEnd + 24 months
        uint256 cliffEnd = vesting.start() + vesting.CLIFF_DURATION();

        // After cliff + 1 month: ~1/24 vested (30 days ≈ 4.11%, 1/24 ≈ 4.17%)
        vm.warp(cliffEnd + 30 days);
        uint256 month1Vested = vesting.vestedAmount();
        assertApproxEqRel(month1Vested, TOTAL_AMOUNT / 24, 0.02e18); // 2% tolerance

        // After cliff + 2 months: ~2/24 vested
        vm.warp(cliffEnd + 60 days);
        uint256 month2Vested = vesting.vestedAmount();
        assertApproxEqRel(month2Vested, TOTAL_AMOUNT * 2 / 24, 0.02e18);

        // After cliff + 6 months: ~6/24 = 25% vested
        vm.warp(cliffEnd + 180 days);
        uint256 month6Vested = vesting.vestedAmount();
        assertApproxEqRel(month6Vested, TOTAL_AMOUNT / 4, 0.02e18);

        // After cliff + 12 months: ~12/24 = 50% vested
        vm.warp(cliffEnd + 365 days);
        uint256 month12Vested = vesting.vestedAmount();
        assertApproxEqRel(month12Vested, TOTAL_AMOUNT / 2, 0.02e18);

        // After cliff + 18 months: ~18/24 = 75% vested
        vm.warp(cliffEnd + 547 days);
        uint256 month18Vested = vesting.vestedAmount();
        assertApproxEqRel(month18Vested, TOTAL_AMOUNT * 3 / 4, 0.02e18);

        // After cliff + 24 months: 24/24 = 100% vested
        vm.warp(cliffEnd + vesting.VESTING_DURATION());
        uint256 month24Vested = vesting.vestedAmount();
        assertEq(month24Vested, TOTAL_AMOUNT);
    }

    /// @notice Simulate time incrementally with multiple warp + release cycles
    function test_IncrementalReleaseOverTime() public {
        uint256 cliffEnd = vesting.start() + vesting.CLIFF_DURATION();
        uint256 totalReleased;

        // Release every 60 days (2 months) during vesting period, then finish at end
        for (uint256 i = 1; i <= 12; i++) {
            vm.warp(cliffEnd + i * 60 days);
            uint256 amount = vesting.releasable();
            if (amount > 0) {
                vesting.release();
                totalReleased += amount;
            }
        }

        // Final warp to end of vesting to release remaining
        vm.warp(cliffEnd + vesting.VESTING_DURATION());
        uint256 remaining = vesting.releasable();
        vesting.release();
        totalReleased += remaining;

        assertEq(totalReleased, TOTAL_AMOUNT);
        assertEq(token.balanceOf(beneficiary), TOTAL_AMOUNT);
    }

    /// @notice Verify that time before deployment reverts to 0 (edge case)
    function test_TimeCannotGoBackwards() public {
        uint256 cliffEnd = vesting.start() + vesting.CLIFF_DURATION();

        // Warp forward
        vm.warp(cliffEnd + 100 days);
        uint256 vestedForward = vesting.vestedAmount();
        assertGt(vestedForward, 0);

        // Warp backward - vested amount should still be computed at the new (earlier) timestamp
        vm.warp(cliffEnd + 10 days);
        uint256 vestedBackward = vesting.vestedAmount();
        assertLt(vestedBackward, vestedForward);
    }

    /// @notice Test that release only sends to beneficiary (not caller)
    function test_ReleaseSendsToBeneficiary() public {
        vm.warp(vesting.start() + vesting.CLIFF_DURATION() + 365 days);

        address someone = makeAddr("someone");
        uint256 someoneBalanceBefore = token.balanceOf(someone);

        vm.prank(someone);
        vesting.release();

        assertEq(token.balanceOf(someone), someoneBalanceBefore);
        assertGt(token.balanceOf(beneficiary), 0);
    }
}
