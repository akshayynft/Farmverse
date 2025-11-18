// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./TreeID.sol";
import "./Certification.sol";
import "./Harvest.sol";
import "./SupplyChain.sol";
import "./ConsumerVerification.sol";
import "./FarmerReputation.sol";
import "./WasteManagement.sol";
import "./Processing.sol";

/**
 * @title FarmaverseCore
 * @dev Master contract that integrates all Farmaverse smart contracts
 * Provides unified interface for complete farm-to-fork traceability
 */
contract FarmaverseCore is Ownable, ReentrancyGuard {
    
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
    
    // Events
    event ContractsDeployed(
        address treeID,
        address certification,
        address harvest,
        address supplyChain,
        address consumerVerification,
        address farmerReputation,
        address wasteManagement,
        address processing
    );
    
    event CompleteTraceabilityCreated(
        uint256 indexed treeId,
        uint256 indexed harvestId,
        uint256 indexed batchId,
        address farmer
    );
   
    event FarmerRegistrationFailed(address indexed farmer, string reason);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Set contract addresses after deployment
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
    ) external onlyOwner {
        require(_treeID != address(0), "Invalid TreeID address");
        require(_certification != address(0), "Invalid Certification address");
        require(_harvest != address(0), "Invalid Harvest address");
        require(_supplyChain != address(0), "Invalid SupplyChain address");
        require(_consumerVerification != address(0), "Invalid ConsumerVerification address");
        require(_farmerReputation != address(0), "Invalid FarmerReputation address");
        require(_wasteManagement != address(0), "Invalid WasteManagement address");
        require(_processing != address(0), "Invalid Processing address");
        
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
        supplyChainContract.setHarvestContract(_harvest);
        emit ContractsDeployed(_treeID, _certification, _harvest, _supplyChain, _consumerVerification, _farmerReputation, _wasteManagement, _processing);
    }
    
    /**
     * @dev Complete farm registration process
     * @param location Tree location
     * @param cropType Type of crop
     * @param plantingDate Planting date
     * @param treeIpfsHash Tree metadata IPFS hash
     * @param farmerName Farmer name
     * @param farmerLocation Farmer location
     * @param farmerIpfsHash Farmer profile IPFS hash
     */
    function registerFarm(
        string memory location,
        string memory cropType,
        uint256 plantingDate,
        string memory treeIpfsHash,
        string memory farmerName,
        string memory farmerLocation,
        string memory farmerIpfsHash
    ) external nonReentrant returns (uint256 treeId) {
        //Input validation
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
        // Success - farmer registered
    } catch Error(string memory reason) {
        // Log the error but continue
        emit FarmerRegistrationFailed(msg.sender, reason);
    } catch {
        // Handle any other errors
        emit FarmerRegistrationFailed(msg.sender, "Unknown error");
    }
    
    return treeId;
    }
    
    /**
     * @dev Complete harvest process with quality metrics
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
    ) external nonReentrant returns (uint256 harvestId) {
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
        
        return harvestId;
    }
    
    /**
     * @dev Complete certification process
     * @param treeId Tree ID
     * @param certificationType Certification type
     * @param expiryDate Expiry date
     * @param certifyingAuthority Certifying authority
     * @param certIpfsHash Certification documents
     * @param labName Lab name
     * @param testType Test type
     * @param passed Test passed
     * @param labResults Lab results IPFS hash
     * @param pesticideLevel Pesticide level
     * @param heavyMetalLevel Heavy metal level
     * @param microbialSafe Microbial safety
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
    ) external nonReentrant returns (uint256 certificationId, uint256 labTestId) {
        // Issue certification
        certificationId = certificationContract.issueCertification(
            treeId,
            certificationType,
            expiryDate,
            certifyingAuthority,
            certIpfsHash
        );
        
            // ========== NEW CERTIFICATION FUNCTIONS (3 SCENARIOS) ==========

    /**
    * @notice SCENARIO 1: Upload existing certificate (NPOP, USDA, EU, etc.)
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
    ) external nonReentrant returns (uint256) {
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
        
        return certId;
    }

    /**
    * @notice Request verification for uploaded certificate
    */
    function requestCertificateVerification(uint256 certId) external nonReentrant {
        certificationContract.requestVerification(certId);
    }

    /**
    * @notice SCENARIO 2: Start organic farming transition (3-year journey)
    */
    function startOrganicTransition(
        uint256 treeId,
        uint256 chemicalFreeStartDate,
        string memory transitionPlanHash
    ) external nonReentrant returns (uint256) {
        require(treeIDContract.getTreeById(treeId).farmerAddress == msg.sender, "Not tree owner");
        
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
        
        return transitionId;
    }

    /**
    * @notice Update transition progress
    */
    function updateOrganicTransitionProgress(
        uint256 transitionId,
        uint256 trustScoreAdjustment,
        bool isIncrease
    ) external nonReentrant {
        certificationContract.updateTransitionProgress(
            transitionId,
            trustScoreAdjustment,
            isIncrease
        );
    }

    /**
    * @notice SCENARIO 3: Log farming practice with photo evidence
    */
    function logFarmingPractice(
        uint256 treeId,
        Certification.PracticeType practiceType,
        string memory description,
        string memory photoHash
    ) external nonReentrant returns (uint256) {
        require(treeIDContract.getTreeById(treeId).farmerAddress == msg.sender, "Not tree owner");
        
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
        
        return logId;
    }

    // ========== NEW VIEW FUNCTIONS ==========

    /**
    * @notice Get complete certification overview for a tree
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
    * @notice Get transition status for a tree
    */
    function getTreeTransitionStatus(uint256 treeId) 
        external 
        view 
        returns (Certification.TransitionRecord[] memory) 
    {
        return certificationContract.getTransitionRecordsByTreeId(treeId);
    }

    /**
    * @notice Get practice logs for a tree
    */
    function getTreePracticeLogs(uint256 treeId) 
        external 
        view 
        returns (Certification.PracticeLog[] memory) 
    {
        return certificationContract.getPracticeLogsByTreeId(treeId);
    }

    /**
    * @notice Calculate farmer's trust score
    */
    function getFarmerTrustScore(uint256 treeId) 
        external 
        view 
        returns (uint256) 
    {
        return certificationContract.calculateFarmerTrustScore(treeId);
    }

    /**
    * @notice Get farmer's complete certification portfolio
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
        uint256 certScore = passed ? 90 : 30; // High score for passed tests
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
        
        return (certificationId, labTestId);
    }
    
    /**
    * @dev Create product batch and enter supply chain
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
    ) external nonReentrant returns (uint256 batchId) {
        require(harvestIds.length > 0, "Must include at least one harvest");
        
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
            
            // Mark harvest as processed to prevent reuse
            // Note: This requires the harvest contract to allow this call
            // You may need to add access control in Harvest.sol
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
        
        return batchId;
    }
    
    /**
     * @dev Complete consumer verification process
     * @param batchId Batch ID
     * @param isAuthentic Whether authentic
     * @param verificationNotes Verification notes
     * @param rating Product rating (1-5)
     * @param feedback Consumer feedback
     * @param verificationIpfsHash Verification documents
     */
    function completeConsumerVerification(
        uint256 batchId,
        bool isAuthentic,
        string memory verificationNotes,
        uint256 rating,
        string memory feedback,
        string memory verificationIpfsHash
    ) external nonReentrant returns (uint256 verificationId) {
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
        farmerReputationContract.recordReputationEvent(
            msg.sender,
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
    
    /**
     * @dev Get complete traceability data for a batch
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
     * @dev Get farmer complete profile
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
     * @dev Calculate quality score from metrics
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
     * @dev Report waste at any stage
     * @param batchId Batch ID
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
     * @dev Start processing a batch
     * @param batchId Batch ID to process
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
        processingContract.completeProcessing(
            processingEventId,
            outputQuantity,
            packageCount,
            qualityPassed,
            qualityNotes,
            cost
        );
    }
    
    /**
     * @dev Get complete waste statistics for a batch
     * @param batchId Batch ID
     * @return Waste statistics
     */
    function getBatchWasteStats(uint256 batchId) external view returns (WasteManagement.WasteStats memory) {
        return wasteManagementContract.getBatchWasteStats(batchId);
    }
    
    /**
     * @dev Get complete processing statistics for a batch
     * @param batchId Batch ID
     * @return Processing statistics
     */
    function getBatchProcessingStats(uint256 batchId) external view returns (Processing.ProcessingStats memory) {
        return processingContract.getBatchProcessingStats(batchId);
    }
    
    /**
     * @dev Get sustainability metrics for a batch
     * @param batchId Batch ID
     * @return recycledPercentage Percentage of waste recycled
     * @return totalWaste Total waste quantity
     * @return totalCost Total waste cost
     */
    function getBatchSustainabilityMetrics(uint256 batchId) external view returns (
        uint256 recycledPercentage,
        uint256 totalWaste,
        uint256 totalCost
    ) {
        return wasteManagementContract.getSustainabilityMetrics(batchId);
    }
    
    /**
     * @dev Get system statistics
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
}
