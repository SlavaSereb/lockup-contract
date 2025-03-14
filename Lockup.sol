// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TimeLockedSavings {
    struct Deposit {
        uint256 amount;
        uint256 unlockTime;
        bool rewardsClaimed;
    }

    mapping(address => Deposit[]) private userDeposits;
    uint256 public constant REWARD_PER_5_MINUTES = 0.001 ether;

    event DepositMade(address indexed user, uint256 amount, uint256 unlockTime);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 rewardAmount);
    event ContractFunded(address indexed funder, uint256 amount);

    // 🔹 Allow contract to receive ETH manually
    receive() external payable {
        emit ContractFunded(msg.sender, msg.value);
    }

    function depositFunds(uint256 lockDuration) public payable {
        require(msg.value > 0, "Must deposit ETH");
        require(lockDuration >= 5 minutes, "Minimum lock time is 5 minutes");

        uint256 unlockTime = block.timestamp + lockDuration;
        userDeposits[msg.sender].push(Deposit(msg.value, unlockTime, false));

        emit DepositMade(msg.sender, msg.value, unlockTime);
    }

    function getUserDeposits() public view returns (Deposit[] memory) {
        return userDeposits[msg.sender];
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function claimRewards() public {
        require(userDeposits[msg.sender].length > 0, "No deposits found");

        uint256 totalRewards = 0;

        for (uint256 i = 0; i < userDeposits[msg.sender].length; i++) {
            if (block.timestamp >= userDeposits[msg.sender][i].unlockTime && !userDeposits[msg.sender][i].rewardsClaimed) {
                uint256 lockDuration = userDeposits[msg.sender][i].unlockTime - (block.timestamp - userDeposits[msg.sender][i].unlockTime);
                uint256 rewardUnits = lockDuration / 300; // 5 minutes = 300 seconds
                uint256 reward = rewardUnits * REWARD_PER_5_MINUTES;
                totalRewards += reward;
                userDeposits[msg.sender][i].rewardsClaimed = true;
            }
        }

        require(totalRewards > 0, "No rewards available to claim");
        require(address(this).balance >= totalRewards, "Insufficient contract balance for rewards");

        payable(msg.sender).transfer(totalRewards);

        emit RewardsClaimed(msg.sender, totalRewards);
    }

    function withdrawFunds() public {
        require(userDeposits[msg.sender].length > 0, "No deposits found");

        uint256 totalWithdrawable = 0;
        uint256 i = 0;

        while (i < userDeposits[msg.sender].length) {
            if (block.timestamp >= userDeposits[msg.sender][i].unlockTime) {
                require(userDeposits[msg.sender][i].rewardsClaimed, "Must claim rewards first");
                
                totalWithdrawable += userDeposits[msg.sender][i].amount;
                userDeposits[msg.sender][i] = userDeposits[msg.sender][userDeposits[msg.sender].length - 1]; // Swap with last element
                userDeposits[msg.sender].pop(); // Remove last element
            } else {
                i++;
            }
        }

        require(totalWithdrawable > 0, "No funds available for withdrawal");
        payable(msg.sender).transfer(totalWithdrawable);

        emit FundsWithdrawn(msg.sender, totalWithdrawable);
    }
}
