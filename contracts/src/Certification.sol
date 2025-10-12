// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Certification
 * @dev Complete flexible certification system for Farmaverse
 * 
 * Features:
 * 1. Self-uploaded certificates (farmers upload existing certificates)
 * 2. Organic transition tracking (3-year conversion period)
 * 3. Practice documentation (fertilizers, pesticides with photos)
 * 4. Platform verification system
 * 5. Lab testing integration
 * 6. Authority onboarding ready (future)
 * 7. Farmaverse own certification program (future)
 * 
 * Philosophy: Work with what farmers HAVE, not what we wish they had
 */
contract Certification is Ownable {
    
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
    
    enum TransitionYear {
        NotInTransition,
        FirstYear,
        SecondYear,
        ThirdYear,
        Completed
    }
    
    enum PracticeType {
        Fertilizer,
        PestControl,
        WeedControl,
        SoilManagement,
        WaterManagement,
        Composting,
        GreenManure,
        CropRotation,
        BioControl,
        Mulching,
        GeneralPractice
    }
    
    // ========== STRUCTS ==========
    
    struct Certificate {
        uint256 certificateId;
        uint256 treeId;
        address farmer;
        CertificationType certType;
        CertificationSource source;
        VerificationStatus verificationStatus;
        uint256 authorityId;
        string authorityName;
        string certificateNumber;
        uint256 issueDate;
        uint256 expiryDate;
        uint256 uploadDate;
        uint256 verificationDate;
        string certificateDocumentHash;
        string supportingDocsHash;
        address verifiedBy;
        string verificationNotes;
        bool isActive;
        uint256 lastUpdateDate;
    }
    
    struct OrganicTransition {
        uint256 transitionId;
        uint256 treeId;
        address farmer;
        uint256 transitionStartDate;
        uint256 lastChemicalUseDate;
        TransitionYear currentYear;
        bool isComplete;
        uint256[] practiceRecordIds;
        string transitionPlanHash;
        string soilTestResultsHash;
        bool isPlatformVerified;
        address verifiedBy;
        uint256 verificationDate;
        string verificationNotes;
        uint256 yearOneCompletionDate;
        uint256 yearTwoCompletionDate;
        uint256 yearThreeCompletionDate;
        uint256 createdDate;
        uint256 lastUpdateDate;
    }
    
    struct PracticeRecord {
        uint256 recordId;
        uint256 treeId;
        uint256 transitionId;
        address farmer;
        PracticeType practiceType;
        uint256 applicationDate;
        string practiceDescription;
        string productName;
        string productBrand;
        bool isOrganic;
        bool isCertifiedOrganic;
        string productCertificateHash;
        string[] photoHashes;
        string methodDocumentHash;
        string invoiceHash;
        string dosage;
        string applicationMethod;
        string targetCrop;
        string coordinates;
        bool isPlatformVerified;
        address verifiedBy;
        uint256 verificationDate;
        uint256 createdDate;
    }
    
    struct LabTest {
        uint256 labTestId;
        uint256 treeId;
        uint256 certificateId;
        address labAddress;
        string labName;
        string labAccreditation;
        uint256 testDate;
        string testType;
        bool passed;
        string resultsIpfsHash;
        uint256 pesticideLevel;
        uint256 heavyMetalLevel;
        bool microbialSafe;
        string[] testParameters;
        string methodology;
        string nitrogenLevel;
        string phosphorusLevel;
        string potassiumLevel;
        string phLevel;
        string organicMatterPercentage;
        uint256 createdDate;
    }
    
    struct CertificationAuthority {
        string name;
        string country;
        bool isRegistered;
        bool isActive;
        address authorizedAddress;
        string contactInfo;
        string[] standards;
        uint256 registeredDate;
    }
    
    struct VerificationRequest {
        uint256 requestId;
        uint256 certificateId;
        uint256 requestDate;
        address requestedBy;
        string farmerNotes;
        bool isProcessed;
        uint256 processedDate;
        address processedBy;
        string reviewNotes;
    }
    
    // ========== STATE VARIABLES ==========
    
    uint256 private _certificateIdCounter;
    uint256 private _authorityIdCounter;
    uint256 private _requestIdCounter;
    uint256 private _transitionIdCounter;
    uint256 private _practiceRecordIdCounter;
    uint256 private _labTestIdCounter;
    
    mapping(uint256 => Certificate) public certificates;
    mapping(uint256 => CertificationAuthority) public authorities;
    mapping(uint256 => VerificationRequest) public verificationRequests;
    mapping(uint256 => OrganicTransition) public organicTransitions;
    mapping(uint256 => PracticeRecord) public practiceRecords;
    mapping(uint256 => LabTest) public labTests;
    
    mapping(uint256 => uint256[]) public treeCertificates;
    mapping(address => uint256[]) public farmerCertificates;
    mapping(uint256 => uint256) public treeTransition;
    mapping(uint256 => uint256[]) public treePracticeRecords;
    mapping(uint256 => uint256[]) public treeLabTests;
    mapping(uint256 => uint256[]) public transitionPracticeRecords;
    
    mapping(address => bool) public platformVerifiers;
    mapping(address => bool) public authorizedLabs;
    mapping(address => bool) public trustedFarmers;
    
    // ========== EVENTS ==========
    
    event CertificateUploaded(
        uint256 indexed certificateId,
        uint256 indexed treeId,
        address indexed farmer,
        CertificationSource source,
        string authorityName
    );
    
    event TransitionStarted(
        uint256 indexed transitionId,
        uint256 indexed treeId,
        address indexed farmer,
        uint256 startDate
    );
    
    event PracticeDocumented(
        uint256 indexed recordId,
        uint256 indexed treeId,
        address indexed farmer,
        PracticeType practiceType,
        string productName
    );
    
    event TransitionYearCompleted(
        uint256 indexed transitionId,
        uint256 indexed treeId,
        TransitionYear year
    );
    
    event LabTestSubmitted(
        uint256 indexed labTestId,
        uint256 indexed treeId,
        bool passed
    );
    
    event CertificateVerified(
        uint256 indexed certificateId,
        address indexed verifier,
        VerificationStatus status
    );
    
    event VerificationRequested(
        uint256 indexed requestId,
        uint256 indexed certificateId
    );
    
    event AuthorityOnboarded(
        uint256 indexed authorityId,
        string name,
        address authorizedAddress
    );
    
    event LabAuthorized(address indexed labAddress, bool authorized);
    event AuthorityAuthorized(address indexed authorityAddress, bool authorized);
    
    // ========== CONSTRUCTOR ==========
    
    constructor() Ownable(msg.sender) {
        _initializeCommonAuthorities();
    }
    
    function _initializeCommonAuthorities() internal {
        string[12] memory authorityNames = [
            "NPOP (India)",
            "USDA NOP (USA)",
            "JAS (Japan)",
            "EU Organic",
            "GLOBALG.A.P.",
            "Rainforest Alliance",
            "Fair Trade",
            "IFOAM",
            "Demeter (Biodynamic)",
            "Control Union",
            "Ecocert",
            "Self-Certified"
        ];
        
        for (uint256 i = 0; i < authorityNames.length; i++) {
            _authorityIdCounter++;
            authorities[_authorityIdCounter] = CertificationAuthority({
                name: authorityNames[i],
                country: "",
                isRegistered: false,
                isActive: true,
                authorizedAddress: address(0),
                contactInfo: "",
                standards: new string[](0),
                registeredDate: block.timestamp
            });
        }
    }
    
    // ========== CERTIFICATE FUNCTIONS ==========
    
    function uploadCertificate(
        uint256 treeId,
        CertificationType certType,
        string memory authorityName,
        string memory certificateNumber,
        uint256 issueDate,
        uint256 expiryDate,
        string memory certificateDocHash,
        string memory supportingDocsHash,
        string memory notes
    ) external returns (uint256) {
        require(bytes(certificateDocHash).length > 0, "Certificate document required");
        require(expiryDate > block.timestamp, "Certificate already expired");
        require(issueDate < expiryDate, "Invalid date range");
        
        _certificateIdCounter++;
        uint256 newCertId = _certificateIdCounter;
        
        uint256 authorityId = _findAuthorityByName(authorityName);
        
        certificates[newCertId] = Certificate({
            certificateId: newCertId,
            treeId: treeId,
            farmer: msg.sender,
            certType: certType,
            source: CertificationSource.SelfUploaded,
            verificationStatus: VerificationStatus.Pending,
            authorityId: authorityId,
            authorityName: authorityName,
            certificateNumber: certificateNumber,
            issueDate: issueDate,
            expiryDate: expiryDate,
            uploadDate: block.timestamp,
            verificationDate: 0,
            certificateDocumentHash: certificateDocHash,
            supportingDocsHash: supportingDocsHash,
            verifiedBy: address(0),
            verificationNotes: notes,
            isActive: true,
            lastUpdateDate: block.timestamp
        });
        
        treeCertificates[treeId].push(newCertId);
        farmerCertificates[msg.sender].push(newCertId);
        
        emit CertificateUploaded(newCertId, treeId, msg.sender, CertificationSource.SelfUploaded, authorityName);
        
        return newCertId;
    }
    
    function requestVerification(
        uint256 certificateId,
        string memory farmerNotes
    ) external returns (uint256) {
        Certificate storage cert = certificates[certificateId];
        require(cert.farmer == msg.sender, "Not certificate owner");
        require(cert.verificationStatus == VerificationStatus.Pending, "Already processed");
        
        _requestIdCounter++;
        uint256 requestId = _requestIdCounter;
        
        verificationRequests[requestId] = VerificationRequest({
            requestId: requestId,
            certificateId: certificateId,
            requestDate: block.timestamp,
            requestedBy: msg.sender,
            farmerNotes: farmerNotes,
            isProcessed: false,
            processedDate: 0,
            processedBy: address(0),
            reviewNotes: ""
        });
        
        cert.verificationStatus = VerificationStatus.UnderReview;
        
        emit VerificationRequested(requestId, certificateId);
        
        return requestId;
    }
    
    function verifyCertificate(
        uint256 certificateId,
        bool approved,
        string memory reviewNotes
    ) external {
        require(platformVerifiers[msg.sender] || msg.sender == owner(), "Not authorized");
        
        Certificate storage cert = certificates[certificateId];
        require(cert.verificationStatus == VerificationStatus.UnderReview, "Not under review");
        
        if (approved) {
            cert.verificationStatus = VerificationStatus.Verified;
            cert.source = CertificationSource.PlatformVerified;
        } else {
            cert.verificationStatus = VerificationStatus.Rejected;
        }
        
        cert.verifiedBy = msg.sender;
        cert.verificationDate = block.timestamp;
        cert.verificationNotes = reviewNotes;
        
        emit CertificateVerified(certificateId, msg.sender, cert.verificationStatus);
    }
    
    // ========== ORGANIC TRANSITION FUNCTIONS ==========
    
    function startOrganicTransition(
        uint256 treeId,
        uint256 lastChemicalUseDate,
        string memory transitionPlanHash,
        string memory notes
    ) external returns (uint256) {
        require(treeTransition[treeId] == 0, "Transition already exists");
        require(lastChemicalUseDate <= block.timestamp, "Last chemical use cannot be in future");
        require(bytes(transitionPlanHash).length > 0, "Transition plan required");
        
        _transitionIdCounter++;
        uint256 newTransitionId = _transitionIdCounter;
        
        uint256 daysSinceLastChemical = (block.timestamp - lastChemicalUseDate) / 86400;
        TransitionYear currentYear;
        
        if (daysSinceLastChemical < 365) {
            currentYear = TransitionYear.FirstYear;
        } else if (daysSinceLastChemical < 730) {
            currentYear = TransitionYear.SecondYear;
        } else if (daysSinceLastChemical < 1095) {
            currentYear = TransitionYear.ThirdYear;
        } else {
            currentYear = TransitionYear.Completed;
        }
        
        organicTransitions[newTransitionId] = OrganicTransition({
            transitionId: newTransitionId,
            treeId: treeId,
            farmer: msg.sender,
            transitionStartDate: lastChemicalUseDate,
            lastChemicalUseDate: lastChemicalUseDate,
            currentYear: currentYear,
            isComplete: currentYear == TransitionYear.Completed,
            practiceRecordIds: new uint256[](0),
            transitionPlanHash: transitionPlanHash,
            soilTestResultsHash: "",
            isPlatformVerified: false,
            verifiedBy: address(0),
            verificationDate: 0,
            verificationNotes: notes,
            yearOneCompletionDate: 0,
            yearTwoCompletionDate: 0,
            yearThreeCompletionDate: 0,
            createdDate: block.timestamp,
            lastUpdateDate: block.timestamp
        });
        
        treeTransition[treeId] = newTransitionId;
        
        _certificateIdCounter++;
        uint256 certId = _certificateIdCounter;
        
        certificates[certId] = Certificate({
            certificateId: certId,
            treeId: treeId,
            farmer: msg.sender,
            certType: CertificationType.InTransition,
            source: CertificationSource.TransitionDocumented,
            verificationStatus: VerificationStatus.Pending,
            authorityId: 0,
            authorityName: "In Organic Transition",
            certificateNumber: string.concat("TRANS-", _toString(newTransitionId)),
            issueDate: block.timestamp,
            expiryDate: lastChemicalUseDate + 1095 days,
            uploadDate: block.timestamp,
            verificationDate: 0,
            certificateDocumentHash: transitionPlanHash,
            supportingDocsHash: "",
            verifiedBy: address(0),
            verificationNotes: notes,
            isActive: true,
            lastUpdateDate: block.timestamp
        });
        
        treeCertificates[treeId].push(certId);
        farmerCertificates[msg.sender].push(certId);
        
        emit TransitionStarted(newTransitionId, treeId, msg.sender, lastChemicalUseDate);
        
        return newTransitionId;
    }
    
    function documentPractice(
        uint256 treeId,
        PracticeType practiceType,
        string memory practiceDescription,
        string memory productName,
        string memory productBrand,
        bool isOrganic,
        bool isCertifiedOrganic,
        string memory productCertificateHash,
        string[] memory photoHashes,
        string memory methodDocumentHash,
        string memory invoiceHash,
        string memory dosage,
        string memory applicationMethod,
        string memory coordinates
    ) external returns (uint256) {
        require(bytes(practiceDescription).length > 0, "Practice description required");
        require(photoHashes.length > 0, "At least one photo required");
        
        _practiceRecordIdCounter++;
        uint256 newRecordId = _practiceRecordIdCounter;
        
        uint256 transitionId = treeTransition[treeId];
        
        practiceRecords[newRecordId] = PracticeRecord({
            recordId: newRecordId,
            treeId: treeId,
            transitionId: transitionId,
            farmer: msg.sender,
            practiceType: practiceType,
            applicationDate: block.timestamp,
            practiceDescription: practiceDescription,
            productName: productName,
            productBrand: productBrand,
            isOrganic: isOrganic,
            isCertifiedOrganic: isCertifiedOrganic,
            productCertificateHash: productCertificateHash,
            photoHashes: photoHashes,
            methodDocumentHash: methodDocumentHash,
            invoiceHash: invoiceHash,
            dosage: dosage,
            applicationMethod: applicationMethod,
            targetCrop: "",
            coordinates: coordinates,
            isPlatformVerified: false,
            verifiedBy: address(0),
            verificationDate: 0,
            createdDate: block.timestamp
        });
        
        treePracticeRecords[treeId].push(newRecordId);
        
        if (transitionId > 0) {
            organicTransitions[transitionId].practiceRecordIds.push(newRecordId);
            transitionPracticeRecords[transitionId].push(newRecordId);
        }
        
        emit PracticeDocumented(newRecordId, treeId, msg.sender, practiceType, productName);
        
        return newRecordId;
    }
    
    function completeTransitionYear(
        uint256 transitionId,
        TransitionYear completedYear,
        string memory soilTestResultsHash
    ) external {
        OrganicTransition storage transition = organicTransitions[transitionId];
        require(transition.farmer == msg.sender || msg.sender == owner(), "Not authorized");
        require(!transition.isComplete, "Transition already complete");
        
        if (completedYear == TransitionYear.FirstYear) {
            transition.yearOneCompletionDate = block.timestamp;
            transition.currentYear = TransitionYear.SecondYear;
        } else if (completedYear == TransitionYear.SecondYear) {
            transition.yearTwoCompletionDate = block.timestamp;
            transition.currentYear = TransitionYear.ThirdYear;
        } else if (completedYear == TransitionYear.ThirdYear) {
            transition.yearThreeCompletionDate = block.timestamp;
            transition.currentYear = TransitionYear.Completed;
            transition.isComplete = true;
        }
        
        if (bytes(soilTestResultsHash).length > 0) {
            transition.soilTestResultsHash = soilTestResultsHash;
        }
        
        transition.lastUpdateDate = block.timestamp;
        
        emit TransitionYearCompleted(transitionId, transition.treeId, completedYear);
    }
    
    function verifyTransition(
        uint256 transitionId,
        bool approved,
        string memory verificationNotes
    ) external {
        require(platformVerifiers[msg.sender] || msg.sender == owner(), "Not authorized");
        
        OrganicTransition storage transition = organicTransitions[transitionId];
        
        transition.isPlatformVerified = approved;
        transition.verifiedBy = msg.sender;
        transition.verificationDate = block.timestamp;
        transition.verificationNotes = verificationNotes;
        transition.lastUpdateDate = block.timestamp;
        
        uint256[] memory certIds = treeCertificates[transition.treeId];
        for (uint256 i = 0; i < certIds.length; i++) {
            Certificate storage cert = certificates[certIds[i]];
            if (cert.certType == CertificationType.InTransition) {
                if (approved) {
                    cert.verificationStatus = VerificationStatus.Verified;
                    cert.source = CertificationSource.PlatformVerified;
                } else {
                    cert.verificationStatus = VerificationStatus.Rejected;
                }
                cert.verifiedBy = msg.sender;
                cert.verificationDate = block.timestamp;
                break;
            }
        }
    }
    
    // ========== LAB TEST FUNCTIONS ==========
    
    function submitLabTest(
        uint256 treeId,
        uint256 certificateId,
        string memory labName,
        string memory labAccreditation,
        string memory testType,
        bool passed,
        string memory resultsIpfsHash,
        uint256 pesticideLevel,
        uint256 heavyMetalLevel,
        bool microbialSafe,
        string[] memory testParameters,
        string memory methodology,
        string memory nitrogenLevel,
        string memory phosphorusLevel,
        string memory potassiumLevel,
        string memory phLevel,
        string memory organicMatterPercentage
    ) external returns (uint256) {
        require(authorizedLabs[msg.sender] || msg.sender == owner(), "Not authorized lab");
        require(bytes(labName).length > 0, "Lab name required");
        
        _labTestIdCounter++;
        uint256 newLabTestId = _labTestIdCounter;
        
        labTests[newLabTestId] = LabTest({
            labTestId: newLabTestId,
            treeId: treeId,
            certificateId: certificateId,
            labAddress: msg.sender,
            labName: labName,
            labAccreditation: labAccreditation,
            testDate: block.timestamp,
            testType: testType,
            passed: passed,
            resultsIpfsHash: resultsIpfsHash,
            pesticideLevel: pesticideLevel,
            heavyMetalLevel: heavyMetalLevel,
            microbialSafe: microbialSafe,
            testParameters: testParameters,
            methodology: methodology,
            nitrogenLevel: nitrogenLevel,
            phosphorusLevel: phosphorusLevel,
            potassiumLevel: potassiumLevel,
            phLevel: phLevel,
            organicMatterPercentage: organicMatterPercentage,
            createdDate: block.timestamp
        });
        
        treeLabTests[treeId].push(newLabTestId);
        
        emit LabTestSubmitted(newLabTestId, treeId, passed);
        
        return newLabTestId;
    }
    
    // ========== AUTHORITY INTEGRATION ==========
    
    function onboardAuthority(
        uint256 authorityId,
        address authorizedAddress,
        string memory country,
        string memory contactInfo,
        string[] memory standards
    ) external onlyOwner {
        CertificationAuthority storage authority = authorities[authorityId];
        require(!authority.isRegistered, "Authority already onboarded");
        require(authorizedAddress != address(0), "Invalid address");
        
        authority.isRegistered = true;
        authority.authorizedAddress = authorizedAddress;
        authority.country = country;
        authority.contactInfo = contactInfo;
        authority.standards = standards;
        authority.registeredDate = block.timestamp;
        
        emit AuthorityOnboarded(authorityId, authority.name, authorizedAddress);
    }
    
    function issueAuthorityCertificate(
        uint256 treeId,
        address farmer,
        CertificationType certType,
        string memory certificateNumber,
        uint256 validityDays,
        string memory certificateDocHash,
        string memory notes
    ) external returns (uint256) {
        uint256 authorityId = _getAuthorityIdByAddress(msg.sender);
        require(authorityId > 0, "Not a registered authority");
        require(authorities[authorityId].isRegistered, "Authority not onboarded");
        
        _certificateIdCounter++;
        uint256 newCertId = _certificateIdCounter;
        
        certificates[newCertId] = Certificate({
            certificateId: newCertId,
            treeId: treeId,
            farmer: farmer,
            certType: certType,
            source: CertificationSource.AuthorityIssued,
            verificationStatus: VerificationStatus.Verified,
            authorityId: authorityId,
            authorityName: authorities[authorityId].name,
            certificateNumber: certificateNumber,
            issueDate: block.timestamp,
            expiryDate: block.timestamp + (validityDays * 1 days),
            uploadDate: block.timestamp,
            verificationDate: block.timestamp,
            certificateDocumentHash: certificateDocHash,
            supportingDocsHash: "",
            verifiedBy: msg.sender,
            verificationNotes: notes,
            isActive: true,
            lastUpdateDate: block.timestamp
        });
        
        treeCertificates[treeId].push(newCertId);
        farmerCertificates[farmer].push(newCertId);
        
        emit CertificateUploaded(newCertId, treeId, farmer, CertificationSource.AuthorityIssued, authorities[authorityId].name);
        
        return newCertId;
    }
    
    // ========== FARMAVERSE CERTIFICATION ==========
    
    function issueFarmaverseCertificate(
        uint256 treeId,
        address farmer,
        CertificationType certType,
        uint256 validityDays,
        string memory certificateDocHash,
        string memory inspectionReport
    ) external onlyOwner returns (uint256) {
        _certificateIdCounter++;
        uint256 newCertId = _certificateIdCounter;
        
        certificates[newCertId] = Certificate({
            certificateId: newCertId,
            treeId: treeId,
            farmer: farmer,
            certType: certType,
            source: CertificationSource.FarmaverseCertified,
            verificationStatus: VerificationStatus.Verified,
            authorityId: 0,
            authorityName: "Farmaverse Certified",
            certificateNumber: string.concat("FV-", _toString(newCertId)),
            issueDate: block.timestamp,
            expiryDate: block.timestamp + (validityDays * 1 days),
            uploadDate: block.timestamp,
            verificationDate: block.timestamp,
            certificateDocumentHash: certificateDocHash,
            supportingDocsHash: inspectionReport,
            verifiedBy: msg.sender,
            verificationNotes: "Farmaverse platform certification",
            isActive: true,
            lastUpdateDate: block.timestamp
        });
        
        treeCertificates[treeId].push(newCertId);
        farmerCertificates[farmer].push(newCertId);
        
        emit CertificateUploaded(newCertId, treeId, farmer, CertificationSource.FarmaverseCertified, "Farmaverse Certified");
        
        return newCertId;
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    function getCertificate(uint256 certificateId) external view returns (Certificate memory) {
        return certificates[certificateId];
    }
    
    function getTreeCertificates(uint256 treeId) external view returns (Certificate[] memory certs) {
        uint256[] memory certIds = treeCertificates[treeId];
        certs = new Certificate[](certIds.length);
        for (uint256 i = 0; i < certIds.length; i++) {
            certs[i] = certificates[certIds[i]];
        }
        return certs;
    }
    
    function getTreeActiveCertificates(uint256 treeId) external view returns (Certificate[] memory activeCerts) {
        uint256[] memory certIds = treeCertificates[treeId];
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < certIds.length; i++) {
            if (_isCertificateActive(certificates[certIds[i]])) {
                activeCount++;
            }
        }
        
        activeCerts = new Certificate[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < certIds.length; i++) {
            Certificate memory cert = certificates[certIds[i]];
            if (_isCertificateActive(cert)) {
                activeCerts[index] = cert;
                index++;
            }
        }
        
        return activeCerts;
    }
    
    function getFarmerCertificates(address farmer) external view returns (uint256[] memory) {
        return farmerCertificates[farmer];
    }
    
    function getCertificateTrustLevel(uint256 certificateId) external view returns (uint256 trustLevel, string memory trustLabel) {
        Certificate memory cert = certificates[certificateId];
        
        if (cert.source == CertificationSource.AuthorityIssued) {
            return (3, "Authority Verified");
        } else if (cert.source == CertificationSource.FarmaverseCertified) {
            return (2, "Farmaverse Certified");
        } else if (cert.source == CertificationSource.PlatformVerified) {
            return (2, "Platform Verified");
        } else if (cert.source == CertificationSource.TransitionDocumented) {
            return (1, "In Organic Transition");
        } else if (cert.verificationStatus == VerificationStatus.Verified) {
            return (1, "Verified");
        } else {
            return (0, "Self-Declared");
        }
    }
    
    function getCertificationSummary(uint256 treeId) external view returns (
        uint256 totalCertificates,
        uint256 verifiedCertificates,
        uint256 authorityCertificates,
        bool hasOrganicCert,
        bool isInTransition,
        string[] memory authorityNames
    ) {
        uint256[] memory certIds = treeCertificates[treeId];
        totalCertificates = certIds.length;
        
        uint256 uniqueAuthCount = 0;
        string[] memory tempAuthNames = new string[](certIds.length);
        
        for (uint256 i = 0; i < certIds.length; i++) {
            Certificate memory cert = certificates[certIds[i]];
            
            if (!_isCertificateActive(cert)) continue;
            
            if (cert.verificationStatus == VerificationStatus.Verified) {
                verifiedCertificates++;
            }
            
            if (cert.source == CertificationSource.AuthorityIssued) {
                authorityCertificates++;
            }
            
            if (cert.certType == CertificationType.Organic) {
                hasOrganicCert = true;
            }
            
            if (cert.certType == CertificationType.InTransition) {
                isInTransition = true;
            }
            
            bool exists = false;
            for (uint256 j = 0; j < uniqueAuthCount; j++) {
                if (keccak256(bytes(tempAuthNames[j])) == keccak256(bytes(cert.authorityName))) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                tempAuthNames[uniqueAuthCount] = cert.authorityName;
                uniqueAuthCount++;
            }
        }
        
        authorityNames = new string[](uniqueAuthCount);
        for (uint256 i = 0; i < uniqueAuthCount; i++) {
            authorityNames[i] = tempAuthNames[i];
        }
        
        return (totalCertificates, verifiedCertificates, authorityCertificates, hasOrganicCert, isInTransition, authorityNames);
    }
    
    function getOrganicTransition(uint256 transitionId) external view returns (OrganicTransition memory) {
        return organicTransitions[transitionId];
    }
    
    function getTreeTransition(uint256 treeId) external view returns (OrganicTransition memory) {
        uint256 transitionId = treeTransition[treeId];
        require(transitionId > 0, "No transition found for tree");
        return organicTransitions[transitionId];
    }
    
    function isTreeInTransition(uint256 treeId) external view returns (bool inTransition, TransitionYear currentYear, uint256 daysRemaining) {
        uint256 transitionId = treeTransition[treeId];
        if (transitionId == 0) {
            return (false, TransitionYear.NotInTransition, 0);
        }
        
        OrganicTransition memory transition = organicTransitions[transitionId];
        if (transition.isComplete) {
            return (false, TransitionYear.Completed, 0);
        }
        
        uint256 threeYearsTimestamp = transition.transitionStartDate + 1095 days;
        if (block.timestamp >= threeYearsTimestamp) {
            daysRemaining = 0;
        } else {
            daysRemaining = (threeYearsTimestamp - block.timestamp) / 86400;
        }
        
        return (true, transition.currentYear, daysRemaining);
    }
    
    function getTransitionProgress(uint256 transitionId) external view returns (uint256 progressPercentage, string memory status) {
        OrganicTransition memory transition = organicTransitions[transitionId];
        
        if (transition.isComplete) {
            return (100, "Completed");
        }
        
        uint256 daysSinceStart = (block.timestamp - transition.transitionStartDate) / 86400;
        uint256 totalDays = 1095;
        
        if (daysSinceStart >= totalDays) {
            progressPercentage = 100;
            status = "Ready for Certification";
        } else {
            progressPercentage = (daysSinceStart * 100) / totalDays;
            
            if (transition.currentYear == TransitionYear.FirstYear) {
                status = "Year 1 of 3";
            } else if (transition.currentYear == TransitionYear.SecondYear) {
                status = "Year 2 of 3";
            } else if (transition.currentYear == TransitionYear.ThirdYear) {
                status = "Year 3 of 3";
            } else {
                status = "In Progress";
            }
        }
        
        return (progressPercentage, status);
    }
    
    function getPracticeRecord(uint256 recordId) external view returns (PracticeRecord memory) {
        return practiceRecords[recordId];
    }
    
    function getTreePracticeRecords(uint256 treeId) external view returns (PracticeRecord[] memory records) {
        uint256[] memory recordIds = treePracticeRecords[treeId];
        records = new PracticeRecord[](recordIds.length);
        for (uint256 i = 0; i < recordIds.length; i++) {
            records[i] = practiceRecords[recordIds[i]];
        }
        return records;
    }
    
    function getTransitionPracticeRecords(uint256 transitionId) external view returns (PracticeRecord[] memory records) {
        uint256[] memory recordIds = transitionPracticeRecords[transitionId];
        records = new PracticeRecord[](recordIds.length);
        for (uint256 i = 0; i < recordIds.length; i++) {
            records[i] = practiceRecords[recordIds[i]];
        }
        return records;
    }
    
    function getRecentPracticeRecords(uint256 treeId, uint256 limit) external view returns (PracticeRecord[] memory records) {
        uint256[] memory recordIds = treePracticeRecords[treeId];
        uint256 recordCount = recordIds.length;
        
        if (recordCount == 0) {
            return new PracticeRecord[](0);
        }
        
        uint256 actualLimit = limit > recordCount ? recordCount : limit;
        records = new PracticeRecord[](actualLimit);
        
        for (uint256 i = 0; i < actualLimit; i++) {
            uint256 index = recordCount - actualLimit + i;
            records[i] = practiceRecords[recordIds[index]];
        }
        
        return records;
    }
    
    function getLabTest(uint256 labTestId) external view returns (LabTest memory) {
        return labTests[labTestId];
    }
    
    function getTreeLabTests(uint256 treeId) external view returns (LabTest[] memory tests) {
        uint256[] memory testIds = treeLabTests[treeId];
        tests = new LabTest[](testIds.length);
        for (uint256 i = 0; i < testIds.length; i++) {
            tests[i] = labTests[testIds[i]];
        }
        return tests;
    }
    
    function getRecentLabTests(uint256 treeId, uint256 limit) external view returns (LabTest[] memory tests) {
        uint256[] memory testIds = treeLabTests[treeId];
        uint256 testCount = testIds.length;
        
        if (testCount == 0) {
            return new LabTest[](0);
        }
        
        uint256 actualLimit = limit > testCount ? testCount : limit;
        tests = new LabTest[](actualLimit);
        
        for (uint256 i = 0; i < actualLimit; i++) {
            uint256 index = testCount - actualLimit + i;
            tests[i] = labTests[testIds[index]];
        }
        
        return tests;
    }
    
    function getCompleteOrganicVerification(uint256 treeId) external view returns (
        Certificate[] memory activeCertificates,
        OrganicTransition memory transition,
        PracticeRecord[] memory recentPractices,
        LabTest[] memory recentLabTests,
        bool isFullyOrganic,
        bool isInTransition,
        uint256 trustScore
    ) {
        uint256[] memory certIds = treeCertificates[treeId];
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < certIds.length; i++) {
            if (_isCertificateActive(certificates[certIds[i]])) {
                activeCount++;
            }
        }
        
        activeCertificates = new Certificate[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < certIds.length; i++) {
            Certificate memory cert = certificates[certIds[i]];
            if (_isCertificateActive(cert)) {
                activeCertificates[index] = cert;
                
                if (cert.certType == CertificationType.Organic && cert.verificationStatus == VerificationStatus.Verified) {
                    isFullyOrganic = true;
                }
                
                if (cert.certType == CertificationType.InTransition) {
                    isInTransition = true;
                }
                
                index++;
            }
        }
        
        uint256 transitionId = treeTransition[treeId];
        if (transitionId > 0) {
            transition = organicTransitions[transitionId];
        }
        
        uint256[] memory practiceIds = treePracticeRecords[treeId];
        uint256 practiceCount = practiceIds.length;
        uint256 practiceLimit = practiceCount > 10 ? 10 : practiceCount;
        
        recentPractices = new PracticeRecord[](practiceLimit);
        for (uint256 i = 0; i < practiceLimit; i++) {
            uint256 idx = practiceCount - practiceLimit + i;
            recentPractices[i] = practiceRecords[practiceIds[idx]];
        }
        
        uint256[] memory testIds = treeLabTests[treeId];
        uint256 testCount = testIds.length;
        uint256 testLimit = testCount > 5 ? 5 : testCount;
        
        recentLabTests = new LabTest[](testLimit);
        for (uint256 i = 0; i < testLimit; i++) {
            uint256 idx = testCount - testLimit + i;
            recentLabTests[i] = labTests[testIds[idx]];
        }
        
        trustScore = _calculateTrustScore(activeCertificates, transition, practiceIds.length, testIds.length);
        
        return (activeCertificates, transition, recentPractices, recentLabTests, isFullyOrganic, isInTransition, trustScore);
    }
    
    // ========== ADMIN FUNCTIONS ==========
    
    function authorizePlatformVerifier(address verifier, bool authorized) external onlyOwner {
        platformVerifiers[verifier] = authorized;
    }
    
    function authorizeLab(address lab, bool authorized) external onlyOwner {
        authorizedLabs[lab] = authorized;
        emit LabAuthorized(lab, authorized);
    }
    
    function setTrustedFarmer(address farmer, bool trusted) external onlyOwner {
        trustedFarmers[farmer] = trusted;
    }
    
    function addAuthority(string memory name, string memory country) external onlyOwner returns (uint256) {
        _authorityIdCounter++;
        
        authorities[_authorityIdCounter] = CertificationAuthority({
            name: name,
            country: country,
            isRegistered: false,
            isActive: true,
            authorizedAddress: address(0),
            contactInfo: "",
            standards: new string[](0),
            registeredDate: block.timestamp
        });
        
        return _authorityIdCounter;
    }
    
    function getPendingVerificationRequests() external view returns (uint256[] memory pending) {
        uint256 count = 0;
        for (uint256 i = 1; i <= _requestIdCounter; i++) {
            if (!verificationRequests[i].isProcessed) {
                count++;
            }
        }
        
        pending = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= _requestIdCounter; i++) {
            if (!verificationRequests[i].isProcessed) {
                pending[index] = i;
                index++;
            }
        }
        
        return pending;
    }
    
    function batchVerifyCertificates(uint256[] memory certificateIds, bool approved, string memory reviewNotes) external {
        require(platformVerifiers[msg.sender] || msg.sender == owner(), "Not authorized");
        
        for (uint256 i = 0; i < certificateIds.length; i++) {
            Certificate storage cert = certificates[certificateIds[i]];
            
            if (cert.verificationStatus == VerificationStatus.UnderReview) {
                if (approved) {
                    cert.verificationStatus = VerificationStatus.Verified;
                    cert.source = CertificationSource.PlatformVerified;
                } else {
                    cert.verificationStatus = VerificationStatus.Rejected;
                }
                
                cert.verifiedBy = msg.sender;
                cert.verificationDate = block.timestamp;
                cert.verificationNotes = reviewNotes;
                
                emit CertificateVerified(certificateIds[i], msg.sender, cert.verificationStatus);
            }
        }
    }
    
    // ========== STATISTICS ==========
    
    function getTotalCertificates() external view returns (uint256) {
        return _certificateIdCounter;
    }
    
    function getTotalTransitions() external view returns (uint256) {
        return _transitionIdCounter;
    }
    
    function getTotalPracticeRecords() external view returns (uint256) {
        return _practiceRecordIdCounter;
    }
    
    function getTotalLabTests() external view returns (uint256) {
        return _labTestIdCounter;
    }
    
    function getTotalAuthorities() external view returns (uint256) {
        return _authorityIdCounter;
    }
    
    function getAuthority(uint256 authorityId) external view returns (CertificationAuthority memory) {
        return authorities[authorityId];
    }
    
    // ========== INTERNAL HELPERS ==========
    
    function _isCertificateActive(Certificate memory cert) internal view returns (bool) {
        return cert.isActive && cert.expiryDate > block.timestamp && cert.verificationStatus != VerificationStatus.Rejected;
    }
    
    function _findAuthorityByName(string memory name) internal view returns (uint256) {
        for (uint256 i = 1; i <= _authorityIdCounter; i++) {
            if (keccak256(bytes(authorities[i].name)) == keccak256(bytes(name))) {
                return i;
            }
        }
        return 0;
    }
    
    function _getAuthorityIdByAddress(address addr) internal view returns (uint256) {
        for (uint256 i = 1; i <= _authorityIdCounter; i++) {
            if (authorities[i].authorizedAddress == addr && authorities[i].isRegistered) {
                return i;
            }
        }
        return 0;
    }
    
    function _calculateTrustScore(
        Certificate[] memory certs,
        OrganicTransition memory transition,
        uint256 practiceCount,
        uint256 labTestCount
    ) internal view returns (uint256) {
        uint256 score = 0;
        
        for (uint256 i = 0; i < certs.length; i++) {
            if (certs[i].source == CertificationSource.AuthorityIssued) {
                score += 30;
            } else if (certs[i].source == CertificationSource.FarmaverseCertified) {
                score += 25;
            } else if (certs[i].source == CertificationSource.PlatformVerified) {
                score += 20;
            } else {
                score += 10;
            }
        }
        if (score > 40) score = 40;
        
        if (transition.transitionId > 0) {
            if (transition.isPlatformVerified) {
                score += 15;
            } else {
                score += 10;
            }
            
            if (transition.isComplete) {
                score += 5;
            }
        }
        
        if (practiceCount > 0) {
            uint256 practiceScore = practiceCount * 2;
            if (practiceScore > 20) practiceScore = 20;
            score += practiceScore;
        }
        
        if (labTestCount > 0) {
            uint256 labScore = labTestCount * 4;
            if (labScore > 20) labScore = 20;
            score += labScore;
        }
        
        if (score > 100) score = 100;
        
        return score;
    }
    
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}