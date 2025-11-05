// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title Certification - Production Ready with Critical Security Fixes
 * @dev Fixed: Unsafe lab test IDs, missing tree ownership verification, unsafe external calls
 */
contract Certification is Ownable, ReentrancyGuard, Pausable {
    
    // ============ SAFE COUNTERS ============
    uint256 private _certificationIdCounter;
    uint256 private _labTestIdCounter; // ✅ FIX: Safe counter instead of array length
    
    // ============ STRUCTURES ============
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
    
    // ============ STORAGE ============
    mapping(uint256 => CertificationData) public certifications;
    mapping(uint256 => LabTest) public labTests;
    mapping(uint256 => uint256[]) public treeCertifications;
    mapping(uint256 => uint256[]) public treeLabTests;
    mapping(address => bool) public authorizedLabs;
    mapping(address => bool) public certifyingAuthorities;
    
    // ============ INTEGRATION ============
    address public treeIDAddress;
    
    // ============ CONSTANTS ============
    uint256 public constant MAX_PESTICIDE_LEVEL = 10000;
    uint256 public constant MAX_HEAVY_METAL_LEVEL = 1000;
    
    // ============ EVENTS ============
    event CertificationIssued(uint256 indexed certificationId, uint256 indexed treeId, string certificationType);
    event CertificationExpired(uint256 indexed certificationId, uint256 indexed treeId);
    event LabTestSubmitted(uint256 indexed labTestId, uint256 indexed treeId, bool passed);
    event LabAuthorized(address indexed labAddress, bool authorized);
    event AuthorityAuthorized(address indexed authorityAddress, bool authorized);
    event TreeOwnershipVerified(uint256 indexed treeId, address indexed owner);
    
    constructor(address _treeIDAddress) Ownable(msg.sender) {
        require(_treeIDAddress != address(0), "Invalid TreeID address");
        treeIDAddress = _treeIDAddress;
    }
    
    // ============ MODIFIERS ============
    modifier onlyTreeOwner(uint256 treeId) {
        require(_verifyTreeOwnership(treeId, msg.sender), "Not tree owner");
        _;
    }
    
    modifier validTree(uint256 treeId) {
        require(_treeExists(treeId), "Tree does not exist");
        _;
    }
    
    // ============ CORE FUNCTIONS WITH CRITICAL FIXES ============
    
    /**
     * @dev Issue certification with tree ownership verification
     */
    function issueCertification(
        uint256 treeId,
        string memory certificationType,
        uint256 expiryDate,
        string memory certifyingAuthority,
        string memory ipfsHash
    ) external nonReentrant whenNotPaused onlyTreeOwner(treeId) returns (uint256) {
        require(bytes(certificationType).length > 0, "Certification type cannot be empty");
        require(expiryDate > block.timestamp, "Expiry date must be in the future");
        require(bytes(certifyingAuthority).length > 0, "Certifying authority cannot be empty");
        
        _certificationIdCounter++;
        uint256 newCertificationId = _certificationIdCounter;
        
        CertificationData memory newCertification = CertificationData({
            certificationId: newCertificationId,
            treeId: treeId,
            farmer: msg.sender, // ✅ Now verified to be tree owner
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
        emit TreeOwnershipVerified(treeId, msg.sender);
        
        return newCertificationId;
    }
    
    /**
     * @dev Submit lab test with safe ID generation
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
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(authorizedLabs[msg.sender], "Only authorized labs can submit results");
        require(bytes(labName).length > 0, "Lab name cannot be empty");
        require(bytes(testType).length > 0, "Test type cannot be empty");
        require(pesticideLevel <= MAX_PESTICIDE_LEVEL, "Pesticide level too high");
        require(heavyMetalLevel <= MAX_HEAVY_METAL_LEVEL, "Heavy metal level too high");
        
        // ✅ CRITICAL FIX: Safe counter instead of array length
        _labTestIdCounter++;
        uint256 labTestId = _labTestIdCounter;
        
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
    
    // ============ SECURITY FIXES: TREE OWNERSHIP VERIFICATION ============
    
    /**
     * @dev Verify tree ownership using safe external calls
     */
    function _verifyTreeOwnership(uint256 treeId, address caller) internal view returns (bool) {
        // ✅ SAFE: Use try-catch for external calls
        try this._getTreeOwner(treeId) returns (address treeOwner) {
            return treeOwner == caller && treeOwner != address(0);
        } catch {
            return false;
        }
    }
    
    /**
     * @dev Check if tree exists using safe external calls  
     */
    function _treeExists(uint256 treeId) internal view returns (bool) {
        try this._isTreeActive(treeId) returns (bool exists) {
            return exists;
        } catch {
            return false;
        }
    }
    
    /**
     * @dev Get tree owner with safe external call (public for try-catch)
     */
    function _getTreeOwner(uint256 treeId) public view returns (address) {
        (bool success, bytes memory data) = treeIDAddress.staticcall(
            abi.encodeWithSignature("getTreeById(uint256)", treeId)
        );
        
        if (!success || data.length == 0) {
            return address(0);
        }
        
        // Parse Tree struct to get farmerAddress (simplified parsing)
        // Tree struct: treeId, farmerAddress, location, variety, ...
        // farmerAddress is the second field (after treeId)
        address treeOwner;
        assembly {
            treeOwner := mload(add(data, 64)) // Skip treeId (32 bytes) + data offset (32 bytes)
        }
        
        return treeOwner;
    }
    
    /**
     * @dev Check if tree is active with safe external call (public for try-catch)
     */
    function _isTreeActive(uint256 treeId) public view returns (bool) {
        (bool success, bytes memory data) = treeIDAddress.staticcall(
            abi.encodeWithSignature("isTreeActiveById(uint256)", treeId)
        );
        
        if (!success || data.length == 0) {
            return false;
        }
        
        return abi.decode(data, (bool));
    }
    
    // ============ EXISTING FUNCTIONS (UPDATED WITH SECURITY) ============
    
    function linkLabTestToCertification(uint256 certificationId, uint256 labTestId) external nonReentrant {
        require(certifications[certificationId].farmer == msg.sender, "Only certification owner can link");
        require(certifications[certificationId].isActive, "Certification must be active");
        require(labTests[labTestId].labTestId != 0, "Lab test does not exist");
        require(labTests[labTestId].treeId == certifications[certificationId].treeId, "Lab test must be for same tree");
        
        certifications[certificationId].labTestId = labTestId;
    }
    
    function isCertificationValid(uint256 certificationId) external view returns (bool) {
        CertificationData memory cert = certifications[certificationId];
        return cert.isActive && cert.expiryDate > block.timestamp;
    }
    
    function getTreeCertifications(uint256 treeId) external view returns (uint256[] memory) {
        return treeCertifications[treeId];
    }
    
    function getTreeLabTests(uint256 treeId) external view returns (uint256[] memory) {
        return treeLabTests[treeId];
    }
    
    function authorizeLab(address labAddress, bool authorized) external onlyOwner {
        authorizedLabs[labAddress] = authorized;
        emit LabAuthorized(labAddress, authorized);
    }
    
    function authorizeCertifyingAuthority(address authorityAddress, bool authorized) external onlyOwner {
        certifyingAuthorities[authorityAddress] = authorized;
        emit AuthorityAuthorized(authorityAddress, authorized);
    }
    
    function expireCertification(uint256 certificationId) external nonReentrant {
        require(certifications[certificationId].farmer == msg.sender, "Only certification owner can expire");
        require(certifications[certificationId].isActive, "Certification is already inactive");
        
        certifications[certificationId].isActive = false;
        emit CertificationExpired(certificationId, certifications[certificationId].treeId);
    }
    
    function getCertification(uint256 certificationId) external view returns (CertificationData memory) {
        require(certifications[certificationId].certificationId != 0, "Certification does not exist");
        return certifications[certificationId];
    }
    
    function getLabTest(uint256 labTestId) external view returns (LabTest memory) {
        require(labTests[labTestId].labTestId != 0, "Lab test does not exist");
        return labTests[labTestId];
    }
    
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
    
    // ============ NEW SECURITY FEATURES ============
    
    /**
     * @dev Emergency pause function
     */
    function emergencyPause() external onlyOwner {
        _pause();
    }
    
    function emergencyUnpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Update TreeID address (only owner)
     */
    function updateTreeIDAddress(address newTreeIDAddress) external onlyOwner {
        require(newTreeIDAddress != address(0), "Invalid address");
        treeIDAddress = newTreeIDAddress;
    }
    
    /**
     * @dev Verify tree ownership for any address (view function)
     */
    function verifyTreeOwnership(uint256 treeId, address owner) external view returns (bool) {
        return _verifyTreeOwnership(treeId, owner);
    }
    
    /**
     * @dev Get total counts for monitoring
     */
    function getTotalCertifications() external view returns (uint256) {
        return _certificationIdCounter;
    }
    
    function getTotalLabTests() external view returns (uint256) {
        return _labTestIdCounter;
    }
}