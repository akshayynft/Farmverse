import { expect } from "chai";
import { ethers } from "hardhat";
import { FarmerReputation } from "../typechain-types";
import { SignerWithAddress } from "@ethersproject/contracts";

describe("FarmerReputation", function () {
  let farmerReputation: FarmerReputation;
  let owner: SignerWithAddress;
  let farmer1: SignerWithAddress;
  let farmer2: SignerWithAddress;
  let addr1: SignerWithAddress;

  beforeEach(async function () {
    [owner, farmer1, farmer2, addr1] = await ethers.getSigners();
    
    const FarmerReputationFactory = await ethers.getContractFactory("FarmerReputation");
    farmerReputation = await FarmerReputationFactory.deploy();
    await farmerReputation.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await farmerReputation.owner()).to.equal(owner.address);
    });

    it("Should initialize reputation tiers correctly", async function () {
      const bronzeTier = await farmerReputation.getTierBenefits(1);
      const silverTier = await farmerReputation.getTierBenefits(2);
      const goldTier = await farmerReputation.getTierBenefits(3);
      const platinumTier = await farmerReputation.getTierBenefits(4);

      expect(bronzeTier).to.equal(100);
      expect(silverTier).to.equal(125);
      expect(goldTier).to.equal(150);
      expect(platinumTier).to.equal(200);
    });
  });

  describe("Farmer Registration", function () {
    it("Should allow farmers to register", async function () {
      await farmerReputation.connect(farmer1).registerFarmer(
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );
      
      const profile = await farmerReputation.getFarmerProfile(farmer1.address);
      expect(profile.farmerName).to.equal("John Farmer");
      expect(profile.location).to.equal("Maharashtra, India");
      expect(profile.reputationScore).to.equal(100); // Starting score
      expect(profile.qualityConsistency).to.equal(50); // Starting consistency
    });

    it("Should emit FarmerRegistered event", async function () {
      await expect(
        farmerReputation.connect(farmer1).registerFarmer(
          "John Farmer",
          "Maharashtra, India",
          "ipfs://farmer-profile"
        )
      ).to.emit(farmerReputation, "FarmerRegistered")
        .withArgs(farmer1.address, "John Farmer");
    });

    it("Should not allow duplicate registration", async function () {
      await farmerReputation.connect(farmer1).registerFarmer(
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );
      
      await expect(
        farmerReputation.connect(farmer1).registerFarmer(
          "John Farmer",
          "Maharashtra, India",
          "ipfs://farmer-profile"
        )
      ).to.be.revertedWith("Farmer already registered");
    });

    it("Should reject empty farmer name", async function () {
      await expect(
        farmerReputation.connect(farmer1).registerFarmer(
          "",
          "Maharashtra, India",
          "ipfs://farmer-profile"
        )
      ).to.be.revertedWith("Farmer name cannot be empty");
    });
  });

  describe("Reputation Events", function () {
    beforeEach(async function () {
      await farmerReputation.connect(farmer1).registerFarmer(
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );
    });

    it("Should allow owner to record reputation events", async function () {
      const eventId = await farmerReputation.connect(owner).recordReputationEvent(
        farmer1.address,
        "Harvest_Quality",
        85,
        "Excellent harvest quality",
        1, // treeId
        1, // harvestId
        0, // certificationId
        "ipfs://event-docs"
      );

      expect(eventId).to.equal(1);
      
      const event = await farmerReputation.getReputationEvent(eventId);
      expect(event.eventType).to.equal("Harvest_Quality");
      expect(event.score).to.equal(85);
    });

    it("Should emit ReputationEventRecorded event", async function () {
      await expect(
        farmerReputation.connect(owner).recordReputationEvent(
          farmer1.address,
          "Harvest_Quality",
          85,
          "Excellent harvest quality",
          1,
          1,
          0,
          "ipfs://event-docs"
        )
      ).to.emit(farmerReputation, "ReputationEventRecorded")
        .withArgs(1, farmer1.address, "Harvest_Quality");
    });

    it("Should not allow non-owner to record reputation events", async function () {
      await expect(
        farmerReputation.connect(addr1).recordReputationEvent(
          farmer1.address,
          "Harvest_Quality",
          85,
          "Excellent harvest quality",
          1,
          1,
          0,
          "ipfs://event-docs"
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should reject invalid scores", async function () {
      await expect(
        farmerReputation.connect(owner).recordReputationEvent(
          farmer1.address,
          "Harvest_Quality",
          101, // Invalid score > 100
          "Excellent harvest quality",
          1,
          1,
          0,
          "ipfs://event-docs"
        )
      ).to.be.revertedWith("Score cannot exceed 100");
    });
  });

  describe("Reputation Updates", function () {
    beforeEach(async function () {
      await farmerReputation.connect(farmer1).registerFarmer(
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );
    });

    it("Should update reputation score correctly", async function () {
      await farmerReputation.connect(owner).recordReputationEvent(
        farmer1.address,
        "Harvest_Quality",
        85,
        "Excellent harvest quality",
        1,
        1,
        0,
        "ipfs://event-docs"
      );

      const profile = await farmerReputation.getFarmerProfile(farmer1.address);
      expect(profile.reputationScore).to.equal(270); // 100 + (85 * 2) = 270
    });

    it("Should cap reputation score at maximum", async function () {
      // Record multiple high-score events to test capping
      for (let i = 0; i < 10; i++) {
        await farmerReputation.connect(owner).recordReputationEvent(
          farmer1.address,
          "Certification",
          100,
          "Perfect certification",
          1,
          1,
          1,
          "ipfs://event-docs"
        );
      }

      const profile = await farmerReputation.getFarmerProfile(farmer1.address);
      expect(profile.reputationScore).to.equal(1000); // MAX_REPUTATION_SCORE
    });

    it("Should handle different event types with correct weights", async function () {
      // Harvest_Quality: weight 2
      await farmerReputation.connect(owner).recordReputationEvent(
        farmer1.address,
        "Harvest_Quality",
        50,
        "Good harvest",
        1,
        1,
        0,
        "ipfs://event-docs"
      );

      // Certification: weight 3
      await farmerReputation.connect(owner).recordReputationEvent(
        farmer1.address,
        "Certification",
        50,
        "Good certification",
        1,
        1,
        1,
        "ipfs://event-docs"
      );

      // Consumer_Rating: weight 1
      await farmerReputation.connect(owner).recordReputationEvent(
        farmer1.address,
        "Consumer_Rating",
        50,
        "Good rating",
        1,
        1,
        0,
        "ipfs://event-docs"
      );

      const profile = await farmerReputation.getFarmerProfile(farmer1.address);
      // 100 + (50*2) + (50*3) + (50*1) = 100 + 100 + 150 + 50 = 400
      expect(profile.reputationScore).to.equal(400);
    });
  });

  describe("Tier Management", function () {
    beforeEach(async function () {
      await farmerReputation.connect(farmer1).registerFarmer(
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );
    });

    it("Should start with Bronze tier", async function () {
      const tier = await farmerReputation.getFarmerTier(farmer1.address);
      expect(tier.tierName).to.equal("Bronze");
      expect(tier.minScore).to.equal(0);
      expect(tier.maxScore).to.equal(250);
    });

    it("Should upgrade to Silver tier", async function () {
      // Add enough reputation to reach Silver tier (251-500)
      await farmerReputation.connect(owner).recordReputationEvent(
        farmer1.address,
        "Certification",
        100,
        "Perfect certification",
        1,
        1,
        1,
        "ipfs://event-docs"
      );

      const tier = await farmerReputation.getFarmerTier(farmer1.address);
      expect(tier.tierName).to.equal("Silver");
    });

    it("Should upgrade to Gold tier", async function () {
      // Add enough reputation to reach Gold tier (501-750)
      for (let i = 0; i < 3; i++) {
        await farmerReputation.connect(owner).recordReputationEvent(
          farmer1.address,
          "Certification",
          100,
          "Perfect certification",
          1,
          1,
          1,
          "ipfs://event-docs"
        );
      }

      const tier = await farmerReputation.getFarmerTier(farmer1.address);
      expect(tier.tierName).to.equal("Gold");
    });

    it("Should upgrade to Platinum tier", async function () {
      // Add enough reputation to reach Platinum tier (751-1000)
      for (let i = 0; i < 5; i++) {
        await farmerReputation.connect(owner).recordReputationEvent(
          farmer1.address,
          "Certification",
          100,
          "Perfect certification",
          1,
          1,
          1,
          "ipfs://event-docs"
        );
      }

      const tier = await farmerReputation.getFarmerTier(farmer1.address);
      expect(tier.tierName).to.equal("Platinum");
    });

    it("Should emit TierUpgraded event", async function () {
      await expect(
        farmerReputation.connect(owner).recordReputationEvent(
          farmer1.address,
          "Certification",
          100,
          "Perfect certification",
          1,
          1,
          1,
          "ipfs://event-docs"
        )
      ).to.emit(farmerReputation, "TierUpgraded")
        .withArgs(farmer1.address, "Silver");
    });
  });

  describe("Quality Metrics", function () {
    beforeEach(async function () {
      await farmerReputation.connect(farmer1).registerFarmer(
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );
    });

    it("Should allow owner to update quality metrics", async function () {
      await farmerReputation.connect(owner).updateQualityMetrics(
        farmer1.address,
        85, // averageSize
        15, // averageSweetness
        8, // averageFirmness
        5, // defectRate
        90 // exportStandardCompliance
      );

      const metrics = await farmerReputation.getFarmerQualityMetrics(farmer1.address);
      expect(metrics.averageSize).to.equal(85);
      expect(metrics.averageSweetness).to.equal(15);
      expect(metrics.averageFirmness).to.equal(8);
      expect(metrics.defectRate).to.equal(5);
      expect(metrics.exportStandardCompliance).to.equal(90);
    });

    it("Should not allow non-owner to update quality metrics", async function () {
      await expect(
        farmerReputation.connect(addr1).updateQualityMetrics(
          farmer1.address,
          85,
          15,
          8,
          5,
          90
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should emit QualityMetricsUpdated event", async function () {
      await expect(
        farmerReputation.connect(owner).updateQualityMetrics(
          farmer1.address,
          85,
          15,
          8,
          5,
          90
        )
      ).to.emit(farmerReputation, "QualityMetricsUpdated")
        .withArgs(farmer1.address, 100); // High consistency score
    });
  });

  describe("Access Control", function () {
    beforeEach(async function () {
      await farmerReputation.connect(farmer1).registerFarmer(
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );
    });

    it("Should allow owner to verify farmers", async function () {
      await farmerReputation.connect(owner).verifyFarmer(farmer1.address, true);
      
      const profile = await farmerReputation.getFarmerProfile(farmer1.address);
      expect(profile.isVerified).to.equal(true);
    });

    it("Should not allow non-owner to verify farmers", async function () {
      await expect(
        farmerReputation.connect(addr1).verifyFarmer(farmer1.address, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should allow owner to update farmer stats", async function () {
      await farmerReputation.connect(owner).updateFarmerStats(
        farmer1.address,
        10, // treeCount
        5, // harvestCount
        3, // certificationCount
        80, // organicPercentage
        85 // consumerRating
      );

      const profile = await farmerReputation.getFarmerProfile(farmer1.address);
      expect(profile.totalTrees).to.equal(10);
      expect(profile.totalHarvests).to.equal(5);
      expect(profile.totalCertifications).to.equal(3);
      expect(profile.organicPercentage).to.equal(80);
      expect(profile.consumerRating).to.equal(85);
    });
  });

  describe("Queries and Statistics", function () {
    beforeEach(async function () {
      await farmerReputation.connect(farmer1).registerFarmer(
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );
    });

    it("Should return correct total reputation events", async function () {
      await farmerReputation.connect(owner).recordReputationEvent(
        farmer1.address,
        "Harvest_Quality",
        85,
        "Excellent harvest quality",
        1,
        1,
        0,
        "ipfs://event-docs"
      );

      const totalEvents = await farmerReputation.getTotalReputationEvents();
      expect(totalEvents).to.equal(1);
    });

    it("Should return farmer events", async function () {
      await farmerReputation.connect(owner).recordReputationEvent(
        farmer1.address,
        "Harvest_Quality",
        85,
        "Excellent harvest quality",
        1,
        1,
        0,
        "ipfs://event-docs"
      );

      const events = await farmerReputation.getFarmerEvents(farmer1.address);
      expect(events.length).to.equal(1);
      expect(events[0]).to.equal(1);
    });

    it("Should check if farmer is verified", async function () {
      expect(await farmerReputation.isFarmerVerified(farmer1.address)).to.equal(false);
      
      await farmerReputation.connect(owner).verifyFarmer(farmer1.address, true);
      expect(await farmerReputation.isFarmerVerified(farmer1.address)).to.equal(true);
    });
  });
});