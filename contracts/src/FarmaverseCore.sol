// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./TreeID.sol";
import "./Certification.sol";
import "./Harvest.sol";
import "./SupplyChain.sol";
import "./ConsumerVerification.sol";
import "./FarmerReputation.sol";
import "./WasteManagement.sol";
import "./Processing.sol";

/**
 * @title FarmaverseCore - Complete Farm-to-Fork Traceability System
 * @author Farmaverse Development Team
 * @notice Master contract integrating all Farmaverse modules with unified interface
 * @dev Implements AccessControl, ReentrancyGuard, and Pausable for enterprise security
 * 
 * SYSTEM ARCHITECTURE:
 * - Tree Registration & Management (TreeID)
 * - 3-Pathway Certification (Certification) 
 * - Harvest & Quality Tracking (Harvest)
 * - Supply Chain & Ownership (SupplyChain)
 * - Consumer Verification (ConsumerVerification)
 * - Farmer Reputation System (FarmerReputation)
 * - Waste Management & Sustainability (WasteManagement)
 * - Processing & Packaging (Processing)
 * 
 * SECURITY FEATURES:
 * - Role-based access control (RBAC)
 * - Reentrancy protection on all state-changing functions
 * - Emergency circuit breaker (Pausable)
 * - Comprehensive input validation
 * - Gas optimization patterns
 * 
 * @custom:security-contact security@farmaverse.com
 */
