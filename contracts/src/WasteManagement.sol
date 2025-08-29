// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title WasteManagement
 * @dev Smart contract for tracking waste at each stage of the supply chain
 * Provides detailed waste categorization, reporting, and sustainability metrics
 */
contract WasteManagement is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    // Counter for waste event IDs
    Counters.Counter private _wasteEventIdCounter;
    
    // Structure for waste event
    struct WasteEvent {
        uint256 wasteEventId;
        uint256 batchId;
        address reportedBy;
        uint256 timestamp;
        uint256 quantity; // Waste quantity in grams
        string stage; // "Harvest", "Processing", "Transport", "Storage", "Retail"
        string wasteType; // "Damaged", "Overripe", "Spoiled", "Defective", "Expired"
        string reason; // Reason for waste
        string disposalMethod; // "Compost", "Animal_Feed", "Landfill", "Recycling"
        bool isRecycled;
        string ipfsHash; // Waste documentation and photos
        uint256 cost; // Cost of waste in wei
    }
    
    // Structure for waste statistics
    struct WasteStats {
        uint256 totalWasteQuantity;
        uint256 totalWasteCost;
        uint256 recycledQuantity;
        uint256 compostedQuantity;
        uint256 landfillQuantity;
        uint256 animalFeedQuantity;
        uint256 totalEvents;
    }
    
    // Structure for stage waste tracking
    struct StageWaste {
        string stage;
        uint256 totalWaste;
        uint256 wastePercentage; // Percentage of total input
        uint256 cost;
        uint256 events;
    }
    
    // Mappings
    mapping(uint256 => WasteEvent) public wasteEvents;
    mapping(uint256 => uint256[]) public batchWasteEvents; // batchId to waste event IDs
    mapping(address => uint256[]) public reporterWasteEvents; // reporter to waste event IDs
    mapping(uint256 => WasteStats) public batchWasteStats; // batchId to waste statistics
    mapping(string => StageWaste) public stageWasteStats; // stage to waste statistics
    mapping(address => bool) public authorizedReporters; // Who can report waste
    
    // Events
    event WasteReported(uint256 indexed wasteEventId, uint256 indexed batchId, string stage, uint256 quantity);
    event WasteRecycled(uint256 indexed wasteEventId, string disposalMethod);
    event WasteStatsUpdated(uint256 indexed batchId, uint256 totalWaste, uint256 recycledQuantity);
    event ReporterAuthorized(address indexed reporter, bool authorized);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Report waste at a specific stage
     * @param batchId The batch ID
     * @param quantity Waste quantity in grams
     * @param stage Stage where waste occurred
     * @param wasteType Type of waste
     * @param reason Reason for waste
     * @param disposalMethod How waste was disposed
     * @param isRecycled Whether waste was recycled
     * @param ipfsHash Waste documentation
     * @param cost Cost of waste
     */
    function reportWaste(
        uint256 batchId,
        uint256 quantity,
        string memory stage,
        string memory wasteType,
        string memory reason,
        string memory disposalMethod,
        bool isRecycled,
        string memory ipfsHash,
        uint256 cost
    ) external nonReentrant returns (uint256) {
        require(authorizedReporters[msg.sender] || msg.sender == owner(), "Not authorized to report waste");
        require(quantity > 0, "Waste quantity must be greater than 0");
        require(bytes(stage).length > 0, "Stage cannot be empty");
        require(bytes(wasteType).length > 0, "Waste type cannot be empty");
        require(bytes(reason).length > 0, "Reason cannot be empty");
        require(bytes(disposalMethod).length > 0, "Disposal method cannot be empty");
        
        _wasteEventIdCounter.increment();
        uint256 newWasteEventId = _wasteEventIdCounter.current();
        
        WasteEvent memory wasteEvent = WasteEvent({
            wasteEventId: newWasteEventId,
            batchId: batchId,
            reportedBy: msg.sender,
            timestamp: block.timestamp,
            quantity: quantity,
            stage: stage,
            wasteType: wasteType,
            reason: reason,
            disposalMethod: disposalMethod,
            isRecycled: isRecycled,
            ipfsHash: ipfsHash,
            cost: cost
        });
        
        wasteEvents[newWasteEventId] = wasteEvent;
        batchWasteEvents[batchId].push(newWasteEventId);
        reporterWasteEvents[msg.sender].push(newWasteEventId);
        
        // Update batch waste statistics
        updateBatchWasteStats(batchId, quantity, isRecycled, cost);
        
        // Update stage waste statistics
        updateStageWasteStats(stage, quantity, cost);
        
        emit WasteReported(newWasteEventId, batchId, stage, quantity);
        
        if (isRecycled) {
            emit WasteRecycled(newWasteEventId, disposalMethod);
        }
        
        return newWasteEventId;
    }
    
    /**
     * @dev Update batch waste statistics
     * @param batchId Batch ID
     * @param quantity Waste quantity
     * @param isRecycled Whether recycled
     * @param cost Waste cost
     */
    function updateBatchWasteStats(uint256 batchId, uint256 quantity, bool isRecycled, uint256 cost) internal {
        WasteStats storage stats = batchWasteStats[batchId];
        
        stats.totalWasteQuantity += quantity;
        stats.totalWasteCost += cost;
        stats.totalEvents += 1;
        
        if (isRecycled) {
            stats.recycledQuantity += quantity;
        }
        
        emit WasteStatsUpdated(batchId, stats.totalWasteQuantity, stats.recycledQuantity);
    }
    
    /**
     * @dev Update stage waste statistics
     * @param stage Stage name
     * @param quantity Waste quantity
     * @param cost Waste cost
     */
    function updateStageWasteStats(string memory stage, uint256 quantity, uint256 cost) internal {
        StageWaste storage stageStats = stageWasteStats[stage];
        
        stageStats.stage = stage;
        stageStats.totalWaste += quantity;
        stageStats.cost += cost;
        stageStats.events += 1;
        
        // Calculate waste percentage (would need total input quantity)
        // For now, we'll track it separately
    }
    
    /**
     * @dev Get waste events for a batch
     * @param batchId Batch ID
     * @return Array of waste event IDs
     */
    function getBatchWasteEvents(uint256 batchId) external view returns (uint256[] memory) {
        return batchWasteEvents[batchId];
    }
    
    /**
     * @dev Get waste event details
     * @param wasteEventId Waste event ID
     * @return Waste event details
     */
    function getWasteEvent(uint256 wasteEventId) external view returns (WasteEvent memory) {
        require(wasteEvents[wasteEventId].wasteEventId != 0, "Waste event does not exist");
        return wasteEvents[wasteEventId];
    }
    
    /**
     * @dev Get waste statistics for a batch
     * @param batchId Batch ID
     * @return Waste statistics
     */
    function getBatchWasteStats(uint256 batchId) external view returns (WasteStats memory) {
        return batchWasteStats[batchId];
    }
    
    /**
     * @dev Get stage waste statistics
     * @param stage Stage name
     * @return Stage waste statistics
     */
    function getStageWasteStats(string memory stage) external view returns (StageWaste memory) {
        return stageWasteStats[stage];
    }
    
    /**
     * @dev Calculate waste percentage for a batch
     * @param batchId Batch ID
     * @param totalInputQuantity Total input quantity for the batch
     * @return Waste percentage (0-100)
     */
    function calculateWastePercentage(uint256 batchId, uint256 totalInputQuantity) external view returns (uint256) {
        require(totalInputQuantity > 0, "Total input quantity must be greater than 0");
        
        WasteStats memory stats = batchWasteStats[batchId];
        return (stats.totalWasteQuantity * 100) / totalInputQuantity;
    }
    
    /**
     * @dev Get sustainability metrics
     * @param batchId Batch ID
     * @return recycledPercentage Percentage of waste recycled
     * @return totalWaste Total waste quantity
     * @return totalCost Total waste cost
     */
    function getSustainabilityMetrics(uint256 batchId) external view returns (
        uint256 recycledPercentage,
        uint256 totalWaste,
        uint256 totalCost
    ) {
        WasteStats memory stats = batchWasteStats[batchId];
        
        totalWaste = stats.totalWasteQuantity;
        totalCost = stats.totalWasteCost;
        
        if (totalWaste > 0) {
            recycledPercentage = (stats.recycledQuantity * 100) / totalWaste;
        } else {
            recycledPercentage = 0;
        }
        
        return (recycledPercentage, totalWaste, totalCost);
    }
    
    /**
     * @dev Authorize waste reporter
     * @param reporter Address to authorize
     * @param authorized Whether to authorize
     */
    function authorizeReporter(address reporter, bool authorized) external onlyOwner {
        authorizedReporters[reporter] = authorized;
        emit ReporterAuthorized(reporter, authorized);
    }
    
    /**
     * @dev Get total waste events
     * @return Total count of waste events
     */
    function getTotalWasteEvents() external view returns (uint256) {
        return _wasteEventIdCounter.current();
    }
    
    /**
     * @dev Get waste events by reporter
     * @param reporter Reporter address
     * @return Array of waste event IDs
     */
    function getReporterWasteEvents(address reporter) external view returns (uint256[] memory) {
        return reporterWasteEvents[reporter];
    }
    
    /**
     * @dev Check if address is authorized to report waste
     * @param reporter Reporter address
     * @return True if authorized
     */
    function isReporterAuthorized(address reporter) external view returns (bool) {
        return authorizedReporters[reporter] || reporter == owner();
    }
}
