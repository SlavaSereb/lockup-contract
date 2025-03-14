// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TimeLockedSavings {
    struct Deposit {
        uint256 amount;
        uint256 depositTime;
        uint256 unlockTime;
        bool rewardsClaimed;
    }

    mapping(address => Deposit[]) private userDeposits;
    uint256 public constant REWARD_PER_5_MINUTES = 0.001 ether;
    uint256 public constant MIN_LOCK_TIME = 5 minutes;
    address public owner;

    event DepositMade(address indexed user, uint256 amount, uint256 unlockTime);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 rewardAmount);
    event ContractFunded(address indexed funder, uint256 amount);
    event ContractEmptied(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {
        emit ContractFunded(msg.sender, msg.value);
    }

    function depositFunds(uint256 lockDuration) public payable {
        require(msg.value > 0, "Must deposit ETH");
        require(lockDuration >= MIN_LOCK_TIME, "Minimum lock time is 5 minutes");

        uint256 unlockTime = block.timestamp + lockDuration;
        userDeposits[msg.sender].push(
            Deposit({
                amount: msg.value,
                depositTime: block.timestamp,
                unlockTime: unlockTime,
                rewardsClaimed: false
            })
        );

        emit DepositMade(msg.sender, msg.value, unlockTime);
    }

    function getUserDeposits() public view returns (Deposit[] memory) {
        return userDeposits[msg.sender];
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getClaimableRewards() public view returns (uint256) {
        Deposit[] memory deposits = userDeposits[msg.sender];
        require(deposits.length > 0, "No deposits found");

        uint256 totalRewards = 0;

        for (uint256 i = 0; i < deposits.length; i++) {
            Deposit memory deposit = deposits[i];

            if (block.timestamp >= deposit.unlockTime && !deposit.rewardsClaimed) {
                // Calculate actual time the funds were locked
                uint256 lockDuration = deposit.unlockTime - deposit.depositTime;
                
                // Calculate rewards based on full 5-minute periods completed
                uint256 rewardUnits = lockDuration / 300; // 5 minutes = 300 seconds
                uint256 reward = rewardUnits * REWARD_PER_5_MINUTES;
                totalRewards += reward;
            }
        }

        return totalRewards;
    }

    function claimRewards() public {
        Deposit[] storage deposits = userDeposits[msg.sender];
        require(deposits.length > 0, "No deposits found");

        uint256 totalRewards = 0;
        bool hasClaimableRewards = false;

        for (uint256 i = 0; i < deposits.length; i++) {
            if (block.timestamp >= deposits[i].unlockTime && !deposits[i].rewardsClaimed) {
                // Calculate rewards for this deposit
                uint256 lockDuration = deposits[i].unlockTime - deposits[i].depositTime;
                uint256 rewardUnits = lockDuration / 300;
                uint256 reward = rewardUnits * REWARD_PER_5_MINUTES;
                
                totalRewards += reward;
                deposits[i].rewardsClaimed = true;
                hasClaimableRewards = true;
            }
        }

        require(hasClaimableRewards, "No rewards available to claim");
        require(address(this).balance >= totalRewards, "Insufficient contract balance for rewards");

        if (totalRewards > 0) {
            payable(msg.sender).transfer(totalRewards);
            emit RewardsClaimed(msg.sender, totalRewards);
        }
    }

    function withdrawFunds() public {
        Deposit[] storage deposits = userDeposits[msg.sender];
        require(deposits.length > 0, "No deposits found");

        uint256 totalWithdrawable = 0;
        uint256 i = 0;

        while (i < deposits.length) {
            if (block.timestamp >= deposits[i].unlockTime) {
                require(deposits[i].rewardsClaimed, "Must claim rewards first");

                totalWithdrawable += deposits[i].amount;

                // Efficient removal by swap and pop
                deposits[i] = deposits[deposits.length - 1];
                deposits.pop();
            } else {
                i++;
            }
        }

        require(totalWithdrawable > 0, "No funds available for withdrawal");
        
        payable(msg.sender).transfer(totalWithdrawable);
        emit FundsWithdrawn(msg.sender, totalWithdrawable);
    }

    function withdrawContractBalance() public onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds available");

        payable(owner).transfer(contractBalance);
        emit ContractEmptied(owner, contractBalance);
    }
}
