import { expect } from "chai";
import { ethers } from "hardhat";
import { TreeID } from "../typechain-types";
import { SignerWithAddress } from "@ethersproject/contracts";

describe("TreeID", function () {
  let treeID: TreeID;
  let owner: SignerWithAddress;
  let farmer1: SignerWithAddress;
  let farmer2: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;

  beforeEach(async function () {
    [owner, farmer1, farmer2, addr1, addr2] = await ethers.getSigners();
    
    const TreeIDFactory = await ethers.getContractFactory("TreeID");
    treeID = await TreeIDFactory.deploy();
    await treeID.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await treeID.owner()).to.equal(owner.address);
    });

    it("Should have correct contract name", async function () {
      expect(await treeID.name()).to.equal("Farmaverse Tree ID");
    });

    it("Should have correct contract symbol", async function () {
      expect(await treeID.symbol()).to.equal("TREE");
    });
  });

  describe("Tree Registration", function () {
    const treeData = {
      farmerAddress: "",
      location: "Maharashtra, India",
      variety: "Alphonso",
      plantingDate: Math.floor(Date.now() / 1000),
      expectedHarvestDate: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60), // 1 year from now
      organicCertified: true,
      irrigationType: "Drip",
      soilType: "Red Soil",
      coordinates: "19.0760,72.8777"
    };

    beforeEach(async function () {
      treeData.farmerAddress = farmer1.address;
    });

    it("Should allow farmers to register trees", async function () {
      await treeID.connect(farmer1).registerTree(treeData);
      
      const treeCount = await treeID.getTreeCount(farmer1.address);
      expect(treeCount).to.equal(1);
    });

    it("Should emit TreeRegistered event", async function () {
      await expect(treeID.connect(farmer1).registerTree(treeData))
        .to.emit(treeID, "TreeRegistered")
        .withArgs(farmer1.address, 0, treeData.variety, treeData.location);
    });

    it("Should increment tree counter for farmer", async function () {
      await treeID.connect(farmer1).registerTree(treeData);
      await treeID.connect(farmer1).registerTree(treeData);
      
      const treeCount = await treeID.getTreeCount(farmer1.address);
      expect(treeCount).to.equal(2);
    });

    it("Should store correct tree data", async function () {
      await treeID.connect(farmer1).registerTree(treeData);
      
      const tree = await treeID.getTree(farmer1.address, 0);
      expect(tree.farmerAddress).to.equal(farmer1.address);
      expect(tree.location).to.equal(treeData.location);
      expect(tree.variety).to.equal(treeData.variety);
      expect(tree.organicCertified).to.equal(treeData.organicCertified);
    });
  });

  describe("Tree Management", function () {
    let treeId: number;

    beforeEach(async function () {
      const treeData = {
        farmerAddress: farmer1.address,
        location: "Maharashtra, India",
        variety: "Alphonso",
        plantingDate: Math.floor(Date.now() / 1000),
        expectedHarvestDate: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60),
        organicCertified: true,
        irrigationType: "Drip",
        soilType: "Red Soil",
        coordinates: "19.0760,72.8777"
      };
      
      await treeID.connect(farmer1).registerTree(treeData);
      treeId = 0;
    });

    it("Should allow farmers to update tree location", async function () {
      const newLocation = "Karnataka, India";
      await treeID.connect(farmer1).updateTreeLocation(treeId, newLocation);
      
      const tree = await treeID.getTree(farmer1.address, treeId);
      expect(tree.location).to.equal(newLocation);
    });

    it("Should allow farmers to update irrigation type", async function () {
      const newIrrigationType = "Sprinkler";
      await treeID.connect(farmer1).updateIrrigationType(treeId, newIrrigationType);
      
      const tree = await treeID.getTree(farmer1.address, treeId);
      expect(tree.irrigationType).to.equal(newIrrigationType);
    });

    it("Should allow farmers to update organic certification", async function () {
      await treeID.connect(farmer1).updateOrganicCertification(treeId, false);
      
      const tree = await treeID.getTree(farmer1.address, treeId);
      expect(tree.organicCertified).to.equal(false);
    });

    it("Should emit TreeUpdated event on location change", async function () {
      const newLocation = "Karnataka, India";
      await expect(treeID.connect(farmer1).updateTreeLocation(treeId, newLocation))
        .to.emit(treeID, "TreeUpdated")
        .withArgs(farmer1.address, treeId, "location", newLocation);
    });
  });

  describe("Access Control", function () {
    it("Should not allow non-farmers to update tree data", async function () {
      const treeData = {
        farmerAddress: farmer1.address,
        location: "Maharashtra, India",
        variety: "Alphonso",
        plantingDate: Math.floor(Date.now() / 1000),
        expectedHarvestDate: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60),
        organicCertified: true,
        irrigationType: "Drip",
        soilType: "Red Soil",
        coordinates: "19.0760,72.8777"
      };
      
      await treeID.connect(farmer1).registerTree(treeData);
      
      await expect(
        treeID.connect(addr1).updateTreeLocation(0, "New Location")
      ).to.be.revertedWith("Only tree owner can update");
    });

    it("Should not allow updating non-existent tree", async function () {
      await expect(
        treeID.connect(farmer1).updateTreeLocation(999, "New Location")
      ).to.be.revertedWith("Tree does not exist");
    });
  });

  describe("Tree Queries", function () {
    beforeEach(async function () {
      const treeData = {
        farmerAddress: farmer1.address,
        location: "Maharashtra, India",
        variety: "Alphonso",
        plantingDate: Math.floor(Date.now() / 1000),
        expectedHarvestDate: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60),
        organicCertified: true,
        irrigationType: "Drip",
        soilType: "Red Soil",
        coordinates: "19.0760,72.8777"
      };
      
      await treeID.connect(farmer1).registerTree(treeData);
    });

    it("Should return correct tree count for farmer", async function () {
      const count = await treeID.getTreeCount(farmer1.address);
      expect(count).to.equal(1);
    });

    it("Should return correct tree data", async function () {
      const tree = await treeID.getTree(farmer1.address, 0);
      expect(tree.farmerAddress).to.equal(farmer1.address);
      expect(tree.variety).to.equal("Alphonso");
    });

    it("Should return empty tree data for non-existent tree", async function () {
      const tree = await treeID.getTree(farmer1.address, 999);
      expect(tree.farmerAddress).to.equal(ethers.ZeroAddress);
    });
  });

  describe("Owner Functions", function () {
    it("Should allow owner to transfer ownership", async function () {
      await treeID.transferOwnership(farmer1.address);
      expect(await treeID.owner()).to.equal(farmer1.address);
    });

    it("Should not allow non-owner to transfer ownership", async function () {
      await expect(
        treeID.connect(farmer1).transferOwnership(addr1.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});


