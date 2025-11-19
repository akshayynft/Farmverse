/*//////////////////////////////////////////////////////////////
                    BATCH CERTIFICATION OPERATIONS
//////////////////////////////////////////////////////////////*/

/**
 * @notice Batch upload certificates for multiple trees in a single transaction
 * @dev Essential for orchard management - reduces gas costs by 70-80%
 * @param treeIds Array of tree IDs to certify
 * @param certType Type of certification for all trees
 * @param authorityName Certifying authority name
 * @param certificateNumber Base certificate number (appended with tree IDs)
 * @param issueDate Certificate issue date
 * @param expiryDate Certificate expiry date
 * @param certificateDocHash IPFS hash of certificate document
 * @param supportingDocsHash IPFS hash of supporting documents
 * @return certIds Array of created certificate IDs
 */
function batchUploadCertificates(
    uint256[] memory treeIds,
    CertificationType certType,
    string memory authorityName,
    string memory certificateNumber,
    uint256 issueDate,
    uint256 expiryDate,
    string memory certificateDocHash,
    string memory supportingDocsHash
) external nonReentrant whenNotPaused returns (uint256[] memory certIds) {
    require(treeIds.length > 0 && treeIds.length <= MAX_BATCH_SIZE, "Invalid batch size");
    require(bytes(authorityName).length > 0, "Authority name required");
    require(bytes(certificateNumber).length > 0, "Certificate number required");
    CertificationValidators.validateDateRange(issueDate, expiryDate);
    CertificationValidators.validateIPFSHash(certificateDocHash);

    certIds = new uint256[](treeIds.length);
    
    for (uint256 i = 0; i < treeIds.length; i++) {
        // Validate tree ownership and existence
        require(_verifyTreeOwnership(treeIds[i], msg.sender), "Not tree owner");
        require(_treeExists(treeIds[i]), "Tree does not exist");
        
        _certificationIdCounter++;
        uint256 newCertId = _certificationIdCounter;
        
        certificates[newCertId] = Certificate({
            certificateId: newCertId,
            treeId: treeIds[i],
            farmer: msg.sender,
            certType: certType,
            source: CertificationSource.SelfUploaded,
            verificationStatus: VerificationStatus.Pending,
            authorityId: _findAuthorityByName(authorityName),
            authorityName: authorityName,
            certificateNumber: string(abi.encodePacked(certificateNumber, "-", _uintToString(treeIds[i]))),
            issueDate: issueDate,
            expiryDate: expiryDate,
            certificateDocumentHash: certificateDocHash,
            verificationDate: 0,
            verifiedBy: address(0),
            isActive: true
        });
        
        _certificateSupportingDocs[newCertId] = supportingDocsHash;
        _treeCertificates[treeIds[i]].add(newCertId);
        _farmerCertificates[msg.sender].add(newCertId);
        
        certIds[i] = newCertId;
        
        emit CertificateUploaded(newCertId, treeIds[i], msg.sender, CertificationSource.SelfUploaded, authorityName);
    }
    
    return certIds;
}

/**
 * @notice Batch start organic transition for multiple trees
 * @dev Critical for farmers transitioning entire orchards to organic
 * @param treeIds Array of tree IDs to start transition
 * @param chemicalFreeStartDate When chemical use stopped for all trees
 * @param transitionPlan IPFS hash of transition plan document
 * @return transitionIds Array of created transition record IDs
 */
