// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Harvest
 * @dev Smart contract for tracking harvest data and quality metrics
 * Links harvests to TreeIDs for complete traceability
 */
contract Harvest is Ownable {
    // Counter for harvest IDs
    uint256 private _harvestIdCounter;
    
    // Structure for harvest data
    struct HarvestData {
        uint256 harvestId;
        uint256 treeId;
        address farmer;
        uint256 harvestDate;
        uint256 quantity; // in grams
        string qualityGrade; // "A", "B", "C", "Premium"
        uint256 ripenessLevel; // 1-10 scale
        bool isOrganic;
        string harvestMethod; // "Manual", "Mechanical"
        string ipfsHash; // For storing harvest images and details
        bool isProcessed;
        uint256 processingDate;
        string processingNotes;
    }
    
    // Structure for quality metrics
    struct QualityMetrics {
        uint256 harvestId;
        uint256 size; // Average size in mm
        uint256 sweetness; // Brix scale 1-20
        uint256 firmness; // 1-10 scale
        uint256 colorScore; // 1-10 scale
        uint256 defectPercentage; // 0-100
        bool meetsExportStandards;
        string qualityNotes;
    }
    
    // Structure for ripening data
    struct RipeningData {
        uint256 harvestId;
        string ripeningMethod; // "Natural", "Ethylene", "Carbide-Free"
        uint256 ripeningDuration; // in hours
        uint256 temperature; // in Celsius
        uint256 humidity; // percentage
        bool isArtificiallyRipened;
        string ripeningNotes;
    }
    
    // Mappings
    mapping(uint256 => HarvestData) public harvests;
    mapping(uint256 => QualityMetrics) public qualityMetrics;
    mapping(uint256 => RipeningData) public ripeningData;
    mapping(uint256 => uint256[]) public treeHarvests; // TreeID to harvest IDs
    mapping(address => uint256[]) public farmerHarvests; // Farmer to harvest IDs
    
    // Events
    event HarvestRecorded(uint256 indexed harvestId, uint256 indexed treeId, uint256 quantity);
    event QualityMetricsRecorded(uint256 indexed harvestId, string qualityGrade);
    event RipeningDataRecorded(uint256 indexed harvestId, string ripeningMethod);
    event HarvestProcessed(uint256 indexed harvestId, uint256 processingDate);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Record a new harvest
     * @param treeId The TreeID being harvested
     * @param quantity Harvest quantity in grams
     * @param qualityGrade Quality grade of the harvest
     * @param ripenessLevel Ripeness level (1-10)
     * @param isOrganic Whether the harvest is organic
     * @param harvestMethod Method used for harvesting
     * @param ipfsHash IPFS hash for harvest images and details
     */
    function recordHarvest(
        uint256 treeId,
        uint256 quantity,
        string memory qualityGrade,
        uint256 ripenessLevel,
        bool isOrganic,
        string memory harvestMethod,
        string memory ipfsHash
    ) external returns (uint256) {
        require(quantity > 0, "Quantity must be greater than 0");
        require(bytes(qualityGrade).length > 0, "Quality grade cannot be empty");
        require(ripenessLevel >= 1 && ripenessLevel <= 10, "Ripeness level must be 1-10");
        require(bytes(harvestMethod).length > 0, "Harvest method cannot be empty");
        
        _harvestIdCounter++;
        uint256 newHarvestId = _harvestIdCounter;
        
        HarvestData memory newHarvest = HarvestData({
            harvestId: newHarvestId,
            treeId: treeId,
            farmer: msg.sender,
            harvestDate: block.timestamp,
            quantity: quantity,
            qualityGrade: qualityGrade,
            ripenessLevel: ripenessLevel,
            isOrganic: isOrganic,
            harvestMethod: harvestMethod,
            ipfsHash: ipfsHash,
            isProcessed: false,
            processingDate: 0,
            processingNotes: ""
        });
        
        harvests[newHarvestId] = newHarvest;
        treeHarvests[treeId].push(newHarvestId);
        farmerHarvests[msg.sender].push(newHarvestId);
        
        emit HarvestRecorded(newHarvestId, treeId, quantity);
        
        return newHarvestId;
    }
    
    /**
     * @dev Record quality metrics for a harvest
     * @param harvestId The harvest ID
     * @param size Average size in mm
     * @param sweetness Sweetness on Brix scale (1-20)
     * @param firmness Firmness scale (1-10)
     * @param colorScore Color score (1-10)
     * @param defectPercentage Percentage of defects (0-100)
     * @param meetsExportStandards Whether it meets export standards
     * @param qualityNotes Additional quality notes
     */
    function recordQualityMetrics(
        uint256 harvestId,
        uint256 size,
        uint256 sweetness,
        uint256 firmness,
        uint256 colorScore,
        uint256 defectPercentage,
        bool meetsExportStandards,
        string memory qualityNotes
    ) external {
        require(harvests[harvestId].farmer == msg.sender, "Only harvest owner can record quality metrics");
        require(harvests[harvestId].harvestId != 0, "Harvest does not exist");
        require(sweetness >= 1 && sweetness <= 20, "Sweetness must be 1-20");
        require(firmness >= 1 && firmness <= 10, "Firmness must be 1-10");
        require(colorScore >= 1 && colorScore <= 10, "Color score must be 1-10");
        require(defectPercentage <= 100, "Defect percentage cannot exceed 100");
        
        QualityMetrics memory metrics = QualityMetrics({
            harvestId: harvestId,
            size: size,
            sweetness: sweetness,
            firmness: firmness,
            colorScore: colorScore,
            defectPercentage: defectPercentage,
            meetsExportStandards: meetsExportStandards,
            qualityNotes: qualityNotes
        });
        
        qualityMetrics[harvestId] = metrics;
        
        emit QualityMetricsRecorded(harvestId, harvests[harvestId].qualityGrade);
    }
    
    /**
     * @dev Record ripening data
     * @param harvestId The harvest ID
     * @param ripeningMethod Method used for ripening
     * @param ripeningDuration Duration in hours
     * @param temperature Temperature in Celsius
     * @param humidity Humidity percentage
     * @param isArtificiallyRipened Whether artificially ripened
     * @param ripeningNotes Additional ripening notes
     */
    function recordRipeningData(
        uint256 harvestId,
        string memory ripeningMethod,
        uint256 ripeningDuration,
        uint256 temperature,
        uint256 humidity,
        bool isArtificiallyRipened,
        string memory ripeningNotes
    ) external {
        require(harvests[harvestId].farmer == msg.sender, "Only harvest owner can record ripening data");
        require(harvests[harvestId].harvestId != 0, "Harvest does not exist");
        require(bytes(ripeningMethod).length > 0, "Ripening method cannot be empty");
        require(temperature >= 0 && temperature <= 50, "Temperature must be 0-50 Celsius");
        require(humidity <= 100, "Humidity cannot exceed 100%");
        
        RipeningData memory ripening = RipeningData({
            harvestId: harvestId,
            ripeningMethod: ripeningMethod,
            ripeningDuration: ripeningDuration,
            temperature: temperature,
            humidity: humidity,
            isArtificiallyRipened: isArtificiallyRipened,
            ripeningNotes: ripeningNotes
        });
        
        ripeningData[harvestId] = ripening;
        
        emit RipeningDataRecorded(harvestId, ripeningMethod);
    }
    
    /**
     * @dev Mark harvest as processed
     * @param harvestId The harvest ID
     * @param processingNotes Notes about processing
     */
    function markAsProcessed(uint256 harvestId, string memory processingNotes) external {
        require(harvests[harvestId].farmer == msg.sender, "Only harvest owner can mark as processed");
        require(harvests[harvestId].harvestId != 0, "Harvest does not exist");
        require(!harvests[harvestId].isProcessed, "Harvest is already processed");
        
        harvests[harvestId].isProcessed = true;
        harvests[harvestId].processingDate = block.timestamp;
        harvests[harvestId].processingNotes = processingNotes;
        
        emit HarvestProcessed(harvestId, block.timestamp);
    }
    
    /**
     * @dev Get harvest details
     * @param harvestId The harvest ID
     * @return Complete harvest data
     */
    function getHarvest(uint256 harvestId) external view returns (HarvestData memory) {
        require(harvests[harvestId].harvestId != 0, "Harvest does not exist");
        return harvests[harvestId];
    }
    
    /**
     * @dev Get quality metrics for a harvest
     * @param harvestId The harvest ID
     * @return Quality metrics data
     */
    function getQualityMetrics(uint256 harvestId) external view returns (QualityMetrics memory) {
        require(qualityMetrics[harvestId].harvestId != 0, "Quality metrics do not exist");
        return qualityMetrics[harvestId];
    }
    
    /**
     * @dev Get ripening data for a harvest
     * @param harvestId The harvest ID
     * @return Ripening data
     */
    function getRipeningData(uint256 harvestId) external view returns (RipeningData memory) {
        require(ripeningData[harvestId].harvestId != 0, "Ripening data does not exist");
        return ripeningData[harvestId];
    }
    
    /**
     * @dev Get all harvests for a tree
     * @param treeId The TreeID to query
     * @return Array of harvest IDs
     */
    function getTreeHarvests(uint256 treeId) external view returns (uint256[] memory) {
        return treeHarvests[treeId];
    }
    
    /**
     * @dev Get all harvests for a farmer
     * @param farmer Address of the farmer
     * @return Array of harvest IDs
     */
    function getFarmerHarvests(address farmer) external view returns (uint256[] memory) {
        return farmerHarvests[farmer];
    }
    
    /**
     * @dev Get total harvest quantity for a tree
     * @param treeId The TreeID to query
     * @return Total quantity harvested in grams
     */
    function getTotalTreeHarvestQuantity(uint256 treeId) external view returns (uint256) {
        uint256[] memory harvestIds = treeHarvests[treeId];
        uint256 totalQuantity = 0;
        
        for (uint256 i = 0; i < harvestIds.length; i++) {
            totalQuantity += harvests[harvestIds[i]].quantity;
        }
        
        return totalQuantity;
    }
    
    /**
     * @dev Check if harvest is organic
     * @param harvestId The harvest ID
     * @return True if harvest is marked as organic
     */
    function isHarvestOrganic(uint256 harvestId) external view returns (bool) {
        require(harvests[harvestId].harvestId != 0, "Harvest does not exist");
        return harvests[harvestId].isOrganic;
    }
    
    /**
     * @dev Get harvest statistics for a farmer
     * @param farmer Address of the farmer
     * @return totalHarvests Total number of harvests
     * @return totalQuantity Total quantity harvested in grams
     * @return organicHarvests Number of organic harvests
     */
    function getFarmerHarvestStats(address farmer) external view returns (
        uint256 totalHarvests,
        uint256 totalQuantity,
        uint256 organicHarvests
    ) {
        uint256[] memory harvestIds = farmerHarvests[farmer];
        
        for (uint256 i = 0; i < harvestIds.length; i++) {
            HarvestData memory harvest = harvests[harvestIds[i]];
            totalQuantity += harvest.quantity;
            if (harvest.isOrganic) {
                organicHarvests++;
            }
        }
        
        totalHarvests = harvestIds.length;
    }
    
    /**
     * @dev Get total number of harvests
     * @return Total count of harvests
     */
    function getTotalHarvests() external view returns (uint256) {
        return _harvestIdCounter;
    }
} 