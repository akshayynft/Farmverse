import { expect } from "chai";
import { ethers } from "hardhat";
import { WasteManagement } from "../typechain-types";
import { SignerWithAddress } from "@ethersproject/contracts";

describe("WasteManagement", function () {
  let wasteManagement: WasteManagement;
  let owner: SignerWithAddress;
  let reporter1: SignerWithAddress;
  let reporter2: SignerWithAddress;
  let addr1: SignerWithAddress;

  beforeEach(async function () {
    [owner, reporter1, reporter2, addr1] = await ethers.getSigners();
    
    const WasteManagementFactory = await ethers.getContractFactory("WasteManagement");
    wasteManagement = await WasteManagementFactory.deploy();
    await wasteManagement.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await wasteManagement.owner()).to.equal(owner.address);
    });
  });

  describe("Waste Reporting", function () {
    beforeEach(async function () {
      await wasteManagement.connect(owner).authorizeReporter(reporter1.address, true);
    });

    it("Should allow authorized reporters to report waste", async function () {
      const wasteEventId = await wasteManagement.connect(reporter1).reportWaste(
        1, // batchId
        ethers.parseEther("5"), // quantity
        "Processing", // stage
        "Damaged", // wasteType
        "Physical damage during processing", // reason
        "Compost", // disposalMethod
        true, // isRecycled
        "ipfs://waste-docs", // ipfsHash
        ethers.parseEther("0.1") // cost
      );

      expect(wasteEventId).to.equal(1);
      
      const wasteEvent = await wasteManagement.getWasteEvent(wasteEventId);
      expect(wasteEvent.quantity).to.equal(ethers.parseEther("5"));
      expect(wasteEvent.stage).to.equal("Processing");
      expect(wasteEvent.wasteType).to.equal("Damaged");
    });

    it("Should emit WasteReported event", async function () {
      await expect(
        wasteManagement.connect(reporter1).reportWaste(
          1,
          ethers.parseEther("5"),
          "Processing",
          "Damaged",
          "Physical damage during processing",
          "Compost",
          true,
          "ipfs://waste-docs",
          ethers.parseEther("0.1")
        )
      ).to.emit(wasteManagement, "WasteReported")
        .withArgs(1, 1, "Processing", ethers.parseEther("5"));
    });

    it("Should emit WasteRecycled event when waste is recycled", async function () {
      await expect(
        wasteManagement.connect(reporter1).reportWaste(
          1,
          ethers.parseEther("5"),
          "Processing",
          "Damaged",
          "Physical damage during processing",
          "Compost",
          true, // isRecycled
          "ipfs://waste-docs",
          ethers.parseEther("0.1")
        )
      ).to.emit(wasteManagement, "WasteRecycled")
        .withArgs(1, "Compost");
    });

    it("Should not allow unauthorized reporters to report waste", async function () {
      await expect(
        wasteManagement.connect(addr1).reportWaste(
          1,
          ethers.parseEther("5"),
          "Processing",
          "Damaged",
          "Physical damage during processing",
          "Compost",
          true,
          "ipfs://waste-docs",
          ethers.parseEther("0.1")
        )
      ).to.be.revertedWith("Not authorized to report waste");
    });

    it("Should reject zero quantity waste", async function () {
      await expect(
        wasteManagement.connect(reporter1).reportWaste(
          1,
          0, // zero quantity
          "Processing",
          "Damaged",
          "Physical damage during processing",
          "Compost",
          true,
          "ipfs://waste-docs",
          ethers.parseEther("0.1")
        )
      ).to.be.revertedWith("Waste quantity must be greater than 0");
    });
  });

  describe("Waste Statistics", function () {
    beforeEach(async function () {
      await wasteManagement.connect(owner).authorizeReporter(reporter1.address, true);
    });

    it("Should track waste statistics correctly", async function () {
      await wasteManagement.connect(reporter1).reportWaste(
        1,
        ethers.parseEther("5"),
        "Processing",
        "Damaged",
        "Physical damage during processing",
        "Compost",
        true,
        "ipfs://waste-docs",
        ethers.parseEther("0.1")
      );

      const stats = await wasteManagement.getBatchWasteStats(1);
      expect(stats.totalWasteQuantity).to.equal(ethers.parseEther("5"));
      expect(stats.recycledQuantity).to.equal(ethers.parseEther("5"));
      expect(stats.totalWasteCost).to.equal(ethers.parseEther("0.1"));
      expect(stats.totalEvents).to.equal(1);
    });

    it("Should calculate waste percentage correctly", async function () {
      await wasteManagement.connect(reporter1).reportWaste(
        1,
        ethers.parseEther("5"),
        "Processing",
        "Damaged",
        "Physical damage during processing",
        "Compost",
        true,
        "ipfs://waste-docs",
        ethers.parseEther("0.1")
      );

      const wastePercentage = await wasteManagement.calculateWastePercentage(1, ethers.parseEther("100"));
      expect(wastePercentage).to.equal(5); // 5% waste
    });

    it("Should calculate sustainability metrics correctly", async function () {
      await wasteManagement.connect(reporter1).reportWaste(
        1,
        ethers.parseEther("5"),
        "Processing",
        "Damaged",
        "Physical damage during processing",
        "Compost",
        true,
        "ipfs://waste-docs",
        ethers.parseEther("0.1")
      );

      const [recycledPercentage, totalWaste, totalCost] = await wasteManagement.getSustainabilityMetrics(1);
      expect(recycledPercentage).to.equal(100); // 100% recycled
      expect(totalWaste).to.equal(ethers.parseEther("5"));
      expect(totalCost).to.equal(ethers.parseEther("0.1"));
    });
  });

  describe("Access Control", function () {
    it("Should allow owner to authorize reporters", async function () {
      await wasteManagement.connect(owner).authorizeReporter(reporter1.address, true);
      expect(await wasteManagement.isReporterAuthorized(reporter1.address)).to.equal(true);
    });

    it("Should not allow non-owner to authorize reporters", async function () {
      await expect(
        wasteManagement.connect(addr1).authorizeReporter(reporter1.address, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should emit ReporterAuthorized event", async function () {
      await expect(
        wasteManagement.connect(owner).authorizeReporter(reporter1.address, true)
      ).to.emit(wasteManagement, "ReporterAuthorized")
        .withArgs(reporter1.address, true);
    });
  });

  describe("Queries and Statistics", function () {
    beforeEach(async function () {
      await wasteManagement.connect(owner).authorizeReporter(reporter1.address, true);
    });

    it("Should return correct total waste events", async function () {
      await wasteManagement.connect(reporter1).reportWaste(
        1,
        ethers.parseEther("5"),
        "Processing",
        "Damaged",
        "Physical damage during processing",
        "Compost",
        true,
        "ipfs://waste-docs",
        ethers.parseEther("0.1")
      );

      const totalEvents = await wasteManagement.getTotalWasteEvents();
      expect(totalEvents).to.equal(1);
    });

    it("Should return waste events by reporter", async function () {
      await wasteManagement.connect(reporter1).reportWaste(
        1,
        ethers.parseEther("5"),
        "Processing",
        "Damaged",
        "Physical damage during processing",
        "Compost",
        true,
        "ipfs://waste-docs",
        ethers.parseEther("0.1")
      );

      const reporterEvents = await wasteManagement.getReporterWasteEvents(reporter1.address);
      expect(reporterEvents.length).to.equal(1);
      expect(reporterEvents[0]).to.equal(1);
    });

    it("Should return batch waste events", async function () {
      await wasteManagement.connect(reporter1).reportWaste(
        1,
        ethers.parseEther("5"),
        "Processing",
        "Damaged",
        "Physical damage during processing",
        "Compost",
        true,
        "ipfs://waste-docs",
        ethers.parseEther("0.1")
      );

      const batchEvents = await wasteManagement.getBatchWasteEvents(1);
      expect(batchEvents.length).to.equal(1);
      expect(batchEvents[0]).to.equal(1);
    });
  });
});