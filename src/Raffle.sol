// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title A simple Raffle contract
 * @dev Implements ChainLink VRFv2.5
 * @author Rudra Bhaskar
 * @notice This contract allows users to enter in a Lottery~Style raffle.
 */

contract Raffle {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();

    /* State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    /* Events */
    event RaffleEntered(address indexed player);


    constructor(uint256 entranceFee){
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable  {
        // Method-1 (Highest Gas Cost)
            // require(msg.value >= i_entranceFee, "No enough ETH sent");
        // Method-2 (Lowest Gas Cost)
            if(msg.value < i_entranceFee) {
                revert Raffle__SendMoreToEnterRaffle();
            }
            s_players.push(payable(msg.sender));
        // Method-3 (Medium Gas Cost)
            // require(msg.value >= i_entranceFee, SendMoreToEnterRaffle());
        
        // Events
        // 1. Make migration easier 
        // 2. Makes front end "indexing" easier
        emit RaffleEntered(msg.sender);
    }

    function pickWinner() public {

    }

    /**
     * Getter Functions
     */
    function getEntraceFee() external view returns (uint256) {
        return i_entranceFee;
    }
    
}
