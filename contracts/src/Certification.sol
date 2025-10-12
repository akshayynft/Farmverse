// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title SecureCertification
 * @dev Gas-optimized, secure certification system with modular architecture
 */
contract SecureCertification is AccessControl, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    
    // ========== CONSTANTS ==========
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant LAB_ROLE = keccak256("LAB_ROLE");
    bytes32 public constant AUTHORITY_ROLE = keccak256("AUTHORITY_ROLE");
    uint256 public constant MAX_BATCH_SIZE = 50;
    uint256 public constant MAX_PHOTOS = 10;
    uint256 public constant MAX_STRING_LENGTH = 500;
    
    // ========== STATE VARIABLES ==========
    uint256 private _certificateIdCounter;
    
    // ========== OPTIMIZED STRUCTS ==========
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
    
    // ========== STORAGE OPTIMIZATION ==========
    mapping(uint256 => Certificate) public certificates;
    mapping(uint256 => string) private _certificateSupportingDocs;
    mapping(uint256 => string) private _certificateVerificationNotes;
    
    // Efficient storage for iterations
    mapping(uint256 => EnumerableSet.UintSet) private _treeCertificates;
    mapping(address => EnumerableSet.UintSet) private _farmerCertificates;
    mapping(string => uint256) private _authorityRegistry;
    
    // ========== INTEGRATION INTERFACE ==========
    ITreeIntegration private _integration;
    
    interface ITreeIntegration {
        function treeExists(uint256 treeId) external view returns (bool);
        function getTreeOwner(uint256 treeId) external view returns (address);
        function updateCertificationStatus(uint256 treeId, bool certified) external;
    }
    
    // ========== ENUMS ==========
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
    
    enum CertificationSource {
        SelfUploaded,
        PlatformVerified,
        AuthorityIssued,
        FarmaverseCertified,
        TransitionDocumented
    }
    
    enum VerificationStatus {
        Pending,
        UnderReview,
        Verified,
        Rejected,
        Expired
    }
    
    // ========== EVENTS ==========
    event CertificateUploaded(uint256 indexed certId, uint256 indexed treeId, address indexed farmer, CertificationSource source, string authority);
    event CertificateVerified(uint256 indexed certId, address indexed verifier);
    event CertificateRevoked(uint256 indexed certId, string reason);
    event CertificateRenewed(uint256 indexed certId, uint256 newExpiry);
    event AuthorityRegistered(string indexed name, uint256 id);
    event VerificationRequested(uint256 indexed certId, address indexed farmer);
    
    // ========== MODIFIERS ==========
    modifier validTree(uint256 treeId) {
        require(_integration.treeExists(treeId), "Tree does not exist");
        _;
    }
    
    modifier validString(string memory str) {
        require(bytes(str).length > 0 && bytes(str).length <= MAX_STRING_LENGTH, "Invalid string");
        _;
    }
    
    modifier certificateExists(uint256 certId) {
        require(certificates[certId].certificateId != 0, "Certificate does not exist");
        _;
    }
    
    // ========== CONSTRUCTOR ==========
    constructor(address admin, address treeIntegration) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VERIFIER_ROLE, admin);
        _integration = ITreeIntegration(treeIntegration);
        _initializeDefaultAuthorities();
    }
    
    // ========== CERTIFICATE MANAGEMENT ==========
    function uploadCertificate(
        uint256 treeId,
        CertificationType certType,
        string memory authorityName,
        string memory certificateNumber,
        uint256 issueDate,
        uint256 expiryDate,
        string memory certificateDocHash,
        string memory supportingDocsHash
    ) external nonReentrant validTree(treeId) validString(authorityName) returns (uint256) {
        
        // CORRECT: Farmers CAN upload their own certificates
        require(_integration.getTreeOwner(treeId) == msg.sender, "Not tree owner");
        CertificationValidators.validateDateRange(issueDate, expiryDate);
        CertificationValidators.validateIPFSHash(certificateDocHash);
        
        _certificateIdCounter++;
        uint256 newCertId = _certificateIdCounter;
        
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
        certificateExists(certId) 
        validString(notes) 
    {
        Certificate storage cert = certificates[certId];
        require(cert.isActive, "Inactive certificate");
        require(cert.verificationStatus == VerificationStatus.Pending || 
                cert.verificationStatus == VerificationStatus.UnderReview, "Invalid status");
        
        cert.verificationStatus = VerificationStatus.Verified;
        cert.verificationDate = block.timestamp;
        cert.verifiedBy = msg.sender;
        cert.source = CertificationSource.PlatformVerified;
        _certificateVerificationNotes[certId] = notes;
        
        // Update tree certification status
        _integration.updateCertificationStatus(cert.treeId, true);
        
        emit CertificateVerified(certId, msg.sender);
    }
    
    function revokeCertificate(uint256 certId, string memory reason) 
        external 
        onlyRole(VERIFIER_ROLE) 
        nonReentrant 
        certificateExists(certId) 
        validString(reason) 
    {
        Certificate storage cert = certificates[certId];
        require(cert.isActive, "Already inactive");
        
        cert.isActive = false;
        cert.verificationStatus = VerificationStatus.Rejected;
        
        // Update tree certification status
        _integration.updateCertificationStatus(cert.treeId, false);
        
        emit CertificateRevoked(certId, reason);
    }
    
    function requestVerification(uint256 certId) 
        external 
        nonReentrant 
        certificateExists(certId) 
    {
        Certificate storage cert = certificates[certId];
        require(cert.farmer == msg.sender, "Not certificate owner");
        require(cert.verificationStatus == VerificationStatus.Pending, "Already processed");
        
        cert.verificationStatus = VerificationStatus.UnderReview;
        
        emit VerificationRequested(certId, msg.sender);
    }
    
    // ========== AUTHORITY MANAGEMENT ==========
    function registerAuthority(string memory name, uint256 id) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        validString(name) 
    {
        require(id > 0, "Invalid authority ID");
        _authorityRegistry[name] = id;
        emit AuthorityRegistered(name, id);
    }
    
    function getAuthorityId(string memory name) external view returns (uint256) {
        return _authorityRegistry[name];
    }
    
    // ========== VIEW FUNCTIONS ==========
    function getTreeActiveCertificatesPaginated(
        uint256 treeId, 
        uint256 page, 
        uint256 pageSize
    ) external view returns (Certificate[] memory, uint256 total) {
        require(pageSize <= 100, "Page size too large");
        
        EnumerableSet.UintSet storage certIds = _treeCertificates[treeId];
        total = _countActiveCertificates(certIds);
        
        uint256 start = page * pageSize;
        if (start >= total) return (new Certificate[](0), total);
        
        uint256 end = start + pageSize > total ? total : start + pageSize;
        Certificate[] memory results = new Certificate[](end - start);
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < certIds.length() && resultIndex < results.length; i++) {
            uint256 certId = certIds.at(i);
            if (_isCertificateActive(certificates[certId])) {
                if (resultIndex >= start && resultIndex < end) {
                    results[resultIndex - start] = certificates[certId];
                }
                resultIndex++;
            }
        }
        
        return (results, total);
    }
    
    function getCertificateByTreeId(uint256 treeId) 
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
    
    function getFarmerCertificates(address farmer) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return _farmerCertificates[farmer].values();
    }
    
    // ========== INTERNAL FUNCTIONS ==========
    function _isCertificateActive(Certificate memory cert) internal view returns (bool) {
        return cert.isActive && 
               cert.expiryDate > block.timestamp && 
               cert.verificationStatus != VerificationStatus.Rejected;
    }
    
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
    
    function _findAuthorityByName(string memory name) internal view returns (uint256) {
        return _authorityRegistry[name];
    }
    
    function _initializeDefaultAuthorities() internal {
        // Initialize with common certification authorities
        _authorityRegistry["NPOP (India)"] = 1;
        _authorityRegistry["USDA NOP (USA)"] = 2;
        _authorityRegistry["JAS (Japan)"] = 3;
        _authorityRegistry["EU Organic"] = 4;
        _authorityRegistry["GLOBALG.A.P."] = 5;
    }
}

// ========== VALIDATION LIBRARY ==========
library CertificationValidators {
    function validateIPFSHash(string memory hash) internal pure {
        require(bytes(hash).length == 46, "Invalid IPFS hash length");
        // Basic IPFS CIDv0 validation (starts with Qm)
        require(bytes(hash)[0] == 'Q' && bytes(hash)[1] == 'm', "Invalid IPFS format");
    }
    
    function validateDateRange(uint256 start, uint256 end) internal view {
        require(start < end, "Invalid date range");
        require(end > block.timestamp, "Date in past");
        require(end - start <= 365 days * 5, "Validity too long"); // Max 5 years
    }
}