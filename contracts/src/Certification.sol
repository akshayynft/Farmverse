// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Certification
 * @dev Smart contract for managing organic certifications and lab test results
 * Links certifications to TreeIDs for complete traceability
 */
contract Certification is Ownable {
    using Counters for Counters.Counter;
    
    // Counter for certification IDs
    Counters.Counter private _certificationIdCounter;
    
    // Structure for certification data
    struct CertificationData {
        uint256 certificationId;
        uint256 treeId;
        address farmer;
        string certificationType; // "Organic", "Pesticide-Free", "Lab-Tested"
        uint256 issueDate;
        uint256 expiryDate;
        string certifyingAuthority;
        string ipfsHash; // For storing detailed certification documents
        bool isActive;
        uint256 labTestId; // Reference to lab test results
    }
    
    // Structure for lab test results
    struct LabTest {
        uint256 labTestId;
        uint256 treeId;
        string labName;
        uint256 testDate;
        string testType; // "Pesticide", "Heavy Metals", "Microbial"
        bool passed;
        string results; // IPFS hash for detailed results
        uint256 pesticideLevel; // PPM (Parts Per Million)
        uint256 heavyMetalLevel; // PPM
        bool microbialSafe;
    }
    
    // Mappings
    mapping(uint256 => CertificationData) public certifications;
    mapping(uint256 => LabTest) public labTests;
    mapping(uint256 => uint256[]) public treeCertifications; // TreeID to certification IDs
    mapping(uint256 => uint256[]) public treeLabTests; // TreeID to lab test IDs
    mapping(address => bool) public authorizedLabs; // Labs authorized to submit results
    mapping(address => bool) public certifyingAuthorities; // Authorized certifying bodies
    
    // Events
    event CertificationIssued(uint256 indexed certificationId, uint256 indexed treeId, string certificationType);
    event CertificationExpired(uint256 indexed certificationId, uint256 indexed treeId);
    event LabTestSubmitted(uint256 indexed labTestId, uint256 indexed treeId, bool passed);
    event LabAuthorized(address indexed labAddress, bool authorized);
    event AuthorityAuthorized(address indexed authorityAddress, bool authorized);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Issue a new certification for a tree
     * @param treeId The TreeID to certify
     * @param certificationType Type of certification
     * @param expiryDate When the certification expires
     * @param certifyingAuthority Name of the certifying authority
     * @param ipfsHash IPFS hash for certification documents
     */
    function issueCertification(
        uint256 treeId,
        string memory certificationType,
        uint256 expiryDate,
        string memory certifyingAuthority,
        string memory ipfsHash
    ) external returns (uint256) {
        require(bytes(certificationType).length > 0, "Certification type cannot be empty");
        require(expiryDate > block.timestamp, "Expiry date must be in the future");
        require(bytes(certifyingAuthority).length > 0, "Certifying authority cannot be empty");
        
        _certificationIdCounter.increment();
        uint256 newCertificationId = _certificationIdCounter.current();
        
        CertificationData memory newCertification = CertificationData({
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
        
        certifications[newCertificationId] = newCertification;
        treeCertifications[treeId].push(newCertificationId);
        
        emit CertificationIssued(newCertificationId, treeId, certificationType);
        
        return newCertificationId;
    }
    
    /**
     * @dev Submit lab test results (only authorized labs)
     * @param treeId The TreeID being tested
     * @param labName Name of the testing laboratory
     * @param testType Type of test performed
     * @param passed Whether the test passed
     * @param results IPFS hash for detailed results
     * @param pesticideLevel Pesticide level in PPM
     * @param heavyMetalLevel Heavy metal level in PPM
     * @param microbialSafe Whether microbial tests passed
     */
    function submitLabTest(
        uint256 treeId,
        string memory labName,
        string memory testType,
        bool passed,
        string memory results,
        uint256 pesticideLevel,
        uint256 heavyMetalLevel,
        bool microbialSafe
    ) external returns (uint256) {
        require(authorizedLabs[msg.sender], "Only authorized labs can submit results");
        require(bytes(labName).length > 0, "Lab name cannot be empty");
        require(bytes(testType).length > 0, "Test type cannot be empty");
        
        uint256 labTestId = treeLabTests[treeId].length + 1;
        
        LabTest memory newLabTest = LabTest({
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
        
        labTests[labTestId] = newLabTest;
        treeLabTests[treeId].push(labTestId);
        
        emit LabTestSubmitted(labTestId, treeId, passed);
        
        return labTestId;
    }
    
    /**
     * @dev Link lab test to certification
     * @param certificationId The certification ID
     * @param labTestId The lab test ID to link
     */
    function linkLabTestToCertification(uint256 certificationId, uint256 labTestId) external {
        require(certifications[certificationId].farmer == msg.sender, "Only certification owner can link");
        require(certifications[certificationId].isActive, "Certification must be active");
        require(labTests[labTestId].treeId == certifications[certificationId].treeId, "Lab test must be for same tree");
        
        certifications[certificationId].labTestId = labTestId;
    }
    
    /**
     * @dev Check if certification is valid
     * @param certificationId The certification ID to check
     * @return True if certification is active and not expired
     */
    function isCertificationValid(uint256 certificationId) external view returns (bool) {
        CertificationData memory cert = certifications[certificationId];
        return cert.isActive && cert.expiryDate > block.timestamp;
    }
    
    /**
     * @dev Get all certifications for a tree
     * @param treeId The TreeID to query
     * @return Array of certification IDs
     */
    function getTreeCertifications(uint256 treeId) external view returns (uint256[] memory) {
        return treeCertifications[treeId];
    }
    
    /**
     * @dev Get all lab tests for a tree
     * @param treeId The TreeID to query
     * @return Array of lab test IDs
     */
    function getTreeLabTests(uint256 treeId) external view returns (uint256[] memory) {
        return treeLabTests[treeId];
    }
    
    /**
     * @dev Authorize a laboratory (only owner)
     * @param labAddress Address of the laboratory
     * @param authorized Whether to authorize or revoke authorization
     */
    function authorizeLab(address labAddress, bool authorized) external onlyOwner {
        authorizedLabs[labAddress] = authorized;
        emit LabAuthorized(labAddress, authorized);
    }
    
    /**
     * @dev Authorize a certifying authority (only owner)
     * @param authorityAddress Address of the authority
     * @param authorized Whether to authorize or revoke authorization
     */
    function authorizeCertifyingAuthority(address authorityAddress, bool authorized) external onlyOwner {
        certifyingAuthorities[authorityAddress] = authorized;
        emit AuthorityAuthorized(authorityAddress, authorized);
    }
    
    /**
     * @dev Expire a certification
     * @param certificationId The certification ID to expire
     */
    function expireCertification(uint256 certificationId) external {
        require(certifications[certificationId].farmer == msg.sender, "Only certification owner can expire");
        require(certifications[certificationId].isActive, "Certification is already inactive");
        
        certifications[certificationId].isActive = false;
        emit CertificationExpired(certificationId, certifications[certificationId].treeId);
    }
    
    /**
     * @dev Get certification details
     * @param certificationId The certification ID
     * @return Complete certification data
     */
    function getCertification(uint256 certificationId) external view returns (CertificationData memory) {
        require(certifications[certificationId].certificationId != 0, "Certification does not exist");
        return certifications[certificationId];
    }
    
    /**
     * @dev Get lab test details
     * @param labTestId The lab test ID
     * @return Complete lab test data
     */
    function getLabTest(uint256 labTestId) external view returns (LabTest memory) {
        require(labTests[labTestId].labTestId != 0, "Lab test does not exist");
        return labTests[labTestId];
    }
    
    /**
     * @dev Check if a tree has valid organic certification
     * @param treeId The TreeID to check
     * @return True if tree has valid organic certification
     */
    function hasValidOrganicCertification(uint256 treeId) external view returns (bool) {
        uint256[] memory certIds = treeCertifications[treeId];
        
        for (uint256 i = 0; i < certIds.length; i++) {
            CertificationData memory cert = certifications[certIds[i]];
            if (cert.isActive && 
                cert.expiryDate > block.timestamp && 
                keccak256(bytes(cert.certificationType)) == keccak256(bytes("Organic"))) {
                return true;
            }
        }
        return false;
    }
} 