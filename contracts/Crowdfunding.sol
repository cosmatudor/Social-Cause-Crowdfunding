// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

/**
 * @title Crowdfunding Contract
 * @author Cosma Tudor Mihai
 * @notice This contract allows users to contribute to crowdfunding campaigns.
 */
contract Crowdfunding {
    using PriceConverter for uint256;

    /* State variables */
    struct Campaign {
        string title;
        string description;
        uint256 targetAmount;
        uint256 currentAmount;
        mapping(address => uint256) contributions;
        uint256 deadline;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public numberOfCampaigns;
    address public owner;
    uint256 public constant MINIMUM_USD = 5 * 1e18; // $5
    AggregatorV3Interface private priceFeed;

    /* Events */
    event CampaignCreated(
        uint256 campaignId,
        string _title,
        string _description,
        uint256 _targetAmount,
        uint256 _currentAmount,
        uint256 _deadline
    );

    event DonationSent(
        address indexed donor,
        uint256 indexed campaignId,
        uint256 amount
    );

    event Refunded(
        address refunder,
        uint256 indexed campaignId,
        uint256 amount
    );

    /* Modifiers */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner is permited!");
        _;
    }

    constructor(address _priceFeedAddress) {
        owner = msg.sender;
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    function addCampaign(
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _currentAmount,
        uint256 _deadline
    ) public onlyOwner returns (uint256 campaignId) {
        require(
            _deadline > block.timestamp,
            "Deadline should be a date in the future"
        );

        numberOfCampaigns++;
        campaignId = hashCampaign(_title, _description);
        Campaign storage campaign = campaigns[campaignId];

        campaign.title = _title;
        campaign.description = _description;
        campaign.targetAmount = _targetAmount;
        campaign.currentAmount = _currentAmount;
        campaign.deadline = _deadline;

        emit CampaignCreated(
            campaignId,
            _title,
            _description,
            _targetAmount,
            _currentAmount,
            _deadline
        );
    }

    function donate(uint256 _campaignId) public payable {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign is closed");
        require(
            campaign.currentAmount < campaign.targetAmount,
            "Campaign is already funded"
        );
        uint256 conversionRate = msg.value.getConversionRate(priceFeed);
        require(
            conversionRate >= MINIMUM_USD,
            "Minimum donation amount should be $5!"
        );

        uint256 newCurrentAmount = campaign.currentAmount + msg.value;
        campaign.currentAmount = newCurrentAmount;
        campaign.contributions[msg.sender] += msg.value;

        emit DonationSent(msg.sender, _campaignId, msg.value);
    }

    function refund(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(
            block.timestamp > campaign.deadline,
            "Campaign is still active"
        );
        require(
            campaign.currentAmount < campaign.targetAmount,
            "Campaign is funded"
        );

        uint256 contribution = campaign.contributions[msg.sender];
        require(contribution > 0, "No contribution made");

        // reduce to 0 the contribution
        campaign.contributions[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: contribution}("");
        require(success, "Refund reverted");

        emit Refunded(msg.sender, _campaignId, contribution);
    }

    /**
     * @dev Computes a unique ID for a campaign based on its title and description.
     * The title and description should preferably differ for each campaign.
     * The function uses keccak256 for hashing and solidity's abi.encode for input encoding.
     * @param title: The title of the campaign.
     * @param description: The description of the campaign.
     * @return campaignId -> The unique campaign identifier as a uint256.
     */
    function hashCampaign(
        string memory title,
        string memory description
    ) private pure returns (uint256 campaignId) {
        campaignId = uint256(keccak256(abi.encode(title, description)));
    }

    /* Getters */
    function getCampaignDetails(
        uint256 _campaignId
    )
        public
        view
        returns (
            string memory title,
            string memory description,
            uint256 targetAmount,
            uint256 currentAmount,
            uint256 deadline
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        title = campaign.title;
        description = campaign.description;
        targetAmount = campaign.targetAmount;
        currentAmount = campaign.currentAmount;
        deadline = campaign.deadline;
    }

    function getCampaignContributions(
        uint256 _campaignId,
        address _contributor
    ) public view returns (uint256) {
        Campaign storage campaign = campaigns[_campaignId];
        return campaign.contributions[_contributor];
    }

    function getRaisedAmountForCampaign(
        uint256 _campaignId
    ) public view returns (uint256) {
        Campaign storage campaign = campaigns[_campaignId];
        return campaign.currentAmount;
    }

    function getCampaignAvailability(
        uint256 _campaignId
    ) public view returns (bool) {
        Campaign storage campaign = campaigns[_campaignId];
        return
            campaign.currentAmount < campaign.targetAmount &&
            block.timestamp < campaign.deadline;
    }
}
