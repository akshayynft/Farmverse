import { expect } from "chai";
import { ethers } from "hardhat";
import { Harvest, TreeID } from "../typechain-types";
import { SignerWithAddress } from "@ethersproject/contracts";

describe("Harvest", function () {
  let harvest: Harvest;
  let treeID: TreeID;
  let owner: SignerWithAddress;
  let farmer1: SignerWithAddress;
  let farmer2: SignerWithAddress;
  let addr1: SignerWithAddress;

  beforeEach(async function () {
    [owner, farmer1, farmer2, processor, addr1] = await ethers.getSigners();
    
    // Deploy contracts with no parameters
    const TreeIDFactory = await ethers.getContractFactory("TreeID");
    treeID = await TreeIDFactory.deploy();
    await treeID.waitForDeployment();
    
    const HarvestFactory = await ethers.getContractFactory("Harvest");
    harvest = await HarvestFactory.deploy();
    await harvest.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await harvest.owner()).to.equal(owner.address);
    });

    it("Should have correct contract name", async function () {
      expect(await harvest.name()).to.equal("Farmaverse Harvest");
    });
  });

  describe("Harvest Recording", function () {
    let treeId: number;
    let harvestData: any;

    beforeEach(async function () {
      // Register a tree first
      const treeData = {
        farmerAddress: farmer1.address,
        location: "Maharashtra, India",
        variety: "Alphonso",
        plantingDate: Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60), // 1 year ago
        expectedHarvestDate: Math.floor(Date.now() / 1000),
        organicCertified: true,
        irrigationType: "Drip",
        soilType: "Red Soil",
        coordinates: "19.0760,72.8777"
      };
      
      await treeID.connect(farmer1).registerTree(treeData);
      treeId = 0;

      harvestData = {
        treeId: treeId,
        harvestDate: Math.floor(Date.now() / 1000),
        quantity: ethers.parseEther("100"), // 100 kg
        qualityMetrics: {
          size: 85, // 85% size grade
          sweetness: 90, // 90% sweetness
          firmness: 80, // 80% firmness
          color: 95, // 95% color grade
          defectRate: 5 // 5% defect rate
        },
        harvestMethod: "Hand Picking",
        weatherConditions: "Sunny",
        notes: "Excellent harvest season"
      };
    });

    it("Should allow farmers to record harvests", async function () {
      await harvest.connect(farmer1).recordHarvest(harvestData);
      
      const harvestCount = await harvest.getHarvestCount(farmer1.address);
      expect(harvestCount).to.equal(1);
    });

    it("Should emit HarvestRecorded event", async function () {
      await expect(harvest.connect(farmer1).recordHarvest(harvestData))
        .to.emit(harvest, "HarvestRecorded")
        .withArgs(farmer1.address, 0, treeId, harvestData.quantity);
    });

    it("Should store correct harvest data", async function () {
      await harvest.connect(farmer1).recordHarvest(harvestData);
      
      const recordedHarvest = await harvest.getHarvest(farmer1.address, 0);
      expect(recordedHarvest.treeId).to.equal(treeId);
      expect(recordedHarvest.quantity).to.equal(harvestData.quantity);
      expect(recordedHarvest.harvestMethod).to.equal(harvestData.harvestMethod);
    });

    it("Should store quality metrics correctly", async function () {
      await harvest.connect(farmer1).recordHarvest(harvestData);
      
      const recordedHarvest = await harvest.getHarvest(farmer1.address, 0);
      expect(recordedHarvest.qualityMetrics.size).to.equal(harvestData.qualityMetrics.size);
      expect(recordedHarvest.qualityMetrics.sweetness).to.equal(harvestData.qualityMetrics.sweetness);
      expect(recordedHarvest.qualityMetrics.defectRate).to.equal(harvestData.qualityMetrics.defectRate);
    });

    it("Should increment harvest counter for farmer", async function () {
      await harvest.connect(farmer1).recordHarvest(harvestData);
      await harvest.connect(farmer1).recordHarvest(harvestData);
      
      const harvestCount = await harvest.getHarvestCount(farmer1.address);
      expect(harvestCount).to.equal(2);
    });
  });

  describe("Quality Metrics Validation", function () {
    let treeId: number;

    beforeEach(async function () {
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
    });

    it("Should reject harvests with invalid quality metrics", async function () {
      const invalidHarvestData = {
        treeId: treeId,
        harvestDate: Math.floor(Date.now() / 1000),
        quantity: ethers.parseEther("100"),
        qualityMetrics: {
          size: 150, // Invalid: > 100%
          sweetness: 90,
          firmness: 80,
          color: 95,
          defectRate: 5
        },
        harvestMethod: "Hand Picking",
        weatherConditions: "Sunny",
        notes: "Test"
      };

      await expect(
        harvest.connect(farmer1).recordHarvest(invalidHarvestData)
      ).to.be.revertedWith("Invalid quality metrics");
    });

    it("Should reject harvests with negative defect rates", async function () {
      const invalidHarvestData = {
        treeId: treeId,
        harvestDate: Math.floor(Date.now() / 1000),
        quantity: ethers.parseEther("100"),
        qualityMetrics: {
          size: 85,
          sweetness: 90,
          firmness: 80,
          color: 95,
          defectRate: -5 // Invalid: negative
        },
        harvestMethod: "Hand Picking",
        weatherConditions: "Sunny",
        notes: "Test"
      };

      await expect(
        harvest.connect(farmer1).recordHarvest(invalidHarvestData)
      ).to.be.revertedWith("Invalid quality metrics");
    });
  });

  describe("Harvest Updates", function () {
    let treeId: number;
    let harvestId: number;

    beforeEach(async function () {
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
        notes: "Initial notes"
      };
      
      await harvest.connect(farmer1).recordHarvest(harvestData);
      harvestId = 0;
    });

    it("Should allow farmers to update harvest notes", async function () {
      const newNotes = "Updated harvest notes";
      await harvest.connect(farmer1).updateHarvestNotes(harvestId, newNotes);
      
      const recordedHarvest = await harvest.getHarvest(farmer1.address, harvestId);
      expect(recordedHarvest.notes).to.equal(newNotes);
    });

    it("Should emit HarvestUpdated event", async function () {
      const newNotes = "Updated harvest notes";
      await expect(harvest.connect(farmer1).updateHarvestNotes(harvestId, newNotes))
        .to.emit(harvest, "HarvestUpdated")
        .withArgs(farmer1.address, harvestId, "notes", newNotes);
    });
  });

  describe("Access Control", function () {
    let treeId: number;

    beforeEach(async function () {
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
    });

    it("Should not allow non-farmers to record harvests", async function () {
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
        notes: "Test"
      };

      await expect(
        harvest.connect(addr1).recordHarvest(harvestData)
      ).to.be.revertedWith("Only tree owner can record harvest");
    });

    it("Should not allow updating non-existent harvest", async function () {
      await expect(
        harvest.connect(farmer1).updateHarvestNotes(999, "New notes")
      ).to.be.revertedWith("Harvest does not exist");
    });
  });

  describe("Harvest Queries", function () {
    beforeEach(async function () {
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

      const harvestData = {
        treeId: 0,
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
    });

    it("Should return correct harvest count for farmer", async function () {
      const count = await harvest.getHarvestCount(farmer1.address);
      expect(count).to.equal(1);
    });

    it("Should return correct harvest data", async function () {
      const recordedHarvest = await harvest.getHarvest(farmer1.address, 0);
      expect(recordedHarvest.treeId).to.equal(0);
      expect(recordedHarvest.harvestMethod).to.equal("Hand Picking");
    });

    it("Should return empty harvest data for non-existent harvest", async function () {
      const recordedHarvest = await harvest.getHarvest(farmer1.address, 999);
      expect(recordedHarvest.treeId).to.equal(0);
      expect(recordedHarvest.quantity).to.equal(0);
    });
  });

  describe("Owner Functions", function () {
    it("Should allow owner to transfer ownership", async function () {
      await harvest.transferOwnership(farmer1.address);
      expect(await harvest.owner()).to.equal(farmer1.address);
    });

    it("Should not allow non-owner to transfer ownership", async function () {
      await expect(
        harvest.connect(farmer1).transferOwnership(addr1.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});


