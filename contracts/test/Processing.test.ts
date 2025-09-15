import { expect } from "chai";
import { ethers } from "hardhat";
import { Processing } from "../typechain-types";
import { SignerWithAddress } from "@ethersproject/contracts";

describe("Processing", function () {
  let processing: Processing;
  let owner: SignerWithAddress;
  let facility1: SignerWithAddress;
  let facility2: SignerWithAddress;
  let addr1: SignerWithAddress;

  beforeEach(async function () {
    [owner, facility1, facility2, addr1] = await ethers.getSigners();
    
    const ProcessingFactory = await ethers.getContractFactory("Processing");
    processing = await ProcessingFactory.deploy();
    await processing.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await processing.owner()).to.equal(owner.address);
    });
  });

  describe("Facility Registration", function () {
    it("Should allow facilities to register", async function () {
      await processing.connect(facility1).registerFacility(
        "Mango Processing Plant",
        "Maharashtra, India",
        "Primary",
        "CERT001"
      );
      
      const facility = await processing.getFacility(facility1.address);
      expect(facility.facilityName).to.equal("Mango Processing Plant");
      expect(facility.facilityType).to.equal("Primary");
    });

    it("Should emit FacilityRegistered event", async function () {
      await expect(
        processing.connect(facility1).registerFacility(
          "Mango Processing Plant",
          "Maharashtra, India",
          "Primary",
          "CERT001"
        )
      ).to.emit(processing, "FacilityRegistered")
        .withArgs(facility1.address, "Mango Processing Plant");
    });

    it("Should not allow duplicate registration", async function () {
      await processing.connect(facility1).registerFacility(
        "Mango Processing Plant",
        "Maharashtra, India",
        "Primary",
        "CERT001"
      );
      
      await expect(
        processing.connect(facility1).registerFacility(
          "Another Plant",
          "Karnataka, India",
          "Secondary",
          "CERT002"
        )
      ).to.be.revertedWith("Facility already registered");
    });
  });

  describe("Processing Operations", function () {
    beforeEach(async function () {
      await processing.connect(facility1).registerFacility(
        "Mango Processing Plant",
        "Maharashtra, India",
        "Primary",
        "CERT001"
      );
      await processing.connect(owner).authorizeFacility(facility1.address, true);
    });

    it("Should start processing successfully", async function () {
      const processingEventId = await processing.connect(facility1).startProcessing(
        1, // batchId
        ethers.parseEther("100"), // input quantity
        "Washing and Sorting",
        "Plastic",
        "1kg",
        "ipfs://processing-docs"
      );

      expect(processingEventId).to.equal(1);
      
      const processingEvent = await processing.getProcessingEvent(processingEventId);
      expect(processingEvent.processingMethod).to.equal("Washing and Sorting");
      expect(processingEvent.inputQuantity).to.equal(ethers.parseEther("100"));
    });

    it("Should complete processing successfully", async function () {
      const processingEventId = await processing.connect(facility1).startProcessing(
        1,
        ethers.parseEther("100"),
        "Washing and Sorting",
        "Plastic",
        "1kg",
        "ipfs://processing-docs"
      );

      await processing.connect(facility1).completeProcessing(
        processingEventId,
        ethers.parseEther("95"), // output quantity
        95, // package count
        true, // quality passed
        "All quality checks passed",
        ethers.parseEther("0.5") // cost
      );

      const processingEvent = await processing.getProcessingEvent(processingEventId);
      expect(processingEvent.outputQuantity).to.equal(ethers.parseEther("95"));
      expect(processingEvent.qualityPassed).to.equal(true);
    });

    it("Should not allow unauthorized facilities to process", async function () {
      await expect(
        processing.connect(addr1).startProcessing(
          1,
          ethers.parseEther("100"),
          "Washing and Sorting",
          "Plastic",
          "1kg",
          "ipfs://processing-docs"
        )
      ).to.be.revertedWith("Not authorized to process");
    });
  });

  describe("Quality Control", function () {
    let processingEventId: number;

    beforeEach(async function () {
      await processing.connect(facility1).registerFacility(
        "Mango Processing Plant",
        "Maharashtra, India",
        "Primary",
        "CERT001"
      );
      await processing.connect(owner).authorizeFacility(facility1.address, true);
      
      processingEventId = await processing.connect(facility1).startProcessing(
        1,
        ethers.parseEther("100"),
        "Washing and Sorting",
        "Plastic",
        "1kg",
        "ipfs://processing-docs"
      );
    });

    it("Should perform quality checks", async function () {
      await processing.connect(facility1).performQualityCheck(
        processingEventId,
        "Visual",
        true,
        "All products look good",
        "ipfs://quality-docs"
      );

      const qualityChecks = await processing.getEventQualityChecks(processingEventId);
      expect(qualityChecks.length).to.equal(1);
      expect(qualityChecks[0].checkType).to.equal("Visual");
      expect(qualityChecks[0].passed).to.equal(true);
    });

    it("Should emit QualityCheckPerformed event", async function () {
      await expect(
        processing.connect(facility1).performQualityCheck(
          processingEventId,
          "Visual",
          true,
          "All products look good",
          "ipfs://quality-docs"
        )
      ).to.emit(processing, "QualityCheckPerformed")
        .withArgs(processingEventId, "Visual", true);
    });
  });

  describe("Access Control", function () {
    it("Should allow owner to certify facilities", async function () {
      await processing.connect(facility1).registerFacility(
        "Mango Processing Plant",
        "Maharashtra, India",
        "Primary",
        "CERT001"
      );
      
      await processing.connect(owner).certifyFacility(facility1.address, true);
      
      const facility = await processing.getFacility(facility1.address);
      expect(facility.isCertified).to.equal(true);
    });

    it("Should not allow non-owner to certify facilities", async function () {
      await processing.connect(facility1).registerFacility(
        "Mango Processing Plant",
        "Maharashtra, India",
        "Primary",
        "CERT001"
      );
      
      await expect(
        processing.connect(addr1).certifyFacility(facility1.address, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Statistics and Queries", function () {
    beforeEach(async function () {
      await processing.connect(facility1).registerFacility(
        "Mango Processing Plant",
        "Maharashtra, India",
        "Primary",
        "CERT001"
      );
      await processing.connect(owner).authorizeFacility(facility1.address, true);
    });

    it("Should return correct processing statistics", async function () {
      const processingEventId = await processing.connect(facility1).startProcessing(
        1,
        ethers.parseEther("100"),
        "Washing and Sorting",
        "Plastic",
        "1kg",
        "ipfs://processing-docs"
      );

      await processing.connect(facility1).completeProcessing(
        processingEventId,
        ethers.parseEther("95"),
        95,
        true,
        "All quality checks passed",
        ethers.parseEther("0.5")
      );

      const stats = await processing.getBatchProcessingStats(1);
      expect(stats.totalProcessed).to.equal(ethers.parseEther("100"));
      expect(stats.totalOutput).to.equal(ethers.parseEther("95"));
      expect(stats.qualityPassRate).to.equal(100);
    });

    it("Should calculate processing efficiency correctly", async function () {
      const processingEventId = await processing.connect(facility1).startProcessing(
        1,
        ethers.parseEther("100"),
        "Washing and Sorting",
        "Plastic",
        "1kg",
        "ipfs://processing-docs"
      );

      await processing.connect(facility1).completeProcessing(
        processingEventId,
        ethers.parseEther("95"),
        95,
        true,
        "All quality checks passed",
        ethers.parseEther("0.5")
      );

      const efficiency = await processing.calculateProcessingEfficiency(processingEventId);
      expect(efficiency).to.equal(95); // 95% efficiency
    });
  });
});