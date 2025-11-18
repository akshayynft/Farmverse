// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Certification - Farm-to-Fork Organic Certification System
 * @author Farmaverse Development Team
 * @notice Manages organic certification with three pathways for Indian mango farmers
 * @dev Implements role-based access control, reentrancy protection, and emergency pause
 * 
 * CERTIFICATION PATHWAYS:
 * 1. Certificate Upload: Farmers with existing NPOP/USDA/EU certificates
 * 2. Transition Journey: Farmers documenting their 3-year organic transition
 * 3. Practice Documentation: New farmers building trust through photo evidence
 * 
 * SECURITY FEATURES:
 * - OpenZeppelin AccessControl for role management
 * - ReentrancyGuard on all state-changing functions
 * - Pausable for emergency circuit breaker
 * - EnumerableSet for gas-efficient iterations
 * 
 * INTEGRATION:
 * - Backward compatible with existing FarmaverseCore
 * - Integrates with TreeID for ownership verification
 * - Supports legacy API for smooth migration
 * 
 * @custom:security-contact security@farmaverse.com
 */
contract Certification is AccessControl, ReentrancyGuard, Pausable {
    using EnumerableSet for EnumerableSet.UintSet;
    
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Role identifier for platform verifiers who validate certificates
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    /// @notice Role identifier for authorized laboratories conducting tests
    bytes32 public constant LAB_ROLE = keccak256("LAB_ROLE");
    
    /// @notice Role identifier for certification authorities (NPOP, USDA, etc.)
    bytes32 public constant AUTHORITY_ROLE = keccak256("AUTHORITY_ROLE");
    
    /// @notice Maximum trees that can be processed in a single batch operation
    uint256 public constant MAX_BATCH_SIZE = 50;
    
    /// @notice Maximum number of practice photos a farmer can upload per tree
    uint256 public constant MAX_PHOTOS = 10;
    
    /// @notice Maximum length for string inputs to prevent gas exhaustion attacks
    uint256 public constant MAX_STRING_LENGTH = 500;
    
    /// @notice Duration of organic transition period as per NPOP guidelines (3 years)
    uint256 public constant TRANSITION_PERIOD = 1095 days;
    
    /// @notice Maximum acceptable pesticide residue level (parts per billion)
    uint256 public constant MAX_PESTICIDE_LEVEL = 10000;
    
    /// @notice Maximum acceptable heavy metal level (parts per billion)
    uint256 public constant MAX_HEAVY_METAL_LEVEL = 1000;
    
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    /// @dev Counter for unique certification IDs (auto-incrementing)
    uint256 private _certificationIdCounter;
    
    /// @dev Counter for unique lab test IDs (auto-incrementing)
    uint256 private _labTestIdCounter;
    
    /// @dev Counter for unique transition record IDs (auto-incrementing)
    uint256 private _transitionIdCounter;
    
    /// @dev Counter for unique practice log IDs (auto-incrementing)
    uint256 private _practiceLogIdCounter;
    
    /// @notice Address of the TreeID contract for ownership verification
    /// @dev Used to verify tree ownership before certification operations
    address public treeIDAddress;
    
    /*//////////////////////////////////////////////////////////////
                            DATA STRUCTURES
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Legacy certification data structure for backward compatibility
     * @dev Maintained to support existing FarmaverseCore integration
     */
    struct CertificationData {
        uint256 certificationId;
        uint256 treeId;
        address farmer;
        string certificationType;
        uint256 issueDate;
        uint256 expiryDate;
        string certifyingAuthority;
        string ipfsHash;
        bool isActive;
        uint256 labTestId;
    }
    
    /**
     * @notice Laboratory test results for food safety verification
     * @dev Used by authorized labs to submit test results
     */
    struct LabTest {
        uint256 labTestId;
        uint256 treeId;
        string labName;
        uint256 testDate;
        string testType;
        bool passed;
        string results;
        uint256 pesticideLevel;
        uint256 heavyMetalLevel;
        bool microbialSafe;
    }
    
    /**
     * @notice Enhanced certificate with detailed tracking and verification
     * @dev New structure supporting multiple certification pathways
     */
    struct Certificate {
        uint256 certificateId;
        uint256 treeId;
        address farmer;
        CertificationType certType;
        CertificationSource source;
        VerificationStatus verificationStatus;
        uint256 authorityId;
        uint256 issueDate;
        uint256 expiryDate;
        uint256 verificationDate;
        address verifiedBy;
        bool isActive;
        string authorityName;
        string certificateNumber;
        string certificateDocumentHash;
    }
    
    /**
     * @notice Tracks a farmer's journey from chemical farming to organic
     * @dev Implements NPOP 3-year transition requirement
     */
    struct TransitionRecord {
        uint256 transitionId;
        uint256 treeId;
        address farmer;
        uint256 startDate;
        uint256 targetCompletionDate;
        uint256 currentProgress;
        bool isCompleted;
        uint256 trustScore;
        string transitionPlan;
    }
    
    /**
     * @notice Individual farming practice documentation with photo evidence
     * @dev Allows farmers to build trust through consistent documentation
     */
    struct PracticeLog {
        uint256 logId;
        uint256 treeId;
        address farmer;
        uint256 logDate;
        PracticeType practiceType;
        string description;
        string photoHash;
        bool isVerified;
        address verifiedBy;
        uint256 trustScoreImpact;
    }
    
    /*//////////////////////////////////////////////////////////////
                            ENUMERATIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Types of organic/sustainable certifications
     * @dev Ordered by frequency of use for gas optimization
     */
    enum CertificationType {
        Organic,
        PesticideFree,
        InTransition,
        FairTrade,
        Rainforest,
        BirdFriendly,
        Biodynamic,
        NaturallyGrown,
        GAP,
        Custom
    }
    
    /**
     * @notice How the certificate was obtained or issued
     * @dev Tracks certificate provenance for transparency
     */
    enum CertificationSource {
        SelfUploaded,
        PlatformVerified,
        AuthorityIssued,
        FarmaverseCertified,
        TransitionDocumented,
        LegacyImport
    }
    
    /**
     * @notice Current status of certificate verification
     * @dev Sequential workflow states
     */
    enum VerificationStatus {
        Pending,
        UnderReview,
        Verified,
        Rejected,
        Expired
    }
    
    /**
     * @notice Types of farming practices that can be documented
     * @dev Used for practice logging and trust score calculation
     */
    enum PracticeType {
        FertilizerApplication,
        PestControl,
        IrrigationManagement,
        SoilTesting,
        CompostingActivity,
        OrganicInputs,
        CropRotation,
        Other
    }
    
    /*//////////////////////////////////////////////////////////////
                            STORAGE MAPPINGS
    //////////////////////////////////////////////////////////////*/
    
    // Legacy storage (backward compatibility)
    mapping(uint256 => CertificationData) public certifications;
    mapping(uint256 => LabTest) public labTests;
    mapping(uint256 => uint256[]) public treeCertifications;
    mapping(uint256 => uint256[]) public treeLabTests;
    
    // Enhanced storage
    mapping(uint256 => Certificate) public certificates;
    mapping(uint256 => TransitionRecord) public transitionRecords;
    mapping(uint256 => PracticeLog) public practiceLogs;
    mapping(uint256 => string) private _certificateSupportingDocs;
    mapping(uint256 => string) private _certificateVerificationNotes;
    
    // Efficient iteration structures using EnumerableSet
    mapping(uint256 => EnumerableSet.UintSet) private _treeCertificates;
    mapping(uint256 => EnumerableSet.UintSet) private _treeTransitionRecords;
    mapping(uint256 => EnumerableSet.UintSet) private _treePracticeLogs;
    mapping(address => EnumerableSet.UintSet) private _farmerCertificates;
    mapping(string => uint256) private _authorityRegistry;
    
    // Authorization mappings
    mapping(address => bool) public authorizedLabs;
    mapping(address => bool) public certifyingAuthorities;
    
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    
    // Legacy events (backward compatibility)
    event CertificationIssued(uint256 indexed certificationId, uint256 indexed treeId, string certificationType);
    event CertificationExpired(uint256 indexed certificationId, uint256 indexed treeId);
    event LabTestSubmitted(uint256 indexed labTestId, uint256 indexed treeId, bool passed);
    event LabAuthorized(address indexed labAddress, bool authorized);
    event AuthorityAuthorized(address indexed authorityAddress, bool authorized);
    
    // Enhanced events
    event CertificateUploaded(
        uint256 indexed certId, 
        uint256 indexed treeId, 
        address indexed farmer, 
        CertificationSource source, 
        string authority
    );
    event CertificateVerified(uint256 indexed certId, address indexed verifier);
    event CertificateRevoked(uint256 indexed certId, string reason);
    event TransitionStarted(
        uint256 indexed transitionId, 
        uint256 indexed treeId, 
        address indexed farmer, 
        uint256 targetDate
    );
    event TransitionProgressUpdated(
        uint256 indexed transitionId, 
        uint256 currentProgress, 
        uint256 trustScore
    );
    event TransitionCompleted(uint256 indexed transitionId, uint256 indexed treeId);
    event PracticeLogged(
        uint256 indexed logId, 
        uint256 indexed treeId, 
        address indexed farmer, 
        PracticeType practiceType
    );
    event PracticeVerified(
        uint256 indexed logId, 
        address indexed verifier, 
        uint256 trustScoreImpact
    );
    event AuthorityRegistered(string indexed name, uint256 id);
    event TreeIDAddressUpdated(address indexed newAddress);
    
    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    
    modifier validTree(uint256 treeId) {
        require(_treeExists(treeId), "Tree does not exist");
        _;
    }
    
    modifier onlyTreeOwner(uint256 treeId) {
        require(_verifyTreeOwnership(treeId, msg.sender), "Not tree owner");
        _;
    }
    
    modifier validString(string memory str) {
        require(
            bytes(str).length > 0 && bytes(str).length <= MAX_STRING_LENGTH, 
            "Invalid string length"
        );
        _;
    }
    
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    constructor(address _treeIDAddress) {
        require(_treeIDAddress != address(0), "Invalid TreeID address");
        treeIDAddress = _treeIDAddress;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _initializeDefaultAuthorities();
    }
    
    /*//////////////////////////////////////////////////////////////
                    LEGACY FUNCTIONS (BACKWARD COMPATIBLE)
    //////////////////////////////////////////////////////////////*/
    
    function issueCertification(
        uint256 treeId,
        string memory certificationType,
        uint256 expiryDate,
        string memory certifyingAuthority,
        string memory ipfsHash
    ) external nonReentrant whenNotPaused onlyTreeOwner(treeId) returns (uint256) {
        require(bytes(certificationType).length > 0, "Certification type cannot be empty");
        require(expiryDate > block.timestamp, "Expiry date must be in future");
        require(bytes(certifyingAuthority).length > 0, "Certifying authority cannot be empty");
        
        _certificationIdCounter++;
        uint256 newCertificationId = _certificationIdCounter;
        
        certifications[newCertificationId] = CertificationData({
            certificationId: newCertificationId,
            treeId: treeId,
            farmer: msg.sender,
            certificationType: certificationType,
            issueDate: block.timestamp,
            expiryDate: expiryDate,
            certifyingAuthority: certifyingAuthority,
            ipfsHash: ipfsHash,
            isActive: true,
            labTestId: 0
        });
        
        treeCertifications[treeId].push(newCertificationId);
        
        _createEnhancedCertificate(
            newCertificationId,
            treeId,
            msg.sender,
            _mapCertificationType(certificationType),
            CertificationSource.LegacyImport,
            certifyingAuthority,
            "",
            block.timestamp,
            expiryDate,
            ipfsHash
        );
        
        emit CertificationIssued(newCertificationId, treeId, certificationType);
        
        return newCertificationId;
    }
    
    function submitLabTest(
        uint256 treeId,
        string memory labName,
        string memory testType,
        bool passed,
        string memory results,
        uint256 pesticideLevel,
        uint256 heavyMetalLevel,
        bool microbialSafe
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(authorizedLabs[msg.sender], "Only authorized labs can submit");
        require(bytes(labName).length > 0, "Lab name cannot be empty");
        require(pesticideLevel <= MAX_PESTICIDE_LEVEL, "Pesticide level exceeds maximum");
        require(heavyMetalLevel <= MAX_HEAVY_METAL_LEVEL, "Heavy metal level exceeds maximum");
        
        _labTestIdCounter++;
        uint256 labTestId = _labTestIdCounter;
        
        labTests[labTestId] = LabTest({
            labTestId: labTestId,
            treeId: treeId,
            labName: labName,
            testDate: block.timestamp,
            testType: testType,
            passed: passed,
            results: results,
            pesticideLevel: pesticideLevel,
            heavyMetalLevel: heavyMetalLevel,
            microbialSafe: microbialSafe
        });
        
        treeLabTests[treeId].push(labTestId);
        
        emit LabTestSubmitted(labTestId, treeId, passed);
        
        return labTestId;
    }
    
    function linkLabTestToCertification(uint256 certificationId, uint256 labTestId) 
        external 
        nonReentrant 
    {
        require(
            certifications[certificationId].farmer == msg.sender, 
            "Only certification owner can link"
        );
        require(certifications[certificationId].isActive, "Certification must be active");
        require(labTests[labTestId].labTestId != 0, "Lab test does not exist");
        require(
            labTests[labTestId].treeId == certifications[certificationId].treeId, 
            "Lab test must be for same tree"
        );
        
        certifications[certificationId].labTestId = labTestId;
    }
    
    function getCertification(uint256 certificationId) 
        external 
        view 
        returns (CertificationData memory) 
    {
        require(
            certifications[certificationId].certificationId != 0, 
            "Certification does not exist"
        );
        return certifications[certificationId];
    }
    
    function getLabTest(uint256 labTestId) 
        external 
        view 
        returns (LabTest memory) 
    {
        require(labTests[labTestId].labTestId != 0, "Lab test does not exist");
        return labTests[labTestId];
    }
    
    function isCertificationValid(uint256 certificationId) 
        external 
        view 
        returns (bool valid) 
    {
        CertificationData memory cert = certifications[certificationId];
        return cert.isActive && cert.expiryDate > block.timestamp;
    }
    
    function getTreeCertifications(uint256 treeId) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return treeCertifications[treeId];
    }
    
    function getTreeLabTests(uint256 treeId) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return treeLabTests[treeId];
    }
    
    function expireCertification(uint256 certificationId) 
        external 
        nonReentrant 
        whenNotPaused
    {
        require(
            certifications[certificationId].certificationId != 0, 
            "Certification does not exist"
        );
        require(
            certifications[certificationId].farmer == msg.sender, 
            "Only certification owner can expire"
        );
        require(certifications[certificationId].isActive, "Already inactive");
        
        certifications[certificationId].isActive = false;
        
        emit CertificationExpired(certificationId, certifications[certificationId].treeId);
    }
    
    /*//////////////////////////////////////////////////////////////
                SCENARIO 1: FARMER HAS EXISTING CERTIFICATE
    //////////////////////////////////////////////////////////////*/
    
    function uploadCertificate(
        uint256 treeId,
        CertificationType certType,
        string memory authorityName,
        string memory certificateNumber,
        uint256 issueDate,
        uint256 expiryDate,
        string memory certificateDocHash,
        string memory supportingDocsHash
    ) external nonReentrant whenNotPaused validTree(treeId) onlyTreeOwner(treeId) returns (uint256) {
        require(bytes(authorityName).length > 0, "Authority name required");
        require(bytes(certificateNumber).length > 0, "Certificate number required");
        CertificationValidators.validateDateRange(issueDate, expiryDate);
        CertificationValidators.validateIPFSHash(certificateDocHash);
        
        _certificationIdCounter++;
        uint256 newCertId = _certificationIdCounter;
        
        certificates[newCertId] = Certificate({
            certificateId: newCertId,
            treeId: treeId,
            farmer: msg.sender,
            certType: certType,
            source: CertificationSource.SelfUploaded,
            verificationStatus: VerificationStatus.Pending,
            authorityId: _findAuthorityByName(authorityName),
            authorityName: authorityName,
            certificateNumber: certificateNumber,
            issueDate: issueDate,
            expiryDate: expiryDate,
            certificateDocumentHash: certificateDocHash,
            verificationDate: 0,
            verifiedBy: address(0),
            isActive: true
        });
        
        _certificateSupportingDocs[newCertId] = supportingDocsHash;
        _treeCertificates[treeId].add(newCertId);
        _farmerCertificates[msg.sender].add(newCertId);
        
        emit CertificateUploaded(newCertId, treeId, msg.sender, CertificationSource.SelfUploaded, authorityName);
        
        return newCertId;
    }
    
    function verifyCertificate(uint256 certId, string memory notes) 
        external 
        onlyRole(VERIFIER_ROLE) 
        nonReentrant 
        whenNotPaused
        validString(notes) 
    {
        require(certificates[certId].certificateId != 0, "Certificate does not exist");
        Certificate storage cert = certificates[certId];
        require(cert.isActive, "Certificate already inactive");
        require(
            cert.verificationStatus == VerificationStatus.Pending || 
            cert.verificationStatus == VerificationStatus.UnderReview,
            "Certificate not eligible for verification"
        );
        
        cert.verificationStatus = VerificationStatus.Verified;
        cert.verificationDate = block.timestamp;
        cert.verifiedBy = msg.sender;
        cert.source = CertificationSource.PlatformVerified;
        _certificateVerificationNotes[certId] = notes;
        
        emit CertificateVerified(certId, msg.sender);
    }
    
    function requestVerification(uint256 certId) 
        external 
        nonReentrant 
        whenNotPaused
    {
        require(certificates[certId].certificateId != 0, "Certificate does not exist");
        Certificate storage cert = certificates[certId];
        require(cert.farmer == msg.sender, "Only certificate owner can request verification");
        require(cert.verificationStatus == VerificationStatus.Pending, "Already under review or verified");
        
        cert.verificationStatus = VerificationStatus.UnderReview;
    }
    
    /*//////////////////////////////////////////////////////////////
            SCENARIO 2: FARMER IN 3-YEAR TRANSITION
    //////////////////////////////////////////////////////////////*/
    
    function startTransition(
        uint256 treeId,
        uint256 chemicalFreeStartDate,
        string memory transitionPlan
    ) external nonReentrant whenNotPaused validTree(treeId) onlyTreeOwner(treeId) returns (uint256) {
        require(bytes(transitionPlan).length > 0, "Transition plan required");
        require(chemicalFreeStartDate <= block.timestamp, "Start date cannot be in future");
        require(
            chemicalFreeStartDate > block.timestamp - (5 * 365 days), 
            "Start date cannot be more than 5 years ago"
        );
        CertificationValidators.validateIPFSHash(transitionPlan);
        
        _transitionIdCounter++;
        uint256 newTransitionId = _transitionIdCounter;
        
        uint256 targetDate = chemicalFreeStartDate + TRANSITION_PERIOD;
        uint256 currentProgress = block.timestamp - chemicalFreeStartDate;
        
        transitionRecords[newTransitionId] = TransitionRecord({
            transitionId: newTransitionId,
            treeId: treeId,
            farmer: msg.sender,
            startDate: chemicalFreeStartDate,
            targetCompletionDate: targetDate,
            currentProgress: currentProgress,
            isCompleted: false,
            trustScore: 30,
            transitionPlan: transitionPlan
        });
        
        _treeTransitionRecords[treeId].add(newTransitionId);
        
        emit TransitionStarted(newTransitionId, treeId, msg.sender, targetDate);
        
        return newTransitionId;
    }
    
    function updateTransitionProgress(
        uint256 transitionId,
        uint256 trustScoreAdjustment,
        bool isIncrease
    ) external nonReentrant whenNotPaused {
        require(transitionRecords[transitionId].transitionId != 0, "Transition does not exist");
        TransitionRecord storage transition = transitionRecords[transitionId];
        require(
            msg.sender == transition.farmer || hasRole(VERIFIER_ROLE, msg.sender),
            "Only farmer or verifier can update"
        );
        require(!transition.isCompleted, "Transition already completed");
        
        transition.currentProgress = block.timestamp - transition.startDate;
        
        if (isIncrease) {
            transition.trustScore = transition.trustScore + trustScoreAdjustment > 100 
                ? 100 
                : transition.trustScore + trustScoreAdjustment;
        } else {
            transition.trustScore = transition.trustScore > trustScoreAdjustment 
                ? transition.trustScore - trustScoreAdjustment 
                : 0;
        }
        
        emit TransitionProgressUpdated(transitionId, transition.currentProgress, transition.trustScore);
        
        if (transition.currentProgress >= TRANSITION_PERIOD && transition.trustScore >= 70) {
            _completeTransition(transitionId);
        }
    }
    
    function _completeTransition(uint256 transitionId) private {
        TransitionRecord storage transition = transitionRecords[transitionId];
        transition.isCompleted = true;
        
        _certificationIdCounter++;
        uint256 newCertId = _certificationIdCounter;
        
        certificates[newCertId] = Certificate({
            certificateId: newCertId,
            treeId: transition.treeId,
            farmer: transition.farmer,
            certType: CertificationType.InTransition,
            source: CertificationSource.FarmaverseCertified,
            verificationStatus: VerificationStatus.Verified,
            authorityId: 0,
            authorityName: "Farmaverse Transition Certified",
            certificateNumber: string(abi.encodePacked("FV-TRANS-", _uintToString(transitionId))),
            issueDate: block.timestamp,
            expiryDate: block.timestamp + 365 days,
            certificateDocumentHash: transition.transitionPlan,
            verificationDate: block.timestamp,
            verifiedBy: address(this),
            isActive: true
        });
        
        _treeCertificates[transition.treeId].add(newCertId);
        _farmerCertificates[transition.farmer].add(newCertId);
        
        emit TransitionCompleted(transitionId, transition.treeId);
        emit CertificateUploaded(
            newCertId, 
            transition.treeId, 
            transition.farmer, 
            CertificationSource.FarmaverseCertified, 
            "Farmaverse"
        );
    }
    
    /*//////////////////////////////////////////////////////////////
            SCENARIO 3: FARMER DOCUMENTING PRACTICES
    //////////////////////////////////////////////////////////////*/
    
    function logPractice(
        uint256 treeId,
        PracticeType practiceType,
        string memory description,
        string memory photoHash
    ) external nonReentrant whenNotPaused validTree(treeId) onlyTreeOwner(treeId) returns (uint256) {
        require(bytes(description).length > 0, "Description required");
        CertificationValidators.validateIPFSHash(photoHash);
        
        _practiceLogIdCounter++;
        uint256 newLogId = _practiceLogIdCounter;
        
        practiceLogs[newLogId] = PracticeLog({
            logId: newLogId,
            treeId: treeId,
            farmer: msg.sender,
            logDate: block.timestamp,
            practiceType: practiceType,
            description: description,
            photoHash: photoHash,
            isVerified: false,
            verifiedBy: address(0),
            trustScoreImpact: 0
        });
        
        _treePracticeLogs[treeId].add(newLogId);
        
        emit PracticeLogged(newLogId, treeId, msg.sender, practiceType);
        
        return newLogId;
    }
    
    function verifyPractice(uint256 logId, uint256 trustScoreImpact) 
        external 
        onlyRole(VERIFIER_ROLE) 
        nonReentrant 
        whenNotPaused
    {
        require(practiceLogs[logId].logId != 0, "Practice log does not exist");
        require(!practiceLogs[logId].isVerified, "Already verified");
        require(trustScoreImpact <= 10, "Maximum 10 points per practice");
        
        PracticeLog storage log = practiceLogs[logId];
        log.isVerified = true;
        log.verifiedBy = msg.sender;
        log.trustScoreImpact = trustScoreImpact;
        
        emit PracticeVerified(logId, msg.sender, trustScoreImpact);
    }
    
    function calculateFarmerTrustScore(uint256 treeId) 
        external 
        view 
        returns (uint256) 
    {
        EnumerableSet.UintSet storage logIds = _treePracticeLogs[treeId];
        uint256 totalScore = 0;
        
        for (uint256 i = 0; i < logIds.length(); i++) {
            PracticeLog memory log = practiceLogs[logIds.at(i)];
            if (log.isVerified) {
                totalScore += log.trustScoreImpact;
            }
        }
        
        return totalScore > 100 ? 100 : totalScore;
    }
    
    /*//////////////////////////////////////////////////////////////
                    CERTIFICATE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    function revokeCertificate(uint256 certId, string memory reason) 
        external 
        onlyRole(VERIFIER_ROLE) 
        nonReentrant 
        whenNotPaused
        validString(reason) 
    {
        require(certificates[certId].certificateId != 0, "Certificate does not exist");
        Certificate storage cert = certificates[certId];
        require(cert.isActive, "Certificate already inactive");
        
        cert.isActive = false;
        cert.verificationStatus = VerificationStatus.Rejected;
        
        emit CertificateRevoked(certId, reason);
    }
    
    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function getCertificatesByTreeId(uint256 treeId) 
        external 
        view 
        returns (Certificate[] memory) 
    {
        EnumerableSet.UintSet storage certIds = _treeCertificates[treeId];
        Certificate[] memory certs = new Certificate[](certIds.length());
        
        for (uint256 i = 0; i < certIds.length(); i++) {
            certs[i] = certificates[certIds.at(i)];
        }
        
        return certs;
    }
    
    function getTransitionRecordsByTreeId(uint256 treeId)
        external
        view
        returns (TransitionRecord[] memory)
    {
        EnumerableSet.UintSet storage transitionIds = _treeTransitionRecords[treeId];
        TransitionRecord[] memory records = new TransitionRecord[](transitionIds.length());
        
        for (uint256 i = 0; i < transitionIds.length(); i++) {
            records[i] = transitionRecords[transitionIds.at(i)];
        }
        
        return records;
    }
    
    function getPracticeLogsByTreeId(uint256 treeId)
        external
        view
        returns (PracticeLog[] memory)
    {
        EnumerableSet.UintSet storage logIds = _treePracticeLogs[treeId];
        PracticeLog[] memory logs = new PracticeLog[](logIds.length());
        
        for (uint256 i = 0; i < logIds.length(); i++) {
            logs[i] = practiceLogs[logIds.at(i)];
        }
        
        return logs;
    }
    
    function getFarmerCertificates(address farmer) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return _farmerCertificates[farmer].values();
    }
    
    function getCertificate(uint256 certId) 
        external 
        view 
        returns (Certificate memory) 
    {
        require(certificates[certId].certificateId != 0, "Certificate does not exist");
        return certificates[certId];
    }
    
    function hasValidOrganicCertification(uint256 treeId) 
        external 
        view 
        returns (bool) 
    {
        // Check legacy certifications
        uint256[] memory legacyCerts = treeCertifications[treeId];
        for (uint256 i = 0; i < legacyCerts.length; i++) {
            CertificationData memory cert = certifications[legacyCerts[i]];
            if (cert.isActive && 
                cert.expiryDate > block.timestamp && 
                keccak256(bytes(cert.certificationType)) == keccak256(bytes("Organic"))) {
                return true;
            }
        }
        
        // Check new certificates
        EnumerableSet.UintSet storage certIds = _treeCertificates[treeId];
        for (uint256 i = 0; i < certIds.length(); i++) {
            Certificate memory cert = certificates[certIds.at(i)];
            if (_isCertificateActive(cert) && cert.certType == CertificationType.Organic) {
                return true;
            }
        }
        
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                    PRODUCTION UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get total counts for dashboard and monitoring
     * @return Total certification count
     */
    function getTotalCertifications() external view returns (uint256) {
        return _certificationIdCounter;
    }

    /**
     * @notice Get total lab tests conducted
     * @return Total lab test count
     */
    function getTotalLabTests() external view returns (uint256) {
        return _labTestIdCounter;
    }

    /**
     * @notice Get total transition programs started
     * @return Total transition count
     */
    function getTotalTransitions() external view returns (uint256) {
        return _transitionIdCounter;
    }

    /**
     * @notice Get total practice logs submitted
     * @return Total practice log count
     */
    function getTotalPracticeLogs() external view returns (uint256) {
        return _practiceLogIdCounter;
    }

    /**
     * @notice Get supporting documents for a certificate
     * @param certId ID of the certificate
     * @return IPFS hash of supporting documents
     */
    function getCertificateSupportingDocs(uint256 certId) 
        external 
        view 
        returns (string memory) 
    {
        require(certificates[certId].certificateId != 0, "Certificate does not exist");
        return _certificateSupportingDocs[certId];
    }

    /**
     * @notice Get verification notes for a certificate
     * @param certId ID of the certificate
     * @return Verifier's notes
     */
    function getCertificateVerificationNotes(uint256 certId) 
        external 
        view 
        returns (string memory) 
    {
        require(certificates[certId].certificateId != 0, "Certificate does not exist");
        return _certificateVerificationNotes[certId];
    }

    /**
     * @notice Get authority ID by name
     * @param name Authority name
     * @return authorityId Numeric ID of the authority
     */
    function getAuthorityId(string memory name) 
        external 
        view 
        returns (uint256) 
    {
        return _authorityRegistry[name];
    }

    /**
     * @notice Verify tree ownership for any address
     * @dev Public function for external verification
     * @param treeId ID of the tree
     * @param owner Address to verify ownership
     * @return True if address owns the tree
     */
    function verifyTreeOwnership(uint256 treeId, address owner) 
        external 
        view 
        returns (bool) 
    {
        return _verifyTreeOwnership(treeId, owner);
    }

    /**
     * @notice Check if enhanced certificate is valid
     * @param certId ID of the certificate to check
     * @return True if certificate is active and verified
     */
    function isCertificateValid(uint256 certId) 
        external 
        view 
        returns (bool) 
    {
        require(certificates[certId].certificateId != 0, "Certificate does not exist");
        return _isCertificateActive(certificates[certId]);
    }

    /**
     * @notice Get paginated certificates for a tree
     * @dev Prevents gas limits with large datasets
     * @param treeId ID of the tree
     * @param page Page number (0-indexed)
     * @param pageSize Number of items per page
     * @return certificates Array of certificates for the page
     * @return total Total number of certificates
     */
    function getTreeActiveCertificatesPaginated(
        uint256 treeId, 
        uint256 page, 
        uint256 pageSize
    ) external view returns (Certificate[] memory certificates, uint256 total) {
        require(pageSize <= 100, "Page size too large");
        
        EnumerableSet.UintSet storage certIds = _treeCertificates[treeId];
        total = _countActiveCertificates(certIds);
        
        uint256 start = page * pageSize;
        if (start >= total) return (new Certificate[](0), total);
        
        uint256 end = start + pageSize > total ? total : start + pageSize;
        Certificate[] memory results = new Certificate[](end - start);
        uint256 resultIndex = 0;
        uint256 activeIndex = 0;
        
        for (uint256 i = 0; i < certIds.length() && activeIndex < end; i++) {
            uint256 certId = certIds.at(i);
            if (_isCertificateActive(certificates[certId])) {
                if (activeIndex >= start) {
                    results[resultIndex] = certificates[certId];
                    resultIndex++;
                }
                activeIndex++;
            }
        }
        
        return (results, total);
    }

    /**
     * @notice Batch expire multiple certifications
     * @dev Gas-efficient way to expire multiple certs
     * @param certificationIds Array of certification IDs to expire
     */
    function batchExpireCertifications(uint256[] calldata certificationIds) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(certificationIds.length <= MAX_BATCH_SIZE, "Batch size too large");
        
        for (uint256 i = 0; i < certificationIds.length; i++) {
            uint256 certId = certificationIds[i];
            if (certifications[certId].farmer == msg.sender && certifications[certId].isActive) {
                certifications[certId].isActive = false;
                emit CertificationExpired(certId, certifications[certId].treeId);
            }
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                    AUTHORITY MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    function registerAuthority(string memory name, uint256 id) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        validString(name) 
    {
        require(id > 0, "Invalid authority ID");
        _authorityRegistry[name] = id;
        emit AuthorityRegistered(name, id);
    }
    
    function authorizeLab(address labAddress, bool authorized) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        authorizedLabs[labAddress] = authorized;
        emit LabAuthorized(labAddress, authorized);
    }
    
    function authorizeCertifyingAuthority(address authorityAddress, bool authorized) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        certifyingAuthorities[authorityAddress] = authorized;
        emit AuthorityAuthorized(authorityAddress, authorized);
    }

    /**
     * @notice Grant verifier role to address
     * @dev Only admin can grant verifier role
     * @param verifier Address to grant verifier role
     */
    function grantVerifierRole(address verifier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(VERIFIER_ROLE, verifier);
    }

    /**
     * @notice Grant lab role to address
     * @dev Only admin can grant lab role
     * @param lab Address to grant lab role
     */
    function grantLabRole(address lab) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(LAB_ROLE, lab);
    }

    /**
     * @notice Grant authority role to address
     * @dev Only admin can grant authority role
     * @param authority Address to grant authority role
     */
    function grantAuthorityRole(address authority) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(AUTHORITY_ROLE, authority);
    }
    
    /*//////////////////////////////////////////////////////////////
                    ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function updateTreeIDAddress(address newTreeIDAddress) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newTreeIDAddress != address(0), "Invalid address");
        treeIDAddress = newTreeIDAddress;
        emit TreeIDAddressUpdated(newTreeIDAddress);
    }
    
    /*//////////////////////////////////////////////////////////////
                    INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    
    function _verifyTreeOwnership(uint256 treeId, address caller) 
        internal 
        view 
        returns (bool) 
    {
        try this._getTreeOwner(treeId) returns (address treeOwner) {
            return treeOwner == caller && treeOwner != address(0);
        } catch {
            return false;
        }
    }
    
    function _treeExists(uint256 treeId) internal view returns (bool) {
        try this._isTreeActive(treeId) returns (bool exists) {
            return exists;
        } catch {
            return false;
        }
    }
    
    function _getTreeOwner(uint256 treeId) public view returns (address) {
        (bool success, bytes memory data) = treeIDAddress.staticcall(
            abi.encodeWithSignature("getTreeById(uint256)", treeId)
        );
        
        if (!success || data.length == 0) {
            return address(0);
        }
        
        address treeOwner;
        assembly {
            treeOwner := mload(add(data, 64))
        }
        
        return treeOwner;
    }
    
    function _isTreeActive(uint256 treeId) public view returns (bool) {
        (bool success, bytes memory data) = treeIDAddress.staticcall(
            abi.encodeWithSignature("isTreeActiveById(uint256)", treeId)
        );
        
        if (!success || data.length == 0) {
            return false;
        }
        
        return abi.decode(data, (bool));
    }
    
    function _isCertificateActive(Certificate memory cert) 
        internal 
        view 
        returns (bool) 
    {
        return cert.isActive && 
               cert.expiryDate > block.timestamp && 
               cert.verificationStatus != VerificationStatus.Rejected;
    }

    /**
     * @dev Counts active certificates in a set
     */
    function _countActiveCertificates(EnumerableSet.UintSet storage certIds) 
        internal 
        view 
        returns (uint256) 
    {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < certIds.length(); i++) {
            if (_isCertificateActive(certificates[certIds.at(i)])) {
                activeCount++;
            }
        }
        return activeCount;
    }
    
    function _findAuthorityByName(string memory name) 
        internal 
        view 
        returns (uint256) 
    {
        return _authorityRegistry[name];
    }
    
    function _initializeDefaultAuthorities() internal {
        _authorityRegistry["NPOP (India)"] = 1;
        _authorityRegistry["USDA NOP (USA)"] = 2;
        _authorityRegistry["JAS (Japan)"] = 3;
        _authorityRegistry["EU Organic"] = 4;
        _authorityRegistry["GLOBALG.A.P."] = 5;
    }
    
    function _createEnhancedCertificate(
        uint256 certId,
        uint256 treeId,
        address farmer,
        CertificationType certType,
        CertificationSource source,
        string memory authorityName,
        string memory certificateNumber,
        uint256 issueDate,
        uint256 expiryDate,
        string memory ipfsHash
    ) internal {
        certificates[certId] = Certificate({
            certificateId: certId,
            treeId: treeId,
            farmer: farmer,
            certType: certType,
            source: source,
            verificationStatus: VerificationStatus.Verified,
            authorityId: _findAuthorityByName(authorityName),
            authorityName: authorityName,
            certificateNumber: certificateNumber,
            issueDate: issueDate,
            expiryDate: expiryDate,
            certificateDocumentHash: ipfsHash,
            verificationDate: block.timestamp,
            verifiedBy: msg.sender,
            isActive: true
        });
        
        _treeCertificates[treeId].add(certId);
        _farmerCertificates[farmer].add(certId);
    }
    
    function _mapCertificationType(string memory certType) 
        internal 
        pure 
        returns (CertificationType) 
    {
        bytes32 typeHash = keccak256(bytes(certType));
        
        if (typeHash == keccak256(bytes("Organic"))) return CertificationType.Organic;
        if (typeHash == keccak256(bytes("PesticideFree"))) return CertificationType.PesticideFree;
        if (typeHash == keccak256(bytes("InTransition"))) return CertificationType.InTransition;
        if (typeHash == keccak256(bytes("FairTrade"))) return CertificationType.FairTrade;
        if (typeHash == keccak256(bytes("Rainforest"))) return CertificationType.Rainforest;
        if (typeHash == keccak256(bytes("BirdFriendly"))) return CertificationType.BirdFriendly;
        if (typeHash == keccak256(bytes("Biodynamic"))) return CertificationType.Biodynamic;
        if (typeHash == keccak256(bytes("NaturallyGrown"))) return CertificationType.NaturallyGrown;
        if (typeHash == keccak256(bytes("GAP"))) return CertificationType.GAP;
        
        return CertificationType.Custom;
    }
    
    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
}

/*//////////////////////////////////////////////////////////////
                    VALIDATION LIBRARY
//////////////////////////////////////////////////////////////*/

/**
 * @title CertificationValidators
 * @notice Library for input validation functions
 * @dev Reusable validation logic to keep contract clean
 */
library CertificationValidators {
    
    /**
     * @notice Validates IPFS CIDv0 hash format
     * @dev Checks length and "Qm" prefix
     * @param hash IPFS hash to validate
     */
    function validateIPFSHash(string memory hash) internal pure {
        require(bytes(hash).length == 46, "IPFS hash must be 46 characters");
        require(
            bytes(hash)[0] == 'Q' && bytes(hash)[1] == 'm', 
            "IPFS hash must start with 'Qm'"
        );
    }
    
    /**
     * @notice Validates date range for certificates
     * @dev Checks logical ordering and maximum validity period
     * @param start Issue date
     * @param end Expiry date
     */
    function validateDateRange(uint256 start, uint256 end) internal view {
        require(start < end, "Issue date must be before expiry date");
        require(end > block.timestamp, "Expiry date must be in future");
        require(
            end - start <= 365 days * 5, 
            "Certificate validity cannot exceed 5 years"
        );
    }
}