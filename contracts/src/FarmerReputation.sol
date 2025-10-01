// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FarmerReputation
 * @dev Smart contract for managing farmer reputation and quality consistency
 * Integrates with TreeID, Certification, Harvest, and ConsumerVerification contracts
 */
contract FarmerReputation is Ownable, ReentrancyGuard {
    // Counter for reputation events
    uint256 private _reputationEventIdCounter;
    
    // Structure for farmer reputation profile
    struct FarmerProfile {
        address farmerAddress;
        string farmerName;
        string location;
        uint256 totalTrees;
        uint256 totalHarvests;
        uint256 totalCertifications;
        uint256 reputationScore; // 0-1000
        uint256 qualityConsistency; // 0-100
        uint256 organicPercentage; // 0-100
        uint256 consumerRating; // 0-100
        uint256 registrationDate;
        bool isVerified;
        uint256 verificationDate;
        string ipfsHash; // For farmer profile documents
    }
    
    // Structure for reputation event
    struct ReputationEvent {
        uint256 eventId;
        address farmer;
        string eventType; // "Harvest_Quality", "Certification", "Consumer_Rating", "Organic_Score"
        uint256 score; // Score for this event
        uint256 timestamp;
        string description;
        uint256 treeId; // Associated tree ID
        uint256 harvestId; // Associated harvest ID
        uint256 certificationId; // Associated certification ID
        string ipfsHash; // Event details
    }
    
    // Structure for quality metrics
    struct QualityMetrics {
        uint256 averageSize; // Average fruit size
        uint256 averageSweetness; // Average sweetness score
        uint256 farmerId;
        uint256 averageFirmness; // Average firmness score
        uint256 defectRate; // Percentage of defects
        uint256 exportStandardCompliance; // Percentage meeting export standards
        uint256 lastUpdated;
    }
    
    // Structure for reputation tier
    struct ReputationTier {
        string tierName; // "Bronze", "Silver", "Gold", "Platinum"
        uint256 minScore;
        uint256 maxScore;
        uint256 benefits; // Benefits multiplier
        string description;
    }
    
    // Mappings
    mapping(address => FarmerProfile) public farmerProfiles;
    mapping(uint256 => ReputationEvent) public reputationEvents;
    mapping(address => uint256[]) public farmerEvents; // farmer to event IDs
    mapping(address => QualityMetrics) public farmerQualityMetrics;
    mapping(uint256 => ReputationTier) public reputationTiers;
    mapping(address => uint256) public farmerTier; // farmer to tier ID
    mapping(address => uint256) public farmerLastUpdate; // Last reputation update
    
    // Constants
    uint256 public constant MAX_REPUTATION_SCORE = 1000;
    uint256 public constant MAX_QUALITY_CONSISTENCY = 100;
    uint256 public constant REPUTATION_DECAY_RATE = 1; // Points per day decay
    
    // Events
    event FarmerRegistered(address indexed farmer, string farmerName);
    event ReputationUpdated(address indexed farmer, uint256 newScore, uint256 eventId);
    event QualityMetricsUpdated(address indexed farmer, uint256 consistency);
    event TierUpgraded(address indexed farmer, string newTier);
    event ReputationEventRecorded(uint256 indexed eventId, address indexed farmer, string eventType);
    
    constructor() Ownable(msg.sender) {
        // Initialize reputation tiers
        reputationTiers[1] = ReputationTier("Bronze", 0, 250, 100, "New farmer, building reputation");
        reputationTiers[2] = ReputationTier("Silver", 251, 500, 125, "Established farmer, good quality");
        reputationTiers[3] = ReputationTier("Gold", 501, 750, 150, "Premium farmer, excellent quality");
        reputationTiers[4] = ReputationTier("Platinum", 751, 1000, 200, "Elite farmer, exceptional quality");
    }
    
    /**
     * @dev Register a new farmer
     * @param farmerName Name of the farmer
     * @param location Farmer's location
     * @param ipfsHash IPFS hash for farmer documents
     */
    function registerFarmer(
        string memory farmerName,
        string memory location,
        string memory ipfsHash
    ) external {
        require(bytes(farmerName).length > 0, "Farmer name cannot be empty");
        require(bytes(location).length > 0, "Location cannot be empty");
        require(farmerProfiles[msg.sender].farmerAddress == address(0), "Farmer already registered");
        
        FarmerProfile memory profile = FarmerProfile({
            farmerAddress: msg.sender,
            farmerName: farmerName,
            location: location,
            totalTrees: 0,
            totalHarvests: 0,
            totalCertifications: 0,
            reputationScore: 100, // Starting score
            qualityConsistency: 50, // Starting consistency
            organicPercentage: 0,
            consumerRating: 0,
            registrationDate: block.timestamp,
            isVerified: false,
            verificationDate: 0,
            ipfsHash: ipfsHash
        });
        
        farmerProfiles[msg.sender] = profile;
        farmerTier[msg.sender] = 1; // Bronze tier
        farmerLastUpdate[msg.sender] = block.timestamp;
        
        emit FarmerRegistered(msg.sender, farmerName);
    }
    
    /**
     * @dev Record a reputation event
     * @param farmer Address of the farmer
     * @param eventType Type of event
     * @param score Score for this event
     * @param description Event description
     * @param treeId Associated tree ID
     * @param harvestId Associated harvest ID
     * @param certificationId Associated certification ID
     * @param ipfsHash Event details
     */
    function recordReputationEvent(
        address farmer,
        string memory eventType,
        uint256 score,
        string memory description,
        uint256 treeId,
        uint256 harvestId,
        uint256 certificationId,
        string memory ipfsHash
    ) external onlyOwner returns (uint256) {
        require(farmerProfiles[farmer].farmerAddress != address(0), "Farmer not registered");
        require(bytes(eventType).length > 0, "Event type cannot be empty");
        require(score <= 100, "Score cannot exceed 100");
        
        _reputationEventIdCounter++;
        uint256 newEventId = _reputationEventIdCounter;
        
        ReputationEvent memory event_ = ReputationEvent({
            eventId: newEventId,
            farmer: farmer,
            eventType: eventType,
            score: score,
            timestamp: block.timestamp,
            description: description,
            treeId: treeId,
            harvestId: harvestId,
            certificationId: certificationId,
            ipfsHash: ipfsHash
        });
        
        reputationEvents[newEventId] = event_;
        farmerEvents[farmer].push(newEventId);
        
        // Update farmer reputation
        updateFarmerReputation(farmer, score, eventType);
        
        emit ReputationEventRecorded(newEventId, farmer, eventType);
        
        return newEventId;
    }
    
    /**
     * @dev Update farmer reputation based on event
     * @param farmer Address of the farmer
     * @param score Event score
     * @param eventType Type of event
     */
     
     // Farmer reputation mechanism
    function updateFarmerReputation(address farmer, uint256 score, string memory eventType) internal {
        FarmerProfile storage profile = farmerProfiles[farmer];
        
        // Apply reputation decay based on time since last update
        uint256 timeSinceLastUpdate = block.timestamp - farmerLastUpdate[farmer];
        uint256 decayAmount = (timeSinceLastUpdate / 86400) * REPUTATION_DECAY_RATE; // Daily decay
        
        if (profile.reputationScore > decayAmount) {
            profile.reputationScore -= decayAmount;
        } else {
            profile.reputationScore = 0;
        }
        
        // Calculate reputation change based on event type
        uint256 reputationChange = 0;
        
        if (keccak256(bytes(eventType)) == keccak256(bytes("Harvest_Quality"))) {
            reputationChange = score * 2;
        } else if (keccak256(bytes(eventType)) == keccak256(bytes("Certification"))) {
            reputationChange = score * 3;
        } else if (keccak256(bytes(eventType)) == keccak256(bytes("Consumer_Rating"))) {
            reputationChange = score * 1;
        } else if (keccak256(bytes(eventType)) == keccak256(bytes("Organic_Score"))) {
            reputationChange = score * 2;
        }
        
        // Apply reputation change
        uint256 newScore = profile.reputationScore + reputationChange;
        if (newScore > MAX_REPUTATION_SCORE) {
            newScore = MAX_REPUTATION_SCORE;
        }
        
        profile.reputationScore = newScore;
        farmerLastUpdate[farmer] = block.timestamp;
        
        // Check for tier upgrade
        checkTierUpgrade(farmer, newScore);
        
        emit ReputationUpdated(farmer, newScore, _reputationEventIdCounter);
    }

    // Tier upgrade logic
    function checkTierUpgrade(address farmer, uint256 newScore) internal {
        uint256 currentTier = farmerTier[farmer];
        uint256 newTier = currentTier;
        
        // Check from highest to lowest tier
        if (newScore >= 751) {
            newTier = 4; // Platinum
        } else if (newScore >= 501) {
            newTier = 3; // Gold
        } else if (newScore >= 251) {
            newTier = 2; // Silver
        } else {
            newTier = 1; // Bronze
        }
        
        if (newTier != currentTier) {
            farmerTier[farmer] = newTier;
            emit TierUpgraded(farmer, reputationTiers[newTier].tierName);
        }
    }
    /**
     * @dev Update quality metrics for a farmer
     * @param farmer Address of the farmer
     * @param averageSize Average fruit size
     * @param averageSweetness Average sweetness score
     * @param averageFirmness Average firmness score
     * @param defectRate Percentage of defects
     * @param exportStandardCompliance Percentage meeting export standards
     */
    function updateQualityMetrics(
        address farmer,
        uint256 averageSize,
        uint256 averageSweetness,
        uint256 averageFirmness,
        uint256 defectRate,
        uint256 exportStandardCompliance
    ) external onlyOwner {
        require(farmerProfiles[farmer].farmerAddress != address(0), "Farmer not registered");
        
        QualityMetrics memory metrics = QualityMetrics({
            farmerId: uint256(uint160(farmer)),
            averageSize: averageSize,
            averageSweetness: averageSweetness,
            averageFirmness: averageFirmness,
            defectRate: defectRate,
            exportStandardCompliance: exportStandardCompliance,
            lastUpdated: block.timestamp
        });
        
        farmerQualityMetrics[farmer] = metrics;
        
        // Calculate quality consistency
        uint256 consistency = calculateQualityConsistency(metrics);
        farmerProfiles[farmer].qualityConsistency = consistency;
        
        emit QualityMetricsUpdated(farmer, consistency);
    }
    
    /**
     * @dev Calculate quality consistency score
     * @param metrics Quality metrics
     * @return Consistency score (0-100)
     */
    function calculateQualityConsistency(QualityMetrics memory metrics) internal pure returns (uint256) {
        uint256 consistency = 0;
        
        // Size consistency (20 points)
        if (metrics.averageSize >= 80) consistency += 20;
        else if (metrics.averageSize >= 60) consistency += 15;
        else if (metrics.averageSize >= 40) consistency += 10;
        
        // Sweetness consistency (20 points)
        if (metrics.averageSweetness >= 15) consistency += 20;
        else if (metrics.averageSweetness >= 12) consistency += 15;
        else if (metrics.averageSweetness >= 8) consistency += 10;
        
        // Firmness consistency (20 points)
        if (metrics.averageFirmness >= 8) consistency += 20;
        else if (metrics.averageFirmness >= 6) consistency += 15;
        else if (metrics.averageFirmness >= 4) consistency += 10;
        
        // Defect rate (20 points)
        if (metrics.defectRate <= 5) consistency += 20;
        else if (metrics.defectRate <= 10) consistency += 15;
        else if (metrics.defectRate <= 20) consistency += 10;
        
        // Export standard compliance (20 points)
        if (metrics.exportStandardCompliance >= 90) consistency += 20;
        else if (metrics.exportStandardCompliance >= 75) consistency += 15;
        else if (metrics.exportStandardCompliance >= 60) consistency += 10;
        
        return consistency;
    }
    
    /**
     * @dev Check and upgrade farmer tier
     * @param farmer Address of the farmer
     * @param newScore New reputation score
     */
    
    /**
     * @dev Get farmer profile
     * @param farmer Address of the farmer
     * @return Farmer profile data
     */
    function getFarmerProfile(address farmer) external view returns (FarmerProfile memory) {
        require(farmerProfiles[farmer].farmerAddress != address(0), "Farmer not found");
        return farmerProfiles[farmer];
    }
    
    /**
     * @dev Get farmer reputation events
     * @param farmer Address of the farmer
     * @return Array of event IDs
     */
    function getFarmerEvents(address farmer) external view returns (uint256[] memory) {
        return farmerEvents[farmer];
    }
    
    /**
     * @dev Get reputation event details
     * @param eventId Event ID
     * @return Event details
     */
    function getReputationEvent(uint256 eventId) external view returns (ReputationEvent memory) {
        require(reputationEvents[eventId].eventId != 0, "Event not found");
        return reputationEvents[eventId];
    }
    
    /**
     * @dev Get farmer quality metrics
     * @param farmer Address of the farmer
     * @return Quality metrics
     */
    function getFarmerQualityMetrics(address farmer) external view returns (QualityMetrics memory) {
        return farmerQualityMetrics[farmer];
    }
    
    /**
     * @dev Get farmer tier information
     * @param farmer Address of the farmer
     * @return Tier information
     */
    function getFarmerTier(address farmer) external view returns (ReputationTier memory) {
        uint256 tierId = farmerTier[farmer];
        return reputationTiers[tierId];
    }
    
    /**
     * @dev Verify a farmer (only owner)
     * @param farmer Address of the farmer
     * @param verified Whether to verify or revoke verification
     */
    function verifyFarmer(address farmer, bool verified) external onlyOwner {
        require(farmerProfiles[farmer].farmerAddress != address(0), "Farmer not found");
        
        farmerProfiles[farmer].isVerified = verified;
        farmerProfiles[farmer].verificationDate = verified ? block.timestamp : 0;
    }
    
    /**
     * @dev Update farmer statistics (called by other contracts)
     * @param farmer Address of the farmer
     * @param treeCount Number of trees
     * @param harvestCount Number of harvests
     * @param certificationCount Number of certifications
     * @param organicPercentage Percentage of organic produce
     * @param consumerRating Average consumer rating
     */
    function updateFarmerStats(
        address farmer,
        uint256 treeCount,
        uint256 harvestCount,
        uint256 certificationCount,
        uint256 organicPercentage,
        uint256 consumerRating
    ) external onlyOwner {
        require(farmerProfiles[farmer].farmerAddress != address(0), "Farmer not found");
        
        farmerProfiles[farmer].totalTrees = treeCount;
        farmerProfiles[farmer].totalHarvests = harvestCount;
        farmerProfiles[farmer].totalCertifications = certificationCount;
        farmerProfiles[farmer].organicPercentage = organicPercentage;
        farmerProfiles[farmer].consumerRating = consumerRating;
    }
    
    /**
     * @dev Get total number of reputation events
     * @return Total count of events
     */
    function getTotalReputationEvents() external view returns (uint256) {
        return _reputationEventIdCounter;
    }
    
    /**
     * @dev Check if farmer is verified
     * @param farmer Address of the farmer
     * @return True if farmer is verified
     */
    function isFarmerVerified(address farmer) external view returns (bool) {
        return farmerProfiles[farmer].isVerified;
    }
    
    /**
     * @dev Get reputation tier benefits
     * @param tierId Tier ID
     * @return Tier benefits
     */
    function getTierBenefits(uint256 tierId) external view returns (uint256) {
        return reputationTiers[tierId].benefits;
    }
}