function batchStartTransition(
    uint256[] memory treeIds,
    uint256 chemicalFreeStartDate,
    string memory transitionPlan
) external nonReentrant whenNotPaused returns (uint256[] memory transitionIds) {
    require(treeIds.length > 0 && treeIds.length <= MAX_BATCH_SIZE, "Invalid batch size");
    require(bytes(transitionPlan).length > 0, "Transition plan required");
    require(chemicalFreeStartDate <= block.timestamp, "Start date cannot be in future");
    require(chemicalFreeStartDate > block.timestamp - (5 * 365 days), "Start date too old");
    CertificationValidators.validateIPFSHash(transitionPlan);

    transitionIds = new uint256[](treeIds.length);
    uint256 targetDate = chemicalFreeStartDate + TRANSITION_PERIOD;
    
    for (uint256 i = 0; i < treeIds.length; i++) {
        require(_verifyTreeOwnership(treeIds[i], msg.sender), "Not tree owner");
        require(_treeExists(treeIds[i]), "Tree does not exist");
        
        _transitionIdCounter++;
        uint256 newTransitionId = _transitionIdCounter;
        uint256 currentProgress = block.timestamp - chemicalFreeStartDate;
        
        transitionRecords[newTransitionId] = TransitionRecord({
            transitionId: newTransitionId,
            treeId: treeIds[i],
            farmer: msg.sender,
            startDate: chemicalFreeStartDate,
            targetCompletionDate: targetDate,
            currentProgress: currentProgress,
            isCompleted: false,
            trustScore: 30,
            transitionPlan: transitionPlan
        });
        
        _treeTransitionRecords[treeIds[i]].add(newTransitionId);
        transitionIds[i] = newTransitionId;
        
        emit TransitionStarted(newTransitionId, treeIds[i], msg.sender, targetDate);
    }
    
    return transitionIds;
}

/**
 * @notice Batch log farming practices for multiple trees
 * @dev Essential for documenting orchard-wide farming activities
 * @param treeIds Array of tree IDs to log practices for
 * @param practiceType Type of farming practice performed
 * @param description Practice description
 * @param photoHash IPFS hash of photo evidence
 * @return logIds Array of created practice log IDs
 */
function batchLogPractices(
    uint256[] memory treeIds,
    PracticeType practiceType,
    string memory description,
    string memory photoHash
) external nonReentrant whenNotPaused returns (uint256[] memory logIds) {
    require(treeIds.length > 0 && treeIds.length <= MAX_BATCH_SIZE, "Invalid batch size");
    require(bytes(description).length > 0, "Description required");
    CertificationValidators.validateIPFSHash(photoHash);

    logIds = new uint256[](treeIds.length);
    
    for (uint256 i = 0; i < treeIds.length; i++) {
        require(_verifyTreeOwnership(treeIds[i], msg.sender), "Not tree owner");
        require(_treeExists(treeIds[i]), "Tree does not exist");
        
        _practiceLogIdCounter++;
        uint256 newLogId = _practiceLogIdCounter;
        
        practiceLogs[newLogId] = PracticeLog({
            logId: newLogId,
            treeId: treeIds[i],
            farmer: msg.sender,
            logDate: block.timestamp,
            practiceType: practiceType,
            description: description,
            photoHash: photoHash,
            isVerified: false,
            verifiedBy: address(0),
            trustScoreImpact: 0
        });
        
        _treePracticeLogs[treeIds[i]].add(newLogId);
        logIds[i] = newLogId;
        
        emit PracticeLogged(newLogId, treeIds[i], msg.sender, practiceType);
    }
    
    return logIds;
}

/**
 * @notice Batch verify multiple certificates
 * @dev Platform verifiers can efficiently verify orchard certifications
 * @param certIds Array of certificate IDs to verify
 * @param notes Verifier's notes for all certificates
 */
function batchVerifyCertificates(
    uint256[] memory certIds,
    string memory notes
) external onlyRole(VERIFIER_ROLE) nonReentrant whenNotPaused validString(notes) {
    require(certIds.length > 0 && certIds.length <= MAX_BATCH_SIZE, "Invalid batch size");

    for (uint256 i = 0; i < certIds.length; i++) {
        require(certificates[certIds[i]].certificateId != 0, "Certificate does not exist");
        Certificate storage cert = certificates[certIds[i]];
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
        _certificateVerificationNotes[certIds[i]] = notes;
        
        emit CertificateVerified(certIds[i], msg.sender);
    }
}

/**
 * @notice Batch revoke multiple certificates
 * @dev Platform verifiers can efficiently revoke fraudulent certifications
 * @param certIds Array of certificate IDs to revoke
 * @param reason Reason for revocation
 */
function batchRevokeCertificates(
    uint256[] memory certIds,
    string memory reason
) external onlyRole(VERIFIER_ROLE) nonReentrant whenNotPaused validString(reason) {
    require(certIds.length > 0 && certIds.length <= MAX_BATCH_SIZE, "Invalid batch size");

    for (uint256 i = 0; i < certIds.length; i++) {
        require(certificates[certIds[i]].certificateId != 0, "Certificate does not exist");
        Certificate storage cert = certificates[certIds[i]];
        require(cert.isActive, "Certificate already inactive");
        
        cert.isActive = false;
        cert.verificationStatus = VerificationStatus.Rejected;
        
        emit CertificateRevoked(certIds[i], reason);
    }
}

/**
 * @notice Batch update transition progress for multiple trees
 * @dev Farmers or verifiers can update progress across entire orchards
 * @param transitionIds Array of transition record IDs to update
 * @param trustScoreAdjustment Points to adjust for all transitions
 * @param isIncrease Whether to increase or decrease trust scores
 */
function batchUpdateTransitionProgress(
    uint256[] memory transitionIds,
    uint256 trustScoreAdjustment,
    bool isIncrease
) external nonReentrant whenNotPaused {
    require(transitionIds.length > 0 && transitionIds.length <= MAX_BATCH_SIZE, "Invalid batch size");

    for (uint256 i = 0; i < transitionIds.length; i++) {
        require(transitionRecords[transitionIds[i]].transitionId != 0, "Transition does not exist");
        TransitionRecord storage transition = transitionRecords[transitionIds[i]];
        require(
            msg.sender == transition.farmer || hasRole(VERIFIER_ROLE, msg.sender),
            "Not authorized"
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
        
        emit TransitionProgressUpdated(transitionIds[i], transition.currentProgress, transition.trustScore);
        
        if (transition.currentProgress >= TRANSITION_PERIOD && transition.trustScore >= 70) {
            _completeTransition(transitionIds[i]);
        }
    }
}

/*//////////////////////////////////////////////////////////////
                    BATCH VIEW FUNCTIONS
//////////////////////////////////////////////////////////////*/

/**
 * @notice Batch check certification validity for multiple trees
 * @dev Efficiently check organic certification status across orchards
 * @param treeIds Array of tree IDs to check
 * @return validity Array indicating if each tree has valid organic certification
 */
function batchHasValidOrganicCertification(uint256[] memory treeIds)
    external
    view
    returns (bool[] memory validity)
{
    require(treeIds.length <= MAX_BATCH_SIZE, "Batch size too large");
    
    validity = new bool[](treeIds.length);
    
    for (uint256 i = 0; i < treeIds.length; i++) {
        validity[i] = _hasValidOrganicCertification(treeIds[i]);
    }
    
    return validity;
}

/**
 * @notice Batch get trust scores for multiple trees
 * @dev Efficient trust score retrieval for orchard management
 * @param treeIds Array of tree IDs to get trust scores for
 * @return trustScores Array of trust scores for each tree
 */
function batchCalculateTrustScores(uint256[] memory treeIds)
    external
    view
    returns (uint256[] memory trustScores)
{
    require(treeIds.length <= MAX_BATCH_SIZE, "Batch size too large");
    
    trustScores = new uint256[](treeIds.length);
    
    for (uint256 i = 0; i < treeIds.length; i++) {
        trustScores[i] = calculateFarmerTrustScore(treeIds[i]);
    }
    
    return trustScores;
}

/*//////////////////////////////////////////////////////////////
                    INTERNAL BATCH HELPERS
//////////////////////////////////////////////////////////////*/

/**
 * @dev Internal helper to check organic certification for a tree
 */
function _hasValidOrganicCertification(uint256 treeId) internal view returns (bool) {
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