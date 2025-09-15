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
  });

  describe("Lab Testing", function () {
    let treeId: number;

    beforeEach(async function () {
      // Register a tree first with complete Tree struct
      const treeData = {
        treeId: 0, // Will be set by contract
        farmerAddress: farmer1.address,
        location: "Maharashtra, India",
        variety: "Alphonso",
        plantingDate: Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        expectedHarvestDate: Math.floor(Date.now() / 1000),
        organicCertified: true,
        irrigationType: "Drip",
        soilType: "Red Soil",
        coordinates: "19.0760,72.8777",
        isActive: true, // Will be set by contract
        reputation: 0, // Will be set by contract
        ipfsHash: ""
      };
      
      await treeID.connect(farmer1).registerTree(treeData);
      treeId = 1; // First tree gets ID 1
    });

    it("Should allow labs to submit test results", async function () {
      // First authorize the lab
      await certification.connect(owner).authorizeLab(lab.address, true);
      
      // Submit lab test using the actual contract interface
      await certification.connect(lab).submitLabTest(
        treeId,
        "Test Lab",
        "Pesticide Test",
        true, // passed
        "ipfs://test-results",
        10, // pesticideLevel (0.01 ppm = 10 in contract units)
        5,  // heavyMetalLevel (0.005 ppm = 5 in contract units)
        true // microbialSafe
      );
      
      // Get the lab test (ID 1)
      const labTest = await certification.getLabTest(1);
      expect(labTest.labName).to.equal("Test Lab");
      expect(labTest.pesticideLevel).to.equal(10);
    });

    it("Should emit LabTestSubmitted event", async function () {
      await certification.connect(owner).authorizeLab(lab.address, true);
      
      await expect(
        certification.connect(lab).submitLabTest(
          treeId,
          "Test Lab",
          "Pesticide Test",
          true,
          "ipfs://test-results",
          10,
          5,
          true
        )
      ).to.emit(certification, "LabTestSubmitted")
        .withArgs(1, treeId, true);
    });
  });

  describe("Certification Process", function () {
    let treeId: number;

    beforeEach(async function () {
      // Register a tree
      const treeData = {
        treeId: 0,
        farmerAddress: farmer1.address,
        location: "Maharashtra, India",
        variety: "Alphonso",
        plantingDate: Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        expectedHarvestDate: Math.floor(Date.now() / 1000),
        organicCertified: true,
        irrigationType: "Drip",
        soilType: "Red Soil",
        coordinates: "19.0760,72.8777",
        isActive: true,
        reputation: 0,
        ipfsHash: ""
      };
      
      await treeID.connect(farmer1).registerTree(treeData);
      treeId = 1;
    });

    it("Should allow farmers to issue organic certification", async function () {
      const expiryDate = Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60); // 1 year
      
      await certification.connect(farmer1).issueCertification(
        treeId,
        "Organic",
        expiryDate,
        "NPOP Authority",
        "ipfs://cert-docs"
      );
      
      const cert = await certification.getCertification(1);
      expect(cert.certificationType).to.equal("Organic");
      expect(cert.certifyingAuthority).to.equal("NPOP Authority");
    });

    it("Should emit CertificationIssued event", async function () {
      const expiryDate = Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60);
      
      await expect(
        certification.connect(farmer1).issueCertification(
          treeId,
          "Organic",
          expiryDate,
          "NPOP Authority",
          "ipfs://cert-docs"
        )
      ).to.emit(certification, "CertificationIssued")
        .withArgs(1, treeId, "Organic");
    });
  });

  describe("Organic Certification Validation", function () {
    let treeId: number;

    beforeEach(async function () {
      // Register a tree
      const treeData = {
        treeId: 0,
        farmerAddress: farmer1.address,
        location: "Maharashtra, India",
        variety: "Alphonso",
        plantingDate: Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        expectedHarvestDate: Math.floor(Date.now() / 1000),
        organicCertified: true,
        irrigationType: "Drip",
        soilType: "Red Soil",
        coordinates: "19.0760,72.8777",
        isActive: true,
        reputation: 0,
        ipfsHash: ""
      };
      
      await treeID.connect(farmer1).registerTree(treeData);
      treeId = 1;
    });

    it("Should return true for valid organic certification", async function () {
      const expiryDate = Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60); // 1 year from now
      
      await certification.connect(farmer1).issueCertification(
        treeId,
        "Organic",
        expiryDate,
        "NPOP Authority",
        "ipfs://cert-docs"
      );
      
      const isOrganic = await certification.hasValidOrganicCertification(treeId);
      expect(isOrganic).to.equal(true);
    });

    it("Should return false for non-organic certification", async function () {
      const expiryDate = Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60);
      
      await certification.connect(farmer1).issueCertification(
        treeId,
        "Pesticide-Free", // Not "Organic"
        expiryDate,
        "NPOP Authority",
        "ipfs://cert-docs"
      );
      
      const isOrganic = await certification.hasValidOrganicCertification(treeId);
      expect(isOrganic).to.equal(false);
    });

    it("Should return false for expired certification", async function () {
      const expiryDate = Math.floor(Date.now() / 1000) - (24 * 60 * 60); // 1 day ago (expired)
      
      await certification.connect(farmer1).issueCertification(
        treeId,
        "Organic",
        expiryDate,
        "NPOP Authority",
        "ipfs://cert-docs"
      );
      
      const isOrganic = await certification.hasValidOrganicCertification(treeId);
      expect(isOrganic).to.equal(false);
    });

    it("Should return false for inactive certification", async function () {
      const expiryDate = Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60);
      
      const certId = await certification.connect(farmer1).issueCertification(
        treeId,
        "Organic",
        expiryDate,
        "NPOP Authority",
        "ipfs://cert-docs"
      );
      
      // Expire the certification
      await certification.connect(farmer1).expireCertification(certId);
      
      const isOrganic = await certification.hasValidOrganicCertification(treeId);
      expect(isOrganic).to.equal(false);
    });

    it("Should return false for tree with no certifications", async function () {
      const isOrganic = await certification.hasValidOrganicCertification(treeId);
      expect(isOrganic).to.equal(false);
    });

    it("Should return true when multiple certifications exist but one is organic", async function () {
      const expiryDate = Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60);
      
      // Issue non-organic certification first
      await certification.connect(farmer1).issueCertification(
        treeId,
        "Pesticide-Free",
        expiryDate,
        "NPOP Authority",
        "ipfs://cert-docs"
      );
      
      // Issue organic certification
      await certification.connect(farmer1).issueCertification(
        treeId,
        "Organic",
        expiryDate,
        "NPOP Authority",
        "ipfs://cert-docs"
      );
      
      const isOrganic = await certification.hasValidOrganicCertification(treeId);
      expect(isOrganic).to.equal(true);
    });
  });

  describe("Access Control", function () {
    it("Should not allow non-authorized labs to submit test results", async function () {
      await expect(
        certification.connect(addr1).submitLabTest(
          1,
          "Unauthorized Lab",
          "Test",
          true,
          "results",
          10,
          5,
          true
        )
      ).to.be.revertedWith("Only authorized labs can submit results");
    });
  });

  describe("Owner Functions", function () {
    it("Should allow owner to authorize labs", async function () {
      await certification.connect(owner).authorizeLab(lab.address, true);
      expect(await certification.authorizedLabs(lab.address)).to.equal(true);
    });

    it("Should allow owner to authorize certifying authorities", async function () {
      await certification.connect(owner).authorizeCertifyingAuthority(certifier.address, true);
      expect(await certification.certifyingAuthorities(certifier.address)).to.equal(true);
    });

    it("Should not allow non-owner to authorize labs", async function () {
      await expect(
        certification.connect(farmer1).authorizeLab(addr1.address, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should allow owner to transfer ownership", async function () {
      await certification.transferOwnership(farmer1.address);
      expect(await certification.owner()).to.equal(farmer1.address);
    });
  });
});