contract FarmaverseCore is AccessControl, ReentrancyGuard, Pausable {
    
    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Role for system administrators with full access
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    /// @notice Role for farmers who can register trees and harvests
    bytes32 public constant FARMER_ROLE = keccak256("FARMER_ROLE");
    
    /// @notice Role for verifiers who validate certificates and practices
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    /// @notice Role for supply chain participants (distributors, retailers)
    bytes32 public constant SUPPLY_CHAIN_ROLE = keccak256("SUPPLY_CHAIN_ROLE");
    
    /// @notice Role for consumers who can verify products
    bytes32 public constant CONSUMER_ROLE = keccak256("CONSUMER_ROLE");
    
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    // Contract instances
    TreeID public treeIDContract;
    Certification public certificationContract;
    Harvest public harvestContract;
    SupplyChain public supplyChainContract;
    ConsumerVerification public consumerVerificationContract;
    FarmerReputation public farmerReputationContract;
    WasteManagement public wasteManagementContract;
    Processing public processingContract;
    
    // Contract addresses
    address public treeIDAddress;
    address public certificationAddress;
    address public harvestAddress;
    address public supplyChainAddress;
    address public consumerVerificationAddress;
    address public farmerReputationAddress;
    address public wasteManagementAddress;
    address public processingAddress;
    
    // System constants
    uint256 public constant MAX_BATCH_SIZE = 50;
    uint256 public constant MAX_STRING_LENGTH = 500;
    uint256 public constant MIN_HARVEST_QUANTITY = 100; // grams
    
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event ContractsDeployed(
        address indexed treeID,
        address indexed certification,
        address indexed harvest,
        address supplyChain,
        address consumerVerification,
        address farmerReputation,
        address wasteManagement,
        address processing
    );
    
    event FarmRegistered(
        address indexed farmer,
        uint256 indexed treeId,
        string location,
        string cropType
    );
    
    event HarvestCompleted(
        address indexed farmer,
        uint256 indexed treeId,
        uint256 indexed harvestId,
        uint256 quantity,
        string qualityGrade
    );
    
    event CertificationCompleted(
        address indexed farmer,
        uint256 indexed treeId,
        uint256 indexed certificationId,
        string certificationType
    );
    
    event CertificateUploaded(
        address indexed farmer,
        uint256 indexed treeId,
        uint256 indexed certId,
        Certification.CertificationSource source
    );
    
    event TransitionStarted(
        address indexed farmer,
        uint256 indexed treeId,
        uint256 indexed transitionId,
        uint256 targetDate
    );
    
    event PracticeLogged(
        address indexed farmer,
        uint256 indexed treeId,
        uint256 indexed logId,
        Certification.PracticeType practiceType
    );
    
    event BatchCreated(
        uint256 indexed batchId,
        address indexed creator,
        uint256[] harvestIds,
        string batchCode
    );
    
    event CompleteTraceabilityCreated(
        uint256 indexed treeId,
        uint256 indexed harvestId,
        uint256 indexed batchId,
        address farmer
    );
    
    event FarmerRegistrationFailed(address indexed farmer, string reason);
    
    event SystemPaused(address indexed pauser);
    event SystemUnpaused(address indexed unpauser);
    
    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Validates string input length
     * @dev Prevents gas exhaustion attacks
     * @param str String to validate
     */
    modifier validString(string memory str) {
        require(
            bytes(str).length > 0 && bytes(str).length <= MAX_STRING_LENGTH,
            "Invalid string length"
        );
        _;
    }
    
    /**
     * @notice Validates array length
     * @dev Prevents gas limit issues
     * @param array Array to validate
     */
    modifier validArrayLength(uint256[] memory array) {
        require(array.length > 0 && array.length <= MAX_BATCH_SIZE, "Invalid array length");
        _;
    }
    
    /**
     * @notice Validates harvest quantity
     * @dev Ensures meaningful harvest quantities
     * @param quantity Harvest quantity in grams
     */
    modifier validQuantity(uint256 quantity) {
        require(quantity >= MIN_HARVEST_QUANTITY, "Quantity below minimum");
        _;
    }
    
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Initializes the FarmaverseCore contract
     * @dev Sets up default admin role and deploys contract instances
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    /*//////////////////////////////////////////////////////////////
                    CONTRACT MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Set contract addresses after deployment
     * @dev Only admin can set contract addresses
     * @param _treeID TreeID contract address
     * @param _certification Certification contract address
     * @param _harvest Harvest contract address
     * @param _supplyChain SupplyChain contract address
     * @param _consumerVerification ConsumerVerification contract address
     * @param _farmerReputation FarmerReputation contract address
     * @param _wasteManagement WasteManagement contract address
     * @param _processing Processing contract address
     */
    function setContractAddresses(
        address _treeID,
        address _certification,
        address _harvest,
        address _supplyChain,
        address _consumerVerification,
        address _farmerReputation,
        address _wasteManagement,
        address _processing
    ) external onlyRole(ADMIN_ROLE) {
        require(_treeID != address(0), "Invalid TreeID address");
        require(_certification != address(0), "Invalid Certification address");
        require(_harvest != address(0), "Invalid Harvest address");
        require(_supplyChain != address(0), "Invalid SupplyChain address");
        require(_consumerVerification != address(0), "Invalid ConsumerVerification address");
        require(_farmerReputation != address(0), "Invalid FarmerReputation address");
        require(_wasteManagement != address(0), "Invalid WasteManagement address");
        require(_processing != address(0), "Invalid Processing address");
        
        // Set addresses
        treeIDAddress = _treeID;
        certificationAddress = _certification;
        harvestAddress = _harvest;
        supplyChainAddress = _supplyChain;
        consumerVerificationAddress = _consumerVerification;
        farmerReputationAddress = _farmerReputation;
        wasteManagementAddress = _wasteManagement;
        processingAddress = _processing;
        
        // Initialize contract instances
        treeIDContract = TreeID(_treeID);
        certificationContract = Certification(_certification);
        harvestContract = Harvest(_harvest);
        supplyChainContract = SupplyChain(_supplyChain);
        consumerVerificationContract = ConsumerVerification(_consumerVerification);
        farmerReputationContract = FarmerReputation(_farmerReputation);
        wasteManagementContract = WasteManagement(_wasteManagement);
        processingContract = Processing(_processing);
        
        // Set up contract dependencies
        try supplyChainContract.setHarvestContract(_harvest) {
            // Success
        } catch {
            revert("Failed to set harvest contract in supply chain");
        }
        
        emit ContractsDeployed(
            _treeID,
            _certification,
            _harvest,
            _supplyChain,
            _consumerVerification,
            _farmerReputation,
            _wasteManagement,
            _processing
        );
    }
    
    /*//////////////////////////////////////////////////////////////
                    FARM REGISTRATION & MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Complete farm registration process
     * @dev Registers tree and farmer in reputation system
     * @param location Tree location
     * @param cropType Type of crop
     * @param plantingDate Planting date
     * @param treeIpfsHash Tree metadata IPFS hash
     * @param farmerName Farmer name
     * @param farmerLocation Farmer location
     * @param farmerIpfsHash Farmer profile IPFS hash
     * @return treeId Registered tree ID
     */
    function registerFarm(
        string memory location,
        string memory cropType,
        uint256 plantingDate,
        string memory treeIpfsHash,
        string memory farmerName,
        string memory farmerLocation,
        string memory farmerIpfsHash
    ) external nonReentrant whenNotPaused returns (uint256 treeId) {
        // Input validation
        require(bytes(location).length > 0, "Location cannot be empty");
        require(bytes(cropType).length > 0, "Crop type cannot be empty");
        require(plantingDate <= block.timestamp, "Planting date cannot be in future");
        require(bytes(treeIpfsHash).length > 0, "Tree IPFS hash cannot be empty");
        require(bytes(farmerName).length > 0, "Farmer name cannot be empty");
        require(bytes(farmerLocation).length > 0, "Farmer location cannot be empty");
        require(bytes(farmerIpfsHash).length > 0, "Farmer IPFS hash cannot be empty");
        
        // Create Tree struct for registration
        TreeID.Tree memory treeData = TreeID.Tree({
            treeId: 0, // Will be set by registerTree
            farmerAddress: msg.sender,
            location: location,
            variety: cropType,
            plantingDate: plantingDate,
            expectedHarvestDate: 0, // Can be set later
            organicCertified: false, // Can be updated later
            irrigationType: "", // Can be set later
            soilType: "", // Can be set later
            coordinates: "", // Can be set later
            isActive: true,
            reputation: 0,
            ipfsHash: treeIpfsHash
        });
        
        // Register tree
        treeId = treeIDContract.registerTree(treeData);
        
        // Register farmer in reputation system
        try farmerReputationContract.registerFarmer(farmerName, farmerLocation, farmerIpfsHash) {
            // Grant farmer role upon successful registration
            _grantRole(FARMER_ROLE, msg.sender);
        } catch Error(string memory reason) {
            // Log the error but continue (tree registration succeeded)
            emit FarmerRegistrationFailed(msg.sender, reason);
        } catch {
            // Handle any other errors
            emit FarmerRegistrationFailed(msg.sender, "Unknown error during farmer registration");
        }
        
        emit FarmRegistered(msg.sender, treeId, location, cropType);
        
        return treeId;
    }
    
    /*//////////////////////////////////////////////////////////////
                    CERTIFICATION PATHWAYS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice PATHWAY 1: Upload existing certificate (NPOP, USDA, EU, etc.)
     * @dev Farmer uploads certificate for platform verification
     * @param treeId Tree ID to certify
     * @param certType Type of certification
     * @param authorityName Certifying authority name
     * @param certificateNumber Official certificate number
     * @param issueDate Certificate issue date
     * @param expiryDate Certificate expiry date
     * @param certificateDocHash IPFS hash of certificate document
     * @param supportingDocsHash IPFS hash of supporting documents
     * @return certId Uploaded certificate ID
     */
    function uploadFarmerCertificate(
        uint256 treeId,
        Certification.CertificationType certType,
        string memory authorityName,
        string memory certificateNumber,
        uint256 issueDate,
        uint256 expiryDate,
        string memory certificateDocHash,
        string memory supportingDocsHash
    ) external nonReentrant whenNotPaused onlyRole(FARMER_ROLE) returns (uint256) {
        _validateTreeOwnership(treeId, msg.sender);
        
        uint256 certId = certificationContract.uploadCertificate(
            treeId,
            certType,
            authorityName,
            certificateNumber,
            issueDate,
            expiryDate,
            certificateDocHash,
            supportingDocsHash
        );
        
        // Update farmer reputation
        farmerReputationContract.recordReputationEvent(
            msg.sender,
            "Certificate_Uploaded",
            50,
            "Uploaded certification for verification",
            treeId,
            0,
            certId,
            certificateDocHash
        );
        
        emit CertificateUploaded(msg.sender, treeId, certId, Certification.CertificationSource.SelfUploaded);
        
        return certId;
    }
    
    /**
     * @notice Request verification for uploaded certificate
     * @dev Moves certificate to under review status
     * @param certId Certificate ID to verify
     */
    function requestCertificateVerification(uint256 certId) external nonReentrant whenNotPaused {
        certificationContract.requestVerification(certId);
    }
    
    /**
     * @notice PATHWAY 2: Start organic farming transition (3-year journey)
     * @dev Farmer starts NPOP-compliant 3-year transition program
     * @param treeId Tree ID for transition
     * @param chemicalFreeStartDate When chemical use stopped
     * @param transitionPlanHash IPFS hash of transition plan
     * @return transitionId Transition record ID
     */
    function startOrganicTransition(
        uint256 treeId,
        uint256 chemicalFreeStartDate,
        string memory transitionPlanHash
    ) external nonReentrant whenNotPaused onlyRole(FARMER_ROLE) returns (uint256) {
        _validateTreeOwnership(treeId, msg.sender);
        
        uint256 transitionId = certificationContract.startTransition(
            treeId,
            chemicalFreeStartDate,
            transitionPlanHash
        );
        
        farmerReputationContract.recordReputationEvent(
            msg.sender,
            "Transition_Started",
            30,
            "Started organic transition journey",
            treeId,
            0,
            0,
            transitionPlanHash
        );
        
        emit TransitionStarted(msg.sender, treeId, transitionId, chemicalFreeStartDate + 1095 days);
        
        return transitionId;
    }
    
    /**
     * @notice Update transition progress and trust score
     * @dev Can be called by farmer or verifier
     * @param transitionId Transition record ID
     * @param trustScoreAdjustment Points to adjust
     * @param isIncrease Whether to increase or decrease
     */
    function updateOrganicTransitionProgress(
        uint256 transitionId,
        uint256 trustScoreAdjustment,
        bool isIncrease
    ) external nonReentrant whenNotPaused {
        require(
            hasRole(FARMER_ROLE, msg.sender) || hasRole(VERIFIER_ROLE, msg.sender),
            "Not authorized"
        );
        
        certificationContract.updateTransitionProgress(
            transitionId,
            trustScoreAdjustment,
            isIncrease
        );
    }
    
    /**
     * @notice PATHWAY 3: Log farming practice with photo evidence
     * @dev Farmer documents practices to build trust score
     * @param treeId Tree ID where practice was performed
     * @param practiceType Type of farming practice
     * @param description Practice description
     * @param photoHash IPFS hash of photo evidence
     * @return logId Practice log ID
     */
    function logFarmingPractice(
        uint256 treeId,
        Certification.PracticeType practiceType,
        string memory description,
        string memory photoHash
    ) external nonReentrant whenNotPaused onlyRole(FARMER_ROLE) returns (uint256) {
        _validateTreeOwnership(treeId, msg.sender);
        
        uint256 logId = certificationContract.logPractice(
            treeId,
            practiceType,
            description,
            photoHash
        );
        
        farmerReputationContract.recordReputationEvent(
            msg.sender,
            "Practice_Documented",
            5,
            string(abi.encodePacked("Documented farming practice: ", description)),
            treeId,
            0,
            0,
            photoHash
        );
        
        emit PracticeLogged(msg.sender, treeId, logId, practiceType);
        
        return logId;
    }
    
    /**
     * @notice Legacy certification function for backward compatibility
     * @dev Maintains compatibility with existing systems
     */
    function completeCertification(
        uint256 treeId,
        string memory certificationType,
        uint256 expiryDate,
        string memory certifyingAuthority,
        string memory certIpfsHash,
        string memory labName,
        string memory testType,
        bool passed,
        string memory labResults,
        uint256 pesticideLevel,
        uint256 heavyMetalLevel,
        bool microbialSafe
    ) external nonReentrant whenNotPaused onlyRole(FARMER_ROLE) returns (uint256 certificationId, uint256 labTestId) {
        _validateTreeOwnership(treeId, msg.sender);
        
        // Issue certification
        certificationId = certificationContract.issueCertification(
            treeId,
            certificationType,
            expiryDate,
            certifyingAuthority,
            certIpfsHash
        );
        
        // Submit lab test
        labTestId = certificationContract.submitLabTest(
            treeId,
            labName,
            testType,
            passed,
            labResults,
            pesticideLevel,
            heavyMetalLevel,
            microbialSafe
        );
        
        // Link lab test to certification
        certificationContract.linkLabTestToCertification(certificationId, labTestId);
        
        // Update farmer reputation
        uint256 certScore = passed ? 90 : 30;
        farmerReputationContract.recordReputationEvent(
            msg.sender,
            "Certification",
            certScore,
            "Certification and lab test completed",
            treeId,
            0,
            certificationId,
            certIpfsHash
        );
        
        emit CertificationCompleted(msg.sender, treeId, certificationId, certificationType);
        
        return (certificationId, labTestId);
    }
    
    /*//////////////////////////////////////////////////////////////
                    HARVEST MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Complete harvest process with quality metrics
     * @dev Records harvest and quality metrics, updates reputation
     * @param treeId Tree ID
     * @param quantity Harvest quantity in grams
     * @param qualityGrade Quality grade
     * @param ripenessLevel Ripeness level (1-10)
     * @param isOrganic Whether organic
     * @param harvestMethod Harvest method
     * @param harvestIpfsHash Harvest metadata
     * @param size Average size in mm
     * @param sweetness Sweetness score (1-20)
     * @param firmness Firmness score (1-10)
     * @param colorScore Color score (1-10)
     * @param defectPercentage Defect percentage
     * @param meetsExportStandards Export standards compliance
     * @param qualityNotes Quality notes
     * @return harvestId Harvest record ID
     */
    function completeHarvest(
        uint256 treeId,
        uint256 quantity,
        string memory qualityGrade,
        uint256 ripenessLevel,
        bool isOrganic,
        string memory harvestMethod,
        string memory harvestIpfsHash,
        uint256 size,
        uint256 sweetness,
        uint256 firmness,
        uint256 colorScore,
        uint256 defectPercentage,
        bool meetsExportStandards,
        string memory qualityNotes
    ) external nonReentrant whenNotPaused onlyRole(FARMER_ROLE) 
      validQuantity(quantity) 
      returns (uint256 harvestId) {
        _validateTreeOwnership(treeId, msg.sender);
        
        // Record harvest
        harvestId = harvestContract.recordHarvest(
            treeId,
            quantity,
            qualityGrade,
            ripenessLevel,
            isOrganic,
            harvestMethod,
            harvestIpfsHash
        );
        
        // Record quality metrics
        harvestContract.recordQualityMetrics(
            harvestId,
            size,
            sweetness,
            firmness,
            colorScore,
            defectPercentage,
            meetsExportStandards,
            qualityNotes
        );
        
        // Update farmer reputation with harvest quality
        uint256 qualityScore = calculateQualityScore(size, sweetness, firmness, colorScore, defectPercentage);
        farmerReputationContract.recordReputationEvent(
            msg.sender,
            "Harvest_Quality",
            qualityScore,
            "Harvest quality metrics recorded",
            treeId,
            harvestId,
            0,
            harvestIpfsHash
        );
        
        emit HarvestCompleted(msg.sender, treeId, harvestId, quantity, qualityGrade);
        
        return harvestId;
    }
    
    /*//////////////////////////////////////////////////////////////
                    SUPPLY CHAIN MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Create product batch and enter supply chain
     * @dev Creates batch from harvests and transfers ownership
     * @param harvestIds Array of harvest IDs
     * @param batchCode Human-readable batch code
     * @param qrCodeHash QR code IPFS hash
     * @param to Recipient address
     * @param transferType Transfer type
     * @param location Transfer location
     * @param transferIpfsHash Transfer documents
     * @param temperature Storage temperature
     * @param humidity Storage humidity
     * @param transportMethod Transport method
     * @return batchId Created batch ID
     */
    function createBatchAndTransfer(
        uint256[] memory harvestIds,
        string memory batchCode,
        string memory qrCodeHash,
        address to,
        string memory transferType,
        string memory location,
        string memory transferIpfsHash,
        uint256 temperature,
        uint256 humidity,
        string memory transportMethod
    ) external nonReentrant whenNotPaused 
      validArrayLength(harvestIds)
      returns (uint256 batchId) {
        require(harvestIds.length > 0, "Must include at least one harvest");
        require(to != address(0), "Invalid recipient address");
        
        // Validate harvests and calculate total quantity
        uint256 totalQuantity = 0;
        for (uint256 i = 0; i < harvestIds.length; i++) {
            Harvest.HarvestData memory harvest = harvestContract.getHarvest(harvestIds[i]);
            
            // Validate harvest ownership
            require(harvest.farmer == msg.sender, "Not owner of all harvests");
            
            // Validate harvest not already used in a batch
            require(!harvest.isProcessed, "Harvest already processed");
            
            // Accumulate quantity
            totalQuantity += harvest.quantity;
        }
        
        require(totalQuantity > 0, "Total quantity must be greater than 0");
        
        // Create product batch
        batchId = supplyChainContract.createProductBatch(harvestIds, batchCode, qrCodeHash);
        
        // Transfer ownership
        supplyChainContract.transferOwnership(
            batchId,
            to,
            transferType,
            location,
            transferIpfsHash,
            temperature,
            humidity,
            transportMethod
        );
        
        // Grant supply chain role to recipient if not already granted
        if (!hasRole(SUPPLY_CHAIN_ROLE, to)) {
            _grantRole(SUPPLY_CHAIN_ROLE, to);
        }
        
        emit BatchCreated(batchId, msg.sender, harvestIds, batchCode);
        
        return batchId;
    }
    
    /*//////////////////////////////////////////////////////////////
                    CONSUMER VERIFICATION
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Complete consumer verification process
     * @dev Verifies product authenticity and collects consumer feedback
     * @param batchId Batch ID
     * @param isAuthentic Whether authentic
     * @param verificationNotes Verification notes
     * @param rating Product rating (1-5)
     * @param feedback Consumer feedback
     * @param verificationIpfsHash Verification documents
     * @return verificationId Verification record ID
     */
    function completeConsumerVerification(
        uint256 batchId,
        bool isAuthentic,
        string memory verificationNotes,
        uint256 rating,
        string memory feedback,
        string memory verificationIpfsHash
    ) external nonReentrant whenNotPaused returns (uint256 verificationId) {
        require(rating >= 1 && rating <= 5, "Rating must be between 1-5");
        
        // Verify product
        verificationId = consumerVerificationContract.verifyProduct(
            batchId,
            isAuthentic,
            verificationNotes,
            rating,
            feedback,
            verificationIpfsHash
        );
        
        // Update farmer reputation with consumer rating
        uint256 ratingScore = rating * 20; // Convert 1-5 rating to 20-100 score
        
        // Get farmer address from batch
        (SupplyChain.ProductBatch memory batch, ) = supplyChainContract.getBatchTraceability(batchId);
        require(batch.harvestIds.length > 0, "Invalid batch");
        
        Harvest.HarvestData memory firstHarvest = harvestContract.getHarvest(batch.harvestIds[0]);
        address farmer = firstHarvest.farmer;
        
        farmerReputationContract.recordReputationEvent(
            farmer,
            "Consumer_Rating",
            ratingScore,
            "Consumer verification and rating",
            0,
            0,
            0,
            verificationIpfsHash
        );
        
        return verificationId;
    }
    
    /*//////////////////////////////////////////////////////////////
                    WASTE MANAGEMENT & PROCESSING
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Report waste at any stage
     * @dev Records waste events for sustainability tracking
     * @param batchId Batch ID
     * @param quantity Waste quantity in grams
     * @param stage Stage where waste occurred
     * @param wasteType Type of waste
     * @param reason Reason for waste
     * @param disposalMethod How waste was disposed
     * @param isRecycled Whether waste was recycled
     * @param ipfsHash Waste documentation
     * @param cost Cost of waste
     * @return wasteEventId Waste event ID
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
    ) external nonReentrant whenNotPaused returns (uint256) {
        return wasteManagementContract.reportWaste(
            batchId,
            quantity,
            stage,
            wasteType,
            reason,
            disposalMethod,
            isRecycled,
            ipfsHash,
            cost
        );
    }
    
    /**
     * @notice Start processing a batch
     * @dev Initiates processing with input details
     * @param batchId Batch ID to process
     * @param inputQuantity Input quantity in grams
     * @param processingMethod Processing method
     * @param packagingType Packaging type
     * @param packageSize Package size
     * @param ipfsHash Processing documentation
     * @return processingEventId Processing event ID
     */
    function startProcessing(
        uint256 batchId,
        uint256 inputQuantity,
        string memory processingMethod,
        string memory packagingType,
        string memory packageSize,
        string memory ipfsHash
    ) external nonReentrant whenNotPaused returns (uint256) {
        return processingContract.startProcessing(
            batchId,
            inputQuantity,
            processingMethod,
            packagingType,
            packageSize,
            ipfsHash
        );
    }
    
    /**
     * @notice Complete processing with output details
     * @dev Finalizes processing with output metrics
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
    ) external nonReentrant whenNotPaused {
        processingContract.completeProcessing(
            processingEventId,
            outputQuantity,
            packageCount,
            qualityPassed,
            qualityNotes,
            cost
        );
    }
    
    /*//////////////////////////////////////////////////////////////
                    VIEW & QUERY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Get complete certification overview for a tree
     * @dev Returns all certification data for a tree
     * @param treeId Tree ID
     * @return certificates Array of certificates
     * @return transitions Array of transition records
     * @return practices Array of practice logs
     * @return trustScore Current trust score
     */
    function getTreeCertificationOverview(uint256 treeId) 
        external 
        view 
        returns (
            Certification.Certificate[] memory certificates,
            Certification.TransitionRecord[] memory transitions,
            Certification.PracticeLog[] memory practices,
            uint256 trustScore
        ) 
    {
        certificates = certificationContract.getCertificatesByTreeId(treeId);
        transitions = certificationContract.getTransitionRecordsByTreeId(treeId);
        practices = certificationContract.getPracticeLogsByTreeId(treeId);
        trustScore = certificationContract.calculateFarmerTrustScore(treeId);
        
        return (certificates, transitions, practices, trustScore);
    }
    
    /**
     * @notice Get complete traceability data for a batch
     * @dev Returns full traceability from tree to batch
     * @param batchId Batch ID
     * @return batch Complete batch information
     * @return transfers Array of ownership transfers
     * @return harvestIds Array of harvest IDs
     * @return treeIds Array of tree IDs
     * @return trees Array of tree data
     */
    function getCompleteTraceability(uint256 batchId) external view returns (
        SupplyChain.ProductBatch memory batch,
        SupplyChain.OwnershipTransfer[] memory transfers,
        uint256[] memory harvestIds,
        uint256[] memory treeIds,
        TreeID.Tree[] memory trees
    ) {
        // Get batch and transfers
        (batch, transfers) = supplyChainContract.getBatchTraceability(batchId);
        
        // Get harvest IDs from batch
        harvestIds = batch.harvestIds;
        
        // Get tree IDs from harvests
        treeIds = new uint256[](harvestIds.length);
        trees = new TreeID.Tree[](harvestIds.length);
        
        for (uint256 i = 0; i < harvestIds.length; i++) {
            Harvest.HarvestData memory harvest = harvestContract.getHarvest(harvestIds[i]);
            treeIds[i] = harvest.treeId;
            trees[i] = treeIDContract.getTreeById(harvest.treeId);
        }
        
        return (batch, transfers, harvestIds, treeIds, trees);
    }
    
    /**
     * @notice Get farmer's complete certification portfolio
     * @dev Returns comprehensive certification data for a farmer
     * @param farmer Farmer address
     * @return certificateIds Array of certificate IDs
     * @return totalCertificates Total certificate count
     * @return activeCertificates Active certificate count
     * @return averageTrustScore Average trust score
     */
    function getFarmerCertificationPortfolio(address farmer) 
        external 
        view 
        returns (
            uint256[] memory certificateIds,
            uint256 totalCertificates,
            uint256 activeCertificates,
            uint256 averageTrustScore
        ) 
    {
        certificateIds = certificationContract.getFarmerCertificates(farmer);
        totalCertificates = certificateIds.length;
        
        // Calculate active certificates
        for (uint256 i = 0; i < certificateIds.length; i++) {
            Certification.Certificate memory cert = certificationContract.getCertificate(certificateIds[i]);
            if (cert.isActive && cert.expiryDate > block.timestamp) {
                activeCertificates++;
            }
        }
        
        // Calculate average trust score
        uint256[] memory farmerTrees = treeIDContract.getFarmerTrees(farmer);
        uint256 totalTrustScore = 0;
        
        for (uint256 i = 0; i < farmerTrees.length; i++) {
            totalTrustScore += certificationContract.calculateFarmerTrustScore(farmerTrees[i]);
        }
        
        averageTrustScore = farmerTrees.length > 0 ? totalTrustScore / farmerTrees.length : 0;
        
        return (certificateIds, totalCertificates, activeCertificates, averageTrustScore);
    }
    
    /**
     * @notice Get farmer complete profile
     * @dev Returns all farmer data including reputation and metrics
     * @param farmer Farmer address
     * @return reputation Farmer reputation profile
     * @return quality Farmer quality metrics
     * @return tier Farmer reputation tier
     * @return treeIds Array of tree IDs owned by farmer
     * @return harvestIds Array of harvest IDs by farmer
     */
    function getFarmerCompleteProfile(address farmer) external view returns (
        FarmerReputation.FarmerProfile memory reputation,
        FarmerReputation.QualityMetrics memory quality,
        FarmerReputation.ReputationTier memory tier,
        uint256[] memory treeIds,
        uint256[] memory harvestIds
    ) {
        // Get reputation profile
        reputation = farmerReputationContract.getFarmerProfile(farmer);
        quality = farmerReputationContract.getFarmerQualityMetrics(farmer);
        tier = farmerReputationContract.getFarmerTier(farmer);
        
        // Get farmer's trees
        treeIds = treeIDContract.getFarmerTrees(farmer);
        
        // Get farmer's harvests
        harvestIds = harvestContract.getFarmerHarvests(farmer);
        
        return (reputation, quality, tier, treeIds, harvestIds);
    }
    
    /**
     * @notice Get system statistics
     * @dev Returns comprehensive system metrics
     * @return totalTrees Total number of trees
     * @return totalHarvests Total number of harvests
     * @return totalBatches Total number of batches
     * @return totalVerifications Total number of verifications
     * @return totalReputationEvents Total number of reputation events
     * @return totalWasteEvents Total number of waste events
     * @return totalProcessingEvents Total number of processing events
     */
    function getSystemStats() external view returns (
        uint256 totalTrees,
        uint256 totalHarvests,
        uint256 totalBatches,
        uint256 totalVerifications,
        uint256 totalReputationEvents,
        uint256 totalWasteEvents,
        uint256 totalProcessingEvents
    ) {
        totalTrees = treeIDContract.getTotalTrees();
        totalHarvests = harvestContract.getTotalHarvests();
        totalBatches = supplyChainContract.getTotalBatches();
        totalVerifications = consumerVerificationContract.getTotalVerifications();
        totalReputationEvents = farmerReputationContract.getTotalReputationEvents();
        totalWasteEvents = wasteManagementContract.getTotalWasteEvents();
        totalProcessingEvents = processingContract.getTotalProcessingEvents();
        
        return (totalTrees, totalHarvests, totalBatches, totalVerifications, totalReputationEvents, totalWasteEvents, totalProcessingEvents);
    }
    
    /*//////////////////////////////////////////////////////////////
                    ADMIN & UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Emergency pause the system
     * @dev Only admin can pause
     */
    function emergencyPause() external onlyRole(ADMIN_ROLE) {
        _pause();
        emit SystemPaused(msg.sender);
    }
    
    /**
     * @notice Unpause the system
     * @dev Only admin can unpause
     */
    function emergencyUnpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
        emit SystemUnpaused(msg.sender);
    }
    
    /**
     * @notice Grant farmer role to address
     * @dev Only admin can grant farmer role
     * @param farmer Address to grant farmer role
     */
    function grantFarmerRole(address farmer) external onlyRole(ADMIN_ROLE) {
        _grantRole(FARMER_ROLE, farmer);
    }
    
    /**
     * @notice Grant verifier role to address
     * @dev Only admin can grant verifier role
     * @param verifier Address to grant verifier role
     */
    function grantVerifierRole(address verifier) external onlyRole(ADMIN_ROLE) {
        _grantRole(VERIFIER_ROLE, verifier);
    }
    
    /**
     * @notice Calculate quality score from metrics
     * @dev Internal function for quality scoring
     * @param size Average size
     * @param sweetness Sweetness score
     * @param firmness Firmness score
     * @param colorScore Color score
     * @param defectPercentage Defect percentage
     * @return Quality score (0-100)
     */
    function calculateQualityScore(
        uint256 size,
        uint256 sweetness,
        uint256 firmness,
        uint256 colorScore,
        uint256 defectPercentage
    ) internal pure returns (uint256) {
        uint256 score = 0;
        
        // Size score (20 points)
        if (size >= 80) score += 20;
        else if (size >= 60) score += 15;
        else if (size >= 40) score += 10;
        
        // Sweetness score (20 points)
        if (sweetness >= 15) score += 20;
        else if (sweetness >= 12) score += 15;
        else if (sweetness >= 8) score += 10;
        
        // Firmness score (20 points)
        if (firmness >= 8) score += 20;
        else if (firmness >= 6) score += 15;
        else if (firmness >= 4) score += 10;
        
        // Color score (20 points)
        if (colorScore >= 8) score += 20;
        else if (colorScore >= 6) score += 15;
        else if (colorScore >= 4) score += 10;
        
        // Defect score (20 points)
        if (defectPercentage <= 5) score += 20;
        else if (defectPercentage <= 10) score += 15;
        else if (defectPercentage <= 20) score += 10;
        
        return score;
    }
    
    /**
     * @dev Validate tree ownership
     * @param treeId Tree ID to validate
     * @param owner Expected owner address
     */
    function _validateTreeOwnership(uint256 treeId, address owner) internal view {
        TreeID.Tree memory tree = treeIDContract.getTreeById(treeId);
        require(tree.farmerAddress == owner, "Not tree owner");
        require(tree.isActive, "Tree not active");
    }
}