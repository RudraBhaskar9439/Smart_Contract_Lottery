// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";


contract Raffletest is Test {
    Raffle public raffle;
    // HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    VRFCoordinatorV2_5Mock vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    //Test user address
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    

    function setUp() external {
        // Deploy VRFCoordinator mock
        vrfCoordinator = new VRFCoordinatorV2_5Mock(0.25 ether, 1e9, 4e15);
        // Create a subscription
        subscriptionId = vrfCoordinator.createSubscription();
        // Fund the subscription (arbitrary amount)
        vrfCoordinator.fundSubscription(subscriptionId, 1 ether);
        entranceFee = 0.01 ether;
        interval = 30;
        gasLane = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
        callbackGasLimit = 500000;
        // Deploy Raffle contract
        raffle = new Raffle(
            entranceFee,
            interval,
            address(vrfCoordinator),
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        // Add Raffle as consumer to VRFCoordinatorV2_5Mock
        vrfCoordinator.addConsumer(subscriptionId, address(raffle));
    }

    function testRaffleInitializationInOpenState() external {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    ////////////////////////////////////////////////////////// */
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act // Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act 
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number +1 );
        raffle.performUpkeep("");

        // Act // Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
       
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number +1 );

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testChekcUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number +1 );
         raffle.performUpkeep("");

         // Act
         (bool upkeepNeeded,) = raffle.checkUpkeep("");

         // Assert
         assert(!upkeepNeeded);
    }

    ////////////////////////////////// Perform Upkeep ///////////////////////////////////////
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number +1 );

        // Act // Assert
        raffle.performUpkeep("");
        
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;


        // Act // Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");

    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number +1 );
        _;
    }

    //What if we need tp get data from emitted events in our tests?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {

        // Arrange
       //  It is in the Modifier 

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) >0);
        assert(uint256(raffleState) == 1);
    
    }

    /////////////////////// FulFill Random Words ///////////////////////

    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public  raffleEntered{ // raffleEntered is the modifier that enters the raffle
    // Arrange // Act // Assert
    vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));


    }

// function testFulfillrandomWordsPicksWinnerAndSendsMoney() public raffleEntered {
//     // Arrange
//     uint256 additionalEntrants = 3;
//     uint256 startingIndex = 1;
//     address expectedWinner = address(1);

//     for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
//         address newPlayer = address(uint160(i));
//         hoax(newPlayer, 1 ether);
//         raffle.enterRaffle{ value: entranceFee }();
//     }
//     uint256 startingTimeStamp = raffle.getLastTimeStamp();
//     uint256 winnerStartingBalance = expectedWinner.balance;

//     // Act
//     vm.recordLogs();
//     raffle.performUpkeep("");
//     Vm.Log[] memory entries = vm.getRecordedLogs();
//     bytes32 requestId = entries[1].topics[1];
//     VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

//     // Assert
//     address recentWinner = raffle.getRecentWinner();
//     Raffle.RaffleState rafflestate = raffle.getRaffleState();
//     uint256 winnerBalance = recentWinner.balance;
//     uint256 endingTimeStamp = raffle.getLastTimeStamp();
//     uint256 prize = entranceFee * (additionalEntrants + 1);

//     assert(recentWinner == expectedWinner);
//     assert(uint256(rafflestate) == 0);
//     assert(winnerBalance == winnerStartingBalance + prize);
//     assert(endingTimeStamp > startingTimeStamp);
// }

}
