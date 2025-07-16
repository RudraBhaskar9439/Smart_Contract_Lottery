// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script,console} from "../lib/forge-std/src/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script,CodeConstants {
    function createSubscriptionUsingConfig() public returns(uint256, address){
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        (uint256 subId,) = createSubscription(vrfCoordinator);  // create a new subscription
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns(uint256, address){
        console.log("Creating subscription on chainId: ",block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscription Id is :", subId);
        console.log("Please update the subscription id to you HelperConfig.s.sol file");
        return (subId, vrfCoordinator);

    }
    function run() public {
        createSubscriptionUsingConfig();
    }
   
}

contract FundSubscription is Script,CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken);

    }
    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
        console.log("Funding Subscription: ", subscriptionId);
        console.log("Using vrdCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        if(block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        }
        else{
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }

}

contract AddConsumer is Script {

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
       HelperConfig helperConfig = new HelperConfig();
       uint256 subId = helperConfig.getConfig().subscriptionId;
       address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
       addConsumer(mostRecentlyDeployed, vrfCoordinator, subId);
    }

    function addConsumer(address contractToAddtoVrf,address vrfCoordinator, uint256 subId ) public {
        console.log(" Adding consumer contract: ", contractToAddtoVrf);
        console.log("To vrfCoordinator: ", vrfCoordinator);
        console.log("Using ChainId: ", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddtoVrf);
        vm.stopBroadcast();

        }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}



