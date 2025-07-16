// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFConsumerBaseV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
/**
 * @title A simple Raffle contract
 * @dev Implements ChainLink VRFv2.5
 * @author Rudra Bhaskar
 * @notice This contract allows users to enter in a Lottery~Style raffle.
 */

contract Raffle is VRFConsumerBaseV2Plus {

    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 numPlayers, uint256 raffleState);
    

// Enums in Solidity are user-defined types that allow you to name and group a set of related constant values. 
// They improve code readability by replacing numeric constants with descriptive names. 
// Internally, enum values are stored as uint, starting from 0.

    /* Type Declaration */
    enum RaffleState {
        OPEN,        //0
        CALCULATING  //1
    }

    /* State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    // @dev The duration of lottery in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_keyHash;
    uint256 private i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1; // Number of random words to request
    address private s_recentWinner;
    RaffleState private s_raffleState ;// Start as OPEN

    

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);


    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint256 subscriptionId, uint32 callbackGasLimit ) VRFConsumerBaseV2Plus(vrfCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;  // Equivalent to s_raffleState = RaffleState(0); 
    
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
            if(s_raffleState != RaffleState.OPEN) {
                revert Raffle__RaffleNotOpen();
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

    // When should the winner be pciked?
    /***
     * @dev This is a function that the chainlink nodes will call to see 
     * if lottery is ready to have a winner picked.
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is in a state of OPEN
     * 3. The contract has ETH
     * 4. Implicitly, your subscription has LINK
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return - ignored
     */

    function checkUpkeep(bytes memory /*checkData*/) 
        public 
        view 
        returns(bool upkeepNeeded, bytes memory /* performData */)
        {
         bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval ); // Check if enough time has passed
         bool isOPEN = s_raffleState ==RaffleState.OPEN; // Check if the raffle is in OPEN state
         bool hasBalance = address(this).balance > 0; // Check if the contract has a balance
         bool hasPlayers = s_players.length > 0; // Check if there is players in the raffle 
         upkeepNeeded = timeHasPassed && isOPEN && hasBalance && hasPlayers; // All condiitons must be true for upkeepNeeded to be true
         return (upkeepNeeded,""); // Return the upkeepNeeded boolean and an empty bytes array
        }

    function performUpkeep(bytes calldata /* performData */) external {
        //check to see if enough time has passed
       (bool upkeepNeeded,) = checkUpkeep("");
       if(!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
}

        s_raffleState = RaffleState.CALCULATING; // Set the raffle state to CALCULATING

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest(
            {
                keyHash: i_keyHash, // Price I am willing to pay for the random number
                subId: i_subscriptionId, // Subscription ID for the VRF service
                requestConfirmations: REQUEST_CONFIRMATIONS, // number of confirmations before the request is considered valid
                callbackGasLimit: i_callbackGasLimit,  // Gas limit for the callback function
                numWords: NUM_WORDS,  // number of random words to request
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayments to true to pay for VRF requests with sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            }
            
        );
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }
        // Get our Rnadom Number using ChainLink VRF
        // 1. Request RNG
        // 2. Get RNG
        // Chainlink VRF will call this function with the random words

//         Feature	                                    calldata	                                  memory
//         Location	                       Non-modifiable, temporary, read-only	                Modifiable, temporary
//        Storage Place                 	   Input data of function call                 	Allocated in memory at runtime
//         Mutability	                          ❌ Cannot be modified	                         ✅ Can be modified
//         Gas Cost	                       ✅ Cheaper (no copying unless needed)	           ❌ More expensive (copies data)
//         Use Case	                          Best for external function inputs	           Best for local variables or modifiable parameters
//       Access Speed	                     Fast (direct reference to call data)	        Slower (data copied into memory)

// The function used override here because its parent contract is abstract and the function is internal virtual

    // CEI: Checks, Effects, Interactions Pattern
    function fulfillRandomWords(uint256 /* requestId */ , uint256[] calldata randomWords) internal override {
        // Checks
            // Conditionals and require statements are checks


        //Effects (Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN; // Set the raffle state back to OPEN
        s_players = new address payable[](0); // Reset the players array for the next raffle
        s_lastTimeStamp = block.timestamp; // Update the last timestamp to the current block timestamp
        emit WinnerPicked(s_recentWinner);

        // Interactions (External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if(!success) {
            revert Raffle__TransferFailed();
        }
        
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
    
    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
