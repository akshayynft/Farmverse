// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Processing
 * @dev Smart contract for tracking food processing, packaging, and quality control
 * Manages processing facilities, methods, and product transformation
 */
contract Processing is Ownable, ReentrancyGuard {
    // Counter for processing event IDs
    uint256 private _processingEventIdCounter;
    
    // Structure for processing facility
    struct ProcessingFacility {
        address facilityAddress;
        string facilityName;
        string location;
        string facilityType; // "Primary", "Secondary", "Packaging", "Distribution"
        bool isCertified;
        uint256 certificationDate;
        string certificationNumber;
        bool isActive;
        uint256 registrationDate;
    }
    
    // Structure for processing event
    struct ProcessingEvent {
        uint256 processingEventId;
        uint256 batchId;
        address facility;
        uint256 startTime;
        uint256 endTime;
        uint256 inputQuantity; // Input quantity in grams
        uint256 outputQuantity; // Output quantity in grams
        string processingMethod; // "Washing", "Sorting", "Packaging", "Freezing", "Drying"
        string packagingType; // "Plastic", "Cardboard", "Glass", "Biodegradable"
        uint256 packageCount; // Number of packages produced
        string packageSize; // Size of each package
        bool qualityPassed;
        string qualityNotes;
        string ipfsHash; // Processing documentation
        uint256 cost; // Processing cost in wei
    }
    
    // Structure for quality control check
    struct QualityCheck {
        uint256 processingEventId;
        uint256 checkTime;
        string checkType; // "Visual", "Microbial", "Chemical", "Physical"
        bool passed;
        string notes;
        address checkedBy;
        string ipfsHash; // Quality check documentation
    }
    
    // Structure for processing statistics
    struct ProcessingStats {
        uint256 totalProcessed;
        uint256 totalOutput;
        uint256 totalWaste;
        uint256 totalCost;
        uint256 qualityPassRate; // Percentage
        uint256 totalEvents;
    }
    
    // Mappings
    mapping(address => ProcessingFacility) public processingFacilities;
    mapping(uint256 => ProcessingEvent) public processingEvents;
    mapping(uint256 => QualityCheck[]) public eventQualityChecks; // processingEventId to quality checks
    mapping(uint256 => uint256[]) public batchProcessingEvents; // batchId to processing event IDs
    mapping(address => uint256[]) public facilityProcessingEvents; // facility to processing event IDs
    mapping(uint256 => ProcessingStats) public batchProcessingStats; // batchId to processing statistics
    mapping(address => bool) public authorizedFacilities; // Authorized processing facilities
    
    // Events
    event FacilityRegistered(address indexed facility, string facilityName);
    event ProcessingStarted(uint256 indexed processingEventId, uint256 indexed batchId, address indexed facility);
    event ProcessingCompleted(uint256 indexed processingEventId, uint256 outputQuantity, bool qualityPassed);
    event QualityCheckPerformed(uint256 indexed processingEventId, string checkType, bool passed);
    event FacilityCertified(address indexed facility, bool certified);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Register a processing facility
     * @param facilityName Name of the facility
     * @param location Facility location
     * @param facilityType Type of facility
     * @param certificationNumber Certification number
     */
    function registerFacility(
        string memory facilityName,
        string memory location,
        string memory facilityType,
        string memory certificationNumber
    ) external {
        require(bytes(facilityName).length > 0, "Facility name cannot be empty");
        require(bytes(location).length > 0, "Location cannot be empty");
        require(bytes(facilityType).length > 0, "Facility type cannot be empty");
        require(processingFacilities[msg.sender].facilityAddress == address(0), "Facility already registered");
        
        ProcessingFacility memory facility = ProcessingFacility({
            facilityAddress: msg.sender,
            facilityName: facilityName,
            location: location,
            facilityType: facilityType,
            isCertified: false,
            certificationDate: 0,
            certificationNumber: certificationNumber,
            isActive: true,
            registrationDate: block.timestamp
        });
        
        processingFacilities[msg.sender] = facility;
        
        emit FacilityRegistered(msg.sender, facilityName);
    }
    
    /**
     * @dev Start processing a batch
     * @param batchId The batch ID to process
     * @param inputQuantity Input quantity in grams
     * @param processingMethod Processing method
     * @param packagingType Packaging type
     * @param packageSize Package size
     * @param ipfsHash Processing documentation
     */
    function startProcessing(
        uint256 batchId,
        uint256 inputQuantity,
        string memory processingMethod,
        string memory packagingType,
        string memory packageSize,
        string memory ipfsHash
    ) external nonReentrant returns (uint256) {
        require(authorizedFacilities[msg.sender] || processingFacilities[msg.sender].isActive, "Not authorized to process");
        require(inputQuantity > 0, "Input quantity must be greater than 0");
        require(bytes(processingMethod).length > 0, "Processing method cannot be empty");
        require(bytes(packagingType).length > 0, "Packaging type cannot be empty");
        require(bytes(packageSize).length > 0, "Package size cannot be empty");
        
        _processingEventIdCounter++;
        uint256 newProcessingEventId = _processingEventIdCounter;
        
        ProcessingEvent memory processingEvent = ProcessingEvent({
            processingEventId: newProcessingEventId,
            batchId: batchId,
            facility: msg.sender,
            startTime: block.timestamp,
            endTime: 0,
            inputQuantity: inputQuantity,
            outputQuantity: 0,
            processingMethod: processingMethod,
            packagingType: packagingType,
            packageCount: 0,
            packageSize: packageSize,
            qualityPassed: false,
            qualityNotes: "",
            ipfsHash: ipfsHash,
            cost: 0
        });
        
        processingEvents[newProcessingEventId] = processingEvent;
        batchProcessingEvents[batchId].push(newProcessingEventId);
        facilityProcessingEvents[msg.sender].push(newProcessingEventId);
        
        emit ProcessingStarted(newProcessingEventId, batchId, msg.sender);
        
        return newProcessingEventId;
    }
    
    /**
     * @dev Complete processing with output details
     * @param processingEventId Processing event ID
     * @param outputQuantity Output quantity in grams
     * @param packageCount Number of packages produced
     * @param qualityPassed Whether quality check passed
     * @param qualityNotes Quality notes
     * @param cost Processing cost
     */
    function completeProcessing(
        uint256 processingEventId,
        uint256 outputQuantity,
        uint256 packageCount,
        bool qualityPassed,
        string memory qualityNotes,
        uint256 cost
    ) external nonReentrant {
        require(processingEvents[processingEventId].facility == msg.sender, "Only processing facility can complete");
        require(processingEvents[processingEventId].endTime == 0, "Processing already completed");
        require(outputQuantity > 0, "Output quantity must be greater than 0");
        require(packageCount > 0, "Package count must be greater than 0");
        
        ProcessingEvent storage event_ = processingEvents[processingEventId];
        event_.endTime = block.timestamp;
        event_.outputQuantity = outputQuantity;
        event_.packageCount = packageCount;
        event_.qualityPassed = qualityPassed;
        event_.qualityNotes = qualityNotes;
        event_.cost = cost;
        
        // Update processing statistics
        updateProcessingStats(event_.batchId, event_.inputQuantity, outputQuantity, cost, qualityPassed);
        
        emit ProcessingCompleted(processingEventId, outputQuantity, qualityPassed);
    }
    
    /**
     * @dev Perform quality control check
     * @param processingEventId Processing event ID
     * @param checkType Type of quality check
     * @param passed Whether check passed
     * @param notes Quality check notes
     * @param ipfsHash Quality check documentation
     */
    function performQualityCheck(
        uint256 processingEventId,
        string memory checkType,
        bool passed,
        string memory notes,
        string memory ipfsHash
    ) external {
        require(authorizedFacilities[msg.sender] || processingFacilities[msg.sender].isActive, "Not authorized to perform quality checks");
        require(bytes(checkType).length > 0, "Check type cannot be empty");
        
        QualityCheck memory qualityCheck = QualityCheck({
            processingEventId: processingEventId,
            checkTime: block.timestamp,
            checkType: checkType,
            passed: passed,
            notes: notes,
            checkedBy: msg.sender,
            ipfsHash: ipfsHash
        });
        
        eventQualityChecks[processingEventId].push(qualityCheck);
        
        emit QualityCheckPerformed(processingEventId, checkType, passed);
    }
    
    /**
     * @dev Update processing statistics
     * @param batchId Batch ID
     * @param inputQuantity Input quantity
     * @param outputQuantity Output quantity
     * @param cost Processing cost
     * @param qualityPassed Whether quality passed
     */
    function updateProcessingStats(
        uint256 batchId,
        uint256 inputQuantity,
        uint256 outputQuantity,
        uint256 cost,
        bool qualityPassed
    ) internal {
        ProcessingStats storage stats = batchProcessingStats[batchId];
        
        stats.totalProcessed += inputQuantity;
        stats.totalOutput += outputQuantity;
        stats.totalWaste += (inputQuantity - outputQuantity);
        stats.totalCost += cost;
        stats.totalEvents += 1;
        
        // Calculate quality pass rate
        uint256 totalChecks = stats.totalEvents;
        uint256 passedChecks = qualityPassed ? totalChecks : (totalChecks - 1);
        stats.qualityPassRate = (passedChecks * 100) / totalChecks;
    }
    
    /**
     * @dev Certify a processing facility
     * @param facility Facility address
     * @param certified Whether to certify
     */
    function certifyFacility(address facility, bool certified) external onlyOwner {
        require(processingFacilities[facility].facilityAddress != address(0), "Facility not found");
        
        processingFacilities[facility].isCertified = certified;
        processingFacilities[facility].certificationDate = certified ? block.timestamp : 0;
        
        emit FacilityCertified(facility, certified);
    }
    
    /**
     * @dev Authorize a processing facility
     * @param facility Facility address
     * @param authorized Whether to authorize
     */
    function authorizeFacility(address facility, bool authorized) external onlyOwner {
        authorizedFacilities[facility] = authorized;
    }
    
    /**
     * @dev Get processing events for a batch
     * @param batchId Batch ID
     * @return Array of processing event IDs
     */
    function getBatchProcessingEvents(uint256 batchId) external view returns (uint256[] memory) {
        return batchProcessingEvents[batchId];
    }
    
    /**
     * @dev Get processing event details
     * @param processingEventId Processing event ID
     * @return Processing event details
     */
    function getProcessingEvent(uint256 processingEventId) external view returns (ProcessingEvent memory) {
        require(processingEvents[processingEventId].processingEventId != 0, "Processing event does not exist");
        return processingEvents[processingEventId];
    }
    
    /**
     * @dev Get quality checks for a processing event
     * @param processingEventId Processing event ID
     * @return Array of quality checks
     */
    function getEventQualityChecks(uint256 processingEventId) external view returns (QualityCheck[] memory) {
        return eventQualityChecks[processingEventId];
    }
    
    /**
     * @dev Get processing statistics for a batch
     * @param batchId Batch ID
     * @return Processing statistics
     */
    function getBatchProcessingStats(uint256 batchId) external view returns (ProcessingStats memory) {
        return batchProcessingStats[batchId];
    }
    
    /**
     * @dev Get facility details
     * @param facility Facility address
     * @return Facility details
     */
    function getFacility(address facility) external view returns (ProcessingFacility memory) {
        require(processingFacilities[facility].facilityAddress != address(0), "Facility not found");
        return processingFacilities[facility];
    }
    
    /**
     * @dev Calculate processing efficiency
     * @param processingEventId Processing event ID
     * @return Efficiency percentage (0-100)
     */
    function calculateProcessingEfficiency(uint256 processingEventId) external view returns (uint256) {
        ProcessingEvent memory event_ = processingEvents[processingEventId];
        require(event_.processingEventId != 0, "Processing event does not exist");
        require(event_.inputQuantity > 0, "Input quantity must be greater than 0");
        
        return (event_.outputQuantity * 100) / event_.inputQuantity;
    }
    
    /**
     * @dev Get total processing events
     * @return Total count of processing events
     */
    function getTotalProcessingEvents() external view returns (uint256) {
        return _processingEventIdCounter;
    }
    
    /**
     * @dev Check if facility is authorized
     * @param facility Facility address
     * @return True if authorized
     */
    function isFacilityAuthorized(address facility) external view returns (bool) {
        return authorizedFacilities[facility] || processingFacilities[facility].isActive;
    }
}
