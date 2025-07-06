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
    // @dev The duration of lottery in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;

    /* Events */
    event RaffleEntered(address indexed player);


    constructor(uint256 entranceFee, uint256 interval){
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }
    // Difference between public and external:
//     // Feature	                 public	                                       external
//     Who can call it?	        Anyone (external and internal)	        Only from outside the contract
// Internal calls allowed?	    ✅ Yes	                               ❌ No (must use this.function())
//     Gas efficiency	        Slightly less efficient	                More gas efficient for external calls
//       Use case	        Shared logic within contract or library	    External APIs (e.g., user input, interfaces)


    function enterRaffle() external payable  {
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
        // 3. Make it easier to store variable in log 
        // 4. Smart contracts cannot access Events this is the trade off
        // 5. We can print information without having to save it in a storage variable which is going to take up more gas
        // 6. Each one of these events is tied to the smart contract or account address that emitted it
        // 7. Listening for these events is incredibly helpful 
        // 8. This is how a lot of off-chain infrastructure works
        // 9. Example: Chainlink VRF
        //    A Chainlink network a Chainlink node is actually listening for these events request data events for it 
        //    to get a random number, make an API call and stores them in a graph so that they are easy to query later on 
        // 10. So Events are incredibly useful
        emit RaffleEntered(msg.sender);
    }

    // What all things are required to be done in pickWinner function?
    // 1. Get a random number
    // 2. Use random number to pick a player
    // 3. Be automatically called

    function pickWinner() external {
        //check to see if enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval ){
            revert();
        }
        
    }

    /**
     * Getter Functions
     */
    function getEntraceFee() external view returns (uint256) {
        return i_entranceFee;
    }
    
}
