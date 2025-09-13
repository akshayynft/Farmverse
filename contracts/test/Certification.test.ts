import { expect } from "chai";
import { ethers } from "hardhat";
import { Certification, TreeID, Harvest } from "../typechain-types";
import { SignerWithAddress } from "@ethersproject/contracts";

describe("Certification", function () {
  let certification: Certification;
  let treeID: TreeID;
  let harvest: Harvest;
  let owner: SignerWithAddress;
  let farmer1: SignerWithAddress;
  let farmer2: SignerWithAddress;
  let lab: SignerWithAddress;
  let certifier: SignerWithAddress;
  let addr1: SignerWithAddress;

  beforeEach(async function () {
    [owner, farmer1, farmer2, lab, certifier, addr1] = await ethers.getSigners();
    
    // Deploy contracts with no parameters
    const TreeIDFactory = await ethers.getContractFactory("TreeID");
    treeID = await TreeIDFactory.deploy();
    await treeID.waitForDeployment();
    
    const HarvestFactory = await ethers.getContractFactory("Harvest");
    harvest = await HarvestFactory.deploy();
    await harvest.waitForDeployment();
    
    const CertificationFactory = await ethers.getContractFactory("Certification");
    certification = await CertificationFactory.deploy();
    await certification.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await certification.owner()).to.equal(owner.address);
    });

    it("Should have correct contract name", async function () {
      expect(await certification.name()).to.equal("Farmaverse Certification");
    });
  });

  describe("Lab Testing", function () {
    let treeId: number;
    let harvestId: number;

    beforeEach(async function () {
      // Register a tree first
      const treeData = {
        farmerAddress: farmer1.address,
        location: "Maharashtra, India",
        variety: "Alphonso",
        plantingDate: Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        expectedHarvestDate: Math.floor(Date.now() / 1000),
        organicCertified: true,
        irrigationType: "Drip",
        soilType: "Red Soil",
        coordinates: "19.0760,72.8777"
      };
      
      await treeID.connect(farmer1).registerTree(treeData);
      treeId = 0;

      // Record a harvest
      const harvestData = {
        treeId: treeId,
        harvestDate: Math.floor(Date.now() / 1000),
        quantity: ethers.parseEther("100"),
        qualityMetrics: {
          size: 85,
          sweetness: 90,
          firmness: 80,
          color: 95,
          defectRate: 5
        },
        harvestMethod: "Hand Picking",
        weatherConditions: "Sunny",
        notes: "Test harvest"
      };
      
      await harvest.connect(farmer1).recordHarvest(harvestData);
      harvestId = 0;
    });

    it("Should allow labs to submit test results", async function () {
      const testResults = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        pesticideResidue: 0.01, // ppm
        heavyMetals: 0.005, // ppm
        microbialContamination: false,
        organicCompliance: true,
        testDate: Math.floor(Date.now() / 1000),
        labNotes: "All parameters within acceptable limits"
      };

      await certification.connect(lab).submitLabResults(testResults);
      
      const labTest = await certification.getLabTest(harvestId);
      expect(labTest.labAddress).to.equal(lab.address);
      expect(labTest.pesticideResidue).to.equal(testResults.pesticideResidue);
    });

    it("Should emit LabResultsSubmitted event", async function () {
      const testResults = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        pesticideResidue: 0.01,
        heavyMetals: 0.005,
        microbialContamination: false,
        organicCompliance: true,
        testDate: Math.floor(Date.now() / 1000),
        labNotes: "Test results"
      };

      await expect(certification.connect(lab).submitLabResults(testResults))
        .to.emit(certification, "LabResultsSubmitted")
        .withArgs(lab.address, harvestId, farmer1.address);
    });

    it("Should store test results correctly", async function () {
      const testResults = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        pesticideResidue: 0.01,
        heavyMetals: 0.005,
        microbialContamination: false,
        organicCompliance: true,
        testDate: Math.floor(Date.now() / 1000),
        labNotes: "Test results"
      };

      await certification.connect(lab).submitLabResults(testResults);
      
      const labTest = await certification.getLabTest(harvestId);
      expect(labTest.harvestId).to.equal(harvestId);
      expect(labTest.farmerAddress).to.equal(farmer1.address);
      expect(labTest.organicCompliance).to.equal(true);
    });
  });

  describe("Certification Process", function () {
    let treeId: number;
    let harvestId: number;

    beforeEach(async function () {
      // Register a tree first
      const treeData = {
        farmerAddress: farmer1.address,
        location: "Maharashtra, India",
        variety: "Alphonso",
        plantingDate: Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        expectedHarvestDate: Math.floor(Date.now() / 1000),
        organicCertified: true,
        irrigationType: "Drip",
        soilType: "Red Soil",
        coordinates: "19.0760,72.8777"
      };
      
      await treeID.connect(farmer1).registerTree(treeData);
      treeId = 0;

      // Record a harvest
      const harvestData = {
        treeId: treeId,
        harvestDate: Math.floor(Date.now() / 1000),
        quantity: ethers.parseEther("100"),
        qualityMetrics: {
          size: 85,
          sweetness: 90,
          firmness: 80,
          color: 95,
          defectRate: 5
        },
        harvestMethod: "Hand Picking",
        weatherConditions: "Sunny",
        notes: "Test harvest"
      };
      
      await harvest.connect(farmer1).recordHarvest(harvestData);
      harvestId = 0;

      // Submit lab results
      const testResults = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        pesticideResidue: 0.01,
        heavyMetals: 0.005,
        microbialContamination: false,
        organicCompliance: true,
        testDate: Math.floor(Date.now() / 1000),
        labNotes: "Test results"
      };

      await certification.connect(lab).submitLabResults(testResults);
    });

    it("Should allow certifiers to issue organic certification", async function () {
      const certificationData = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        certificationType: "Organic",
        validityPeriod: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60), // 1 year
        standards: "NPOP, USDA Organic",
        certifierNotes: "Compliant with all organic standards"
      };

      await certification.connect(certifier).issueCertification(certificationData);
      
      const cert = await certification.getCertification(harvestId);
      expect(cert.certificationType).to.equal("Organic");
      expect(cert.standards).to.equal("NPOP, USDA Organic");
    });

    it("Should emit CertificationIssued event", async function () {
      const certificationData = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        certificationType: "Organic",
        validityPeriod: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60),
        standards: "NPOP, USDA Organic",
        certifierNotes: "Test certification"
      };

      await expect(certification.connect(certifier).issueCertification(certificationData))
        .to.emit(certification, "CertificationIssued")
        .withArgs(certifier.address, harvestId, farmer1.address, "Organic");
    });

    it("Should reject certification without lab results", async function () {
      // Try to certify a harvest without lab results
      const certificationData = {
        harvestId: 999, // Non-existent harvest
        farmerAddress: farmer1.address,
        certificationType: "Organic",
        validityPeriod: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60),
        standards: "NPOP, USDA Organic",
        certifierNotes: "Test certification"
      };

      await expect(
        certification.connect(certifier).issueCertification(certificationData)
      ).to.be.revertedWith("Lab results not found for this harvest");
    });
  });

  describe("Certification Validation", function () {
    let treeId: number;
    let harvestId: number;

    beforeEach(async function () {
      // Register a tree first
      const treeData = {
        farmerAddress: farmer1.address,
        location: "Maharashtra, India",
        variety: "Alphonso",
        plantingDate: Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        expectedHarvestDate: Math.floor(Date.now() / 1000),
        organicCertified: true,
        irrigationType: "Drip",
        soilType: "Red Soil",
        coordinates: "19.0760,72.8777"
      };
      
      await treeID.connect(farmer1).registerTree(treeData);
      treeId = 0;

      // Record a harvest
      const harvestData = {
        treeId: treeId,
        harvestDate: Math.floor(Date.now() / 1000),
        quantity: ethers.parseEther("100"),
        qualityMetrics: {
          size: 85,
          sweetness: 90,
          firmness: 80,
          color: 95,
          defectRate: 5
        },
        harvestMethod: "Hand Picking",
        weatherConditions: "Sunny",
        notes: "Test harvest"
      };
      
      await harvest.connect(farmer1).recordHarvest(harvestData);
      harvestId = 0;
    });

    it("Should reject lab results with invalid pesticide levels", async function () {
      const invalidTestResults = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        pesticideResidue: 5.0, // Too high
        heavyMetals: 0.005,
        microbialContamination: false,
        organicCompliance: false,
        testDate: Math.floor(Date.now() / 1000),
        labNotes: "High pesticide levels detected"
      };

      await expect(
        certification.connect(lab).submitLabResults(invalidTestResults)
      ).to.be.revertedWith("Pesticide levels exceed organic standards");
    });

    it("Should reject lab results with heavy metal contamination", async function () {
      const invalidTestResults = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        pesticideResidue: 0.01,
        heavyMetals: 1.0, // Too high
        microbialContamination: false,
        organicCompliance: false,
        testDate: Math.floor(Date.now() / 1000),
        labNotes: "Heavy metal contamination detected"
      };

      await expect(
        certification.connect(lab).submitLabResults(invalidTestResults)
      ).to.be.revertedWith("Heavy metal levels exceed safety limits");
    });
  });

  describe("Certification Queries", function () {
    let treeId: number;
    let harvestId: number;

    beforeEach(async function () {
      // Register a tree first
      const treeData = {
        farmerAddress: farmer1.address,
        location: "Maharashtra, India",
        variety: "Alphonso",
        plantingDate: Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        expectedHarvestDate: Math.floor(Date.now() / 1000),
        organicCertified: true,
        irrigationType: "Drip",
        soilType: "Red Soil",
        coordinates: "19.0760,72.8777"
      };
      
      await treeID.connect(farmer1).registerTree(treeData);
      treeId = 0;

      // Record a harvest
      const harvestData = {
        treeId: treeId,
        harvestDate: Math.floor(Date.now() / 1000),
        quantity: ethers.parseEther("100"),
        qualityMetrics: {
          size: 85,
          sweetness: 90,
          firmness: 80,
          color: 95,
          defectRate: 5
        },
        harvestMethod: "Hand Picking",
        weatherConditions: "Sunny",
        notes: "Test harvest"
      };
      
      await harvest.connect(farmer1).recordHarvest(harvestData);
      harvestId = 0;

      // Submit lab results
      const testResults = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        pesticideResidue: 0.01,
        heavyMetals: 0.005,
        microbialContamination: false,
        organicCompliance: true,
        testDate: Math.floor(Date.now() / 1000),
        labNotes: "Test results"
      };

      await certification.connect(lab).submitLabResults(testResults);

      // Issue certification
      const certificationData = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        certificationType: "Organic",
        validityPeriod: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60),
        standards: "NPOP, USDA Organic",
        certifierNotes: "Test certification"
      };

      await certification.connect(certifier).issueCertification(certificationData);
    });

    it("Should return correct lab test data", async function () {
      const labTest = await certification.getLabTest(harvestId);
      expect(labTest.harvestId).to.equal(harvestId);
      expect(labTest.labAddress).to.equal(lab.address);
    });

    it("Should return correct certification data", async function () {
      const cert = await certification.getCertification(harvestId);
      expect(cert.certificationType).to.equal("Organic");
      expect(cert.certifierAddress).to.equal(certifier.address);
    });

    it("Should verify organic certification status", async function () {
      const isCertified = await certification.isOrganicallyCertified(harvestId);
      expect(isCertified).to.equal(true);
    });

    it("Should return empty data for non-existent harvest", async function () {
      const labTest = await certification.getLabTest(999);
      expect(labTest.harvestId).to.equal(0);
      expect(labTest.labAddress).to.equal(ethers.ZeroAddress);
    });
  });

  describe("Access Control", function () {
    it("Should not allow non-labs to submit test results", async function () {
      const testResults = {
        harvestId: 0,
        farmerAddress: farmer1.address,
        pesticideResidue: 0.01,
        heavyMetals: 0.005,
        microbialContamination: false,
        organicCompliance: true,
        testDate: Math.floor(Date.now() / 1000),
        labNotes: "Test results"
      };

      await expect(
        certification.connect(addr1).submitLabResults(testResults)
      ).to.be.revertedWith("Only authorized labs can submit results");
    });

    it("Should not allow non-certifiers to issue certifications", async function () {
      const certificationData = {
        harvestId: 0,
        farmerAddress: farmer1.address,
        certificationType: "Organic",
        validityPeriod: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60),
        standards: "NPOP, USDA Organic",
        certifierNotes: "Test certification"
      };

      await expect(
        certification.connect(addr1).issueCertification(certificationData)
      ).to.be.revertedWith("Only authorized certifiers can issue certifications");
    });
  });

  describe("Owner Functions", function () {
    it("Should allow owner to add authorized labs", async function () {
      await certification.addAuthorizedLab(lab.address);
      expect(await certification.isAuthorizedLab(lab.address)).to.equal(true);
    });

    it("Should allow owner to add authorized certifiers", async function () {
      await certification.addAuthorizedCertifier(certifier.address);
      expect(await certification.isAuthorizedCertifier(certifier.address)).to.equal(true);
    });

    it("Should not allow non-owner to add authorized labs", async function () {
      await expect(
        certification.connect(farmer1).addAuthorizedLab(addr1.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should allow owner to transfer ownership", async function () {
      await certification.transferOwnership(farmer1.address);
      expect(await certification.owner()).to.equal(farmer1.address);
    });
  });
});



