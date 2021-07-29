// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/master/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev A token holder contract that will allow a beneficiary to extract the
 * tokens after a given release time.
 *
 * Useful for simple vesting schedules like "advisors get all of their tokens
 * after 1 year".
 */
 
 library Staker{
     struct data{
         uint256 releaseTime;
         uint256 stakedAmount;
         string stakingPlan;
         uint256 lastRewardTime;
         uint256 claimed;
         uint256 unclaimed;
         uint256 id;
         bool isValue;
     }
 }
contract Stake {
    using SafeERC20 for IERC20;
    using Staker for Staker.data;

    // ERC20 basic token contract being held
    IERC20 private  _token;
    
    uint private totalStakers;
    uint private activeStakers;
    address private owner;
    mapping(uint => address) private holders;
    mapping(address => Staker.data) public stakers;
    uint256 public totalStaked;
    uint256 public totalClaimed;
    uint256 public totalUnclaimed;

    constructor(IERC20 token_) {
        //require(releaseTime_ > block.timestamp, "TokenTimelock: release time is before current time");
        _token = token_;
        owner = msg.sender;
        //_beneficiary = beneficiary_;
        //_releaseTime = releaseTime_;
    }
    
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @return the token being held.
     */
    function token() public view virtual returns (IERC20) {
        return _token;
    }
    
    /**
     * Stake Amount in the contract.
     */
    function StakeAmount(uint256 amount, uint256 LockDays) public{
        require(!stakers[msg.sender].isValue,"Already staked with this account");
        require(LockDays >= 30, "Minimum lock period is 30 days");
        require(LockDays <= 366, "Max lock period is 366 days");
        require(amount >= 1500 * 10**18, "Minimum staking amount is 1500 AssetCoin");
        uint stakerID = stakers[msg.sender].id;
        stakers[msg.sender].releaseTime = block.timestamp + (LockDays * 1 days);
        stakers[msg.sender].stakedAmount = amount;
        stakers[msg.sender].isValue = true;
        if(amount >= 1500 * 10**18 && amount < 2500 * 10**18){
            stakers[msg.sender].stakingPlan = "staker";
        }else if(amount >= 2500 * 10**18 && amount < 5000 * 10**18){
            stakers[msg.sender].stakingPlan = "miner";
        }else if(amount >= 5000 * 10**18){
            stakers[msg.sender].stakingPlan = "masternode";
        }
        totalStaked += amount;
        token().safeTransferFrom(msg.sender, address(this), amount);
        if(stakerID == 0){
            holders[totalStakers+1] = msg.sender;
            stakers[msg.sender].id = totalStakers+1;
            totalStakers++;
        }
        stakers[msg.sender].lastRewardTime = block.timestamp;
        activeStakers++;
    }
    
    // function setLastRewardTime(address stakerAddress, uint256 timer) public {
    //     stakers[stakerAddress].lastRewardTime = timer;
    // }
    
    function calculateDay(address stakerAddress) public view returns (uint256, uint){
        if(stakers[stakerAddress].lastRewardTime == 0){
            return (0,0);
        }
        uint256 differ = block.timestamp - stakers[stakerAddress].lastRewardTime;
        uint totalDays = differ/60/60/24;
        return (differ, totalDays);
    }
    
    /**
     * Distribute rewards to the stakers according to their plan.
     */
    function distributeRewards() public onlyOwner() {
        require(RemainingRewards() > 1, "Please refill the staking contract");
        uint256 distributed = 0;
        uint256 percent = 0;
        for(uint i=1; i<=totalStakers; i++){
            if(stakers[holders[i]].isValue){
                (uint256 differ, uint Tdays) = calculateDay(holders[i]);
                if(Tdays > 0){
                    if(keccak256(bytes(stakers[holders[i]].stakingPlan)) == keccak256(bytes("staker"))){
                        percent = 10;
                    }else if(keccak256(bytes(stakers[holders[i]].stakingPlan)) == keccak256(bytes("miner"))){
                        percent = 15;
                    }else if(keccak256(bytes(stakers[holders[i]].stakingPlan)) == keccak256(bytes("masternode"))){
                        percent = 20;
                    }
                    uint256 rewardAmount = (stakers[holders[i]].stakedAmount/100)*percent/30 * Tdays;
                    stakers[holders[i]].unclaimed += rewardAmount;
                    totalUnclaimed += rewardAmount;
                    distributed += rewardAmount;
                    stakers[holders[i]].lastRewardTime += Tdays * 1 days;
                }
            }
        }
        require(RemainingRewards() > distributed, "Please refill the staking contract!");
    }
    
    /**
     * claim your unclaimed amount
     */
    function claimNow() public{
        require(stakers[msg.sender].unclaimed > 1, "There is no unclaimed reward!");
        require(RemainingRewards() > stakers[msg.sender].unclaimed, "There is no unclaimed reward!");
        token().safeTransfer(msg.sender, stakers[msg.sender].unclaimed);
        stakers[msg.sender].claimed += stakers[msg.sender].unclaimed;
        totalClaimed += stakers[msg.sender].unclaimed;
        totalUnclaimed -= stakers[msg.sender].unclaimed;
        stakers[msg.sender].unclaimed = 0;
    }
    
    /**
     * @return the staker's claimed amount.
     */
    function Claimed(address staker) public view virtual returns(uint256){
        return stakers[staker].claimed;
    }
    
    /**
     * @return the staker's unclaimed amount.
     */
    function Unclaimed(address staker) public view virtual returns(uint256){
        return stakers[staker].unclaimed;
    }
    
    /**
     * @return the Rewarding Contract Balance.
     */
    function RemainingRewards() public view virtual returns (uint256) {
        return token().balanceOf(address(this)) - totalStaked - totalUnclaimed;
    }

    /**
     * @return the beneficiary of the tokens.
     */
    
    /**
     * @return the time when the tokens are released.
     */
    function releaseTime(address stakerAddress) public view virtual returns (uint256) {
        return stakers[stakerAddress].releaseTime;
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public virtual {
        require(block.timestamp >= releaseTime(msg.sender), "TokenTimelock: current time is before release time");
        require(!stakers[msg.sender].isValue,"You not staked");
        uint256 camount = token().balanceOf(address(this));
        uint256 amount = stakers[msg.sender].stakedAmount;
        require(camount > 0, "TokenStaker: no tokens to release");
        require(stakers[msg.sender].stakedAmount > 0, "No amount staked");
        token().safeTransfer(msg.sender, amount);
        stakers[msg.sender].isValue = false;
        stakers[msg.sender].stakedAmount = 0;
        activeStakers--;
        totalStaked = totalStaked-amount;
    }
    
    function ForceRelease() public virtual {
        //require(block.timestamp >= releaseTime(msg.sender), "TokenTimelock: current time is before release time");
        require(stakers[msg.sender].isValue,"You not staked");
        uint256 camount = token().balanceOf(address(this));
        uint256 amount = stakers[msg.sender].stakedAmount;
        require(camount > 0, "TokenStaker: no tokens to release");
        require(stakers[msg.sender].stakedAmount > 1, "No amount staked");
        token().safeTransfer(msg.sender, amount);
        stakers[msg.sender].stakedAmount = 0;
        stakers[msg.sender].isValue = false;
        activeStakers--;
        totalStaked = totalStaked-amount;
    }
}