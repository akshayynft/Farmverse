// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title ConsumerVerification
 * @dev Smart contract for consumer verification and feedback system
 * Allows consumers to verify products, provide ratings, and earn rewards
 */
contract ConsumerVerification is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    // Counter for verification IDs
    Counters.Counter private _verificationIdCounter;
    
    // Structure for consumer verification
    struct Verification {
        uint256 verificationId;
        uint256 batchId;
        address consumer;
        uint256 verificationDate;
        bool isAuthentic;
        string verificationNotes;
        uint256 rating; // 1-5 stars
        string feedback;
        bool isVerified;
        string ipfsHash; // For storing verification photos/documents
    }
    
    // Structure for consumer profile
    struct ConsumerProfile {
        address consumerAddress;
        string name;
        string email;
        uint256 totalVerifications;
        uint256 totalRatings;
        uint256 averageRating;
        uint256 rewardPoints;
        bool isActive;
        uint256 registrationDate;
    }
    
    // Structure for product authenticity check
    struct AuthenticityCheck {
        uint256 batchId;
        bool isAuthentic;
        string checkType; // "QR_Scan", "Manual_Check", "Lab_Test"
        uint256 checkDate;
        address checkedBy;
        string checkNotes;
        bool isVerified;
    }
    
    // Mappings
    mapping(uint256 => Verification) public verifications;
    mapping(address => ConsumerProfile) public consumerProfiles;
    mapping(uint256 => AuthenticityCheck[]) public batchAuthenticityChecks; // batchId to checks
    mapping(uint256 => uint256[]) public batchVerifications; // batchId to verification IDs
    mapping(address => uint256[]) public consumerVerifications; // consumer to verification IDs
    mapping(uint256 => uint256) public batchAverageRating; // batchId to average rating
    mapping(uint256 => uint256) public batchTotalRatings; // batchId to total ratings
    
    // Events
    event ConsumerRegistered(address indexed consumer, string name);
    event ProductVerified(uint256 indexed verificationId, uint256 indexed batchId, address indexed consumer);
    event RatingSubmitted(uint256 indexed batchId, uint256 rating, address indexed consumer);
    event AuthenticityChecked(uint256 indexed batchId, bool isAuthentic, address indexed checkedBy);
    event RewardPointsEarned(address indexed consumer, uint256 points);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Register a new consumer
     * @param name Consumer's name
     * @param email Consumer's email
     */
    function registerConsumer(string memory name, string memory email) external {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(email).length > 0, "Email cannot be empty");
        require(consumerProfiles[msg.sender].consumerAddress == address(0), "Consumer already registered");
        
        ConsumerProfile memory profile = ConsumerProfile({
            consumerAddress: msg.sender,
            name: name,
            email: email,
            totalVerifications: 0,
            totalRatings: 0,
            averageRating: 0,
            rewardPoints: 0,
            isActive: true,
            registrationDate: block.timestamp
        });
        
        consumerProfiles[msg.sender] = profile;
        
        emit ConsumerRegistered(msg.sender, name);
    }
    
    /**
     * @dev Verify a product batch
     * @param batchId The batch ID to verify
     * @param isAuthentic Whether the product is authentic
     * @param verificationNotes Notes about the verification
     * @param rating Product rating (1-5)
     * @param feedback Consumer feedback
     * @param ipfsHash IPFS hash for verification documents
     */
    function verifyProduct(
        uint256 batchId,
        bool isAuthentic,
        string memory verificationNotes,
        uint256 rating,
        string memory feedback,
        string memory ipfsHash
    ) external nonReentrant returns (uint256) {
        require(consumerProfiles[msg.sender].isActive, "Consumer must be registered and active");
        require(rating >= 1 && rating <= 5, "Rating must be 1-5");
        require(bytes(verificationNotes).length > 0, "Verification notes cannot be empty");
        
        _verificationIdCounter.increment();
        uint256 newVerificationId = _verificationIdCounter.current();
        
        Verification memory verification = Verification({
            verificationId: newVerificationId,
            batchId: batchId,
            consumer: msg.sender,
            verificationDate: block.timestamp,
            isAuthentic: isAuthentic,
            verificationNotes: verificationNotes,
            rating: rating,
            feedback: feedback,
            isVerified: true,
            ipfsHash: ipfsHash
        });
        
        verifications[newVerificationId] = verification;
        batchVerifications[batchId].push(newVerificationId);
        consumerVerifications[msg.sender].push(newVerificationId);
        
        // Update consumer profile
        consumerProfiles[msg.sender].totalVerifications++;
        consumerProfiles[msg.sender].totalRatings++;
        
        // Update batch ratings
        updateBatchRating(batchId, rating);
        
        // Award points for verification
        awardVerificationPoints(msg.sender, isAuthentic ? 10 : 5);
        
        emit ProductVerified(newVerificationId, batchId, msg.sender);
        emit RatingSubmitted(batchId, rating, msg.sender);
        
        return newVerificationId;
    }
    
    /**
     * @dev Check product authenticity (for authorized parties)
     * @param batchId The batch ID to check
     * @param isAuthentic Whether the product is authentic
     * @param checkType Type of check performed
     * @param checkNotes Notes about the check
     */
    function checkAuthenticity(
        uint256 batchId,
        bool isAuthentic,
        string memory checkType,
        string memory checkNotes
    ) external {
        require(consumerProfiles[msg.sender].isActive || msg.sender == owner(), "Not authorized");
        require(bytes(checkType).length > 0, "Check type cannot be empty");
        
        AuthenticityCheck memory check = AuthenticityCheck({
            batchId: batchId,
            isAuthentic: isAuthentic,
            checkType: checkType,
            checkDate: block.timestamp,
            checkedBy: msg.sender,
            checkNotes: checkNotes,
            isVerified: true
        });
        
        batchAuthenticityChecks[batchId].push(check);
        
        emit AuthenticityChecked(batchId, isAuthentic, msg.sender);
    }
    
    /**
     * @dev Get verification details
     * @param verificationId The verification ID
     * @return Complete verification data
     */
    function getVerification(uint256 verificationId) external view returns (Verification memory) {
        require(verifications[verificationId].verificationId != 0, "Verification does not exist");
        return verifications[verificationId];
    }
    
    /**
     * @dev Get all verifications for a batch
     * @param batchId The batch ID
     * @return Array of verification IDs
     */
    function getBatchVerifications(uint256 batchId) external view returns (uint256[] memory) {
        return batchVerifications[batchId];
    }
    
    /**
     * @dev Get all verifications by a consumer
     * @param consumer Address of the consumer
     * @return Array of verification IDs
     */
    function getConsumerVerifications(address consumer) external view returns (uint256[] memory) {
        return consumerVerifications[consumer];
    }
    
    /**
     * @dev Get consumer profile
     * @param consumer Address of the consumer
     * @return Consumer profile data
     */
    function getConsumerProfile(address consumer) external view returns (ConsumerProfile memory) {
        require(consumerProfiles[consumer].consumerAddress != address(0), "Consumer not found");
        return consumerProfiles[consumer];
    }
    
    /**
     * @dev Get authenticity checks for a batch
     * @param batchId The batch ID
     * @return Array of authenticity checks
     */
    function getBatchAuthenticityChecks(uint256 batchId) external view returns (AuthenticityCheck[] memory) {
        return batchAuthenticityChecks[batchId];
    }
    
    /**
     * @dev Get batch average rating
     * @param batchId The batch ID
     * @return Average rating (1-5)
     */
    function getBatchAverageRating(uint256 batchId) external view returns (uint256) {
        return batchAverageRating[batchId];
    }
    
    /**
     * @dev Get batch total ratings
     * @param batchId The batch ID
     * @return Total number of ratings
     */
    function getBatchTotalRatings(uint256 batchId) external view returns (uint256) {
        return batchTotalRatings[batchId];
    }
    
    /**
     * @dev Update batch rating statistics
     * @param batchId The batch ID
     * @param newRating The new rating to add
     */
    function updateBatchRating(uint256 batchId, uint256 newRating) internal {
        uint256 currentTotal = batchTotalRatings[batchId];
        uint256 currentAverage = batchAverageRating[batchId];
        
        uint256 newTotal = currentTotal + 1;
        uint256 newAverage = ((currentAverage * currentTotal) + newRating) / newTotal;
        
        batchTotalRatings[batchId] = newTotal;
        batchAverageRating[batchId] = newAverage;
    }
    
    /**
     * @dev Award verification points to consumer
     * @param consumer Address of the consumer
     * @param points Points to award
     */
    function awardVerificationPoints(address consumer, uint256 points) internal {
        consumerProfiles[consumer].rewardPoints += points;
        emit RewardPointsEarned(consumer, points);
    }
    
    /**
     * @dev Deactivate a consumer (only owner)
     * @param consumer Address of the consumer
     * @param active Whether to activate or deactivate
     */
    function setConsumerActive(address consumer, bool active) external onlyOwner {
        require(consumerProfiles[consumer].consumerAddress != address(0), "Consumer not found");
        consumerProfiles[consumer].isActive = active;
    }
    
    /**
     * @dev Get total number of verifications
     * @return Total count of verifications
     */
    function getTotalVerifications() external view returns (uint256) {
        return _verificationIdCounter.current();
    }
    
    /**
     * @dev Check if a consumer is registered and active
     * @param consumer Address of the consumer
     * @return True if consumer is registered and active
     */
    function isConsumerActive(address consumer) external view returns (bool) {
        return consumerProfiles[consumer].isActive;
    }
    
    /**
     * @dev Get verification statistics for a batch
     * @param batchId The batch ID
     * @return totalVerifications Total number of verifications
     * @return authenticCount Number of authentic verifications
     * @return averageRating Average rating
     * @return totalRatings Total number of ratings
     */
    function getBatchVerificationStats(uint256 batchId) external view returns (
        uint256 totalVerifications,
        uint256 authenticCount,
        uint256 averageRating,
        uint256 totalRatings
    ) {
        uint256[] memory verificationIds = batchVerifications[batchId];
        
        for (uint256 i = 0; i < verificationIds.length; i++) {
            Verification memory verification = verifications[verificationIds[i]];
            if (verification.isAuthentic) {
                authenticCount++;
            }
        }
        
        totalVerifications = verificationIds.length;
        averageRating = batchAverageRating[batchId];
        totalRatings = batchTotalRatings[batchId];
    }
}
