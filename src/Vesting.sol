// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Vesting - Token vesting contract with cliff and linear unlock
/// @notice After deployment, a 12-month cliff starts. Then tokens unlock linearly
///         over the next 24 months (1/24 per month from month 13 to month 36).
contract Vesting {
    using SafeERC20 for IERC20;

    /// @notice Beneficiary who receives vested tokens
    address public immutable beneficiary;
    /// @notice The ERC20 token being vested
    IERC20 public immutable token;
    /// @notice Total amount of tokens locked in this contract
    uint256 public immutable totalAmount;
    /// @notice Timestamp when vesting starts (deployment time)
    uint64 public immutable start;

    /// @notice Total tokens already released to beneficiary
    uint256 public released;

    /// @notice Cliff period: 12 months (365 days)
    uint256 public constant CLIFF_DURATION = 365 days;
    /// @notice Vesting period: 24 months (730 days) after cliff ends
    uint256 public constant VESTING_DURATION = 730 days;

    event ERC20Released(uint256 amount);

    /// @param _beneficiary Address that will receive the vested tokens
    /// @param _token Address of the ERC20 token to vest
    /// @param _totalAmount Total amount of tokens to lock (must be transferred after deployment)
    constructor(address _beneficiary, address _token, uint256 _totalAmount) {
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_token != address(0), "Invalid token");
        require(_totalAmount > 0, "Amount must be > 0");

        beneficiary = _beneficiary;
        token = IERC20(_token);
        totalAmount = _totalAmount;
        start = uint64(block.timestamp);
    }

    /// @notice Computes the amount of tokens that have vested so far
    function vestedAmount() public view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 cliffEnd = uint256(start) + CLIFF_DURATION;

        // Still in cliff period, nothing vested
        if (currentTime < cliffEnd) {
            return 0;
        }

        uint256 vestingEnd = cliffEnd + VESTING_DURATION;

        // Fully vested after cliff + vesting period
        if (currentTime >= vestingEnd) {
            return totalAmount;
        }

        // Linear vesting during the 24-month period after cliff
        uint256 timeAfterCliff = currentTime - cliffEnd;
        return (totalAmount * timeAfterCliff) / VESTING_DURATION;
    }

    /// @notice Computes how many tokens are currently available to release
    function releasable() public view returns (uint256) {
        return vestedAmount() - released;
    }

    /// @notice Releases vested tokens to the beneficiary
    function release() external {
        uint256 amount = releasable();
        require(amount > 0, "Nothing to release");
        released += amount;
        emit ERC20Released(amount);
        token.safeTransfer(beneficiary, amount);
    }
}
