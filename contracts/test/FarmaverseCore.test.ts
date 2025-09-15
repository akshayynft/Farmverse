import { expect } from "chai";
import { ethers } from "hardhat";
import { 
  FarmaverseCore, 
  TreeID, 
  Certification, 
  Harvest, 
  SupplyChain, 
  ConsumerVerification, 
  FarmerReputation, 
  WasteManagement, 
  Processing 
} from "../typechain-types";
import { SignerWithAddress } from "@ethersproject/contracts";

describe("FarmaverseCore", function () {
  let farmaverseCore: FarmaverseCore;
  let treeID: TreeID;
  let certification: Certification;
  let harvest: Harvest;
  let supplyChain: SupplyChain;
  let consumerVerification: ConsumerVerification;
  let farmerReputation: FarmerReputation;
  let wasteManagement: WasteManagement;
  let processing: Processing;
  
  let owner: SignerWithAddress;
  let farmer1: SignerWithAddress;
  let farmer2: SignerWithAddress;
  let consumer1: SignerWithAddress;
  let lab: SignerWithAddress;
  let processor: SignerWithAddress;
  let addr1: SignerWithAddress;

  beforeEach(async function () {
    [owner, farmer1, farmer2, consumer1, lab, processor, addr1] = await ethers.getSigners();
    
    // Deploy all contracts
    const TreeIDFactory = await ethers.getContractFactory("TreeID");
    treeID = await TreeIDFactory.deploy();
    await treeID.waitForDeployment();

    const CertificationFactory = await ethers.getContractFactory("Certification");
    certification = await CertificationFactory.deploy();
    await certification.waitForDeployment();

    const HarvestFactory = await ethers.getContractFactory("Harvest");
    harvest = await HarvestFactory.deploy();
    await harvest.waitForDeployment();

    const SupplyChainFactory = await ethers.getContractFactory("SupplyChain");
    supplyChain = await SupplyChainFactory.deploy();
    await supplyChain.waitForDeployment();

    const ConsumerVerificationFactory = await ethers.getContractFactory("ConsumerVerification");
    consumerVerification = await ConsumerVerificationFactory.deploy();
    await consumerVerification.waitForDeployment();

    const FarmerReputationFactory = await ethers.getContractFactory("FarmerReputation");
    farmerReputation = await FarmerReputationFactory.deploy();
    await farmerReputation.waitForDeployment();

    const WasteManagementFactory = await ethers.getContractFactory("WasteManagement");
    wasteManagement = await WasteManagementFactory.deploy();
    await wasteManagement.waitForDeployment();

    const ProcessingFactory = await ethers.getContractFactory("Processing");
    processing = await ProcessingFactory.deploy();
    await processing.waitForDeployment();

    // Deploy FarmaverseCore
    const FarmaverseCoreFactory = await ethers.getContractFactory("FarmaverseCore");
    farmaverseCore = await FarmaverseCoreFactory.deploy();
    await farmaverseCore.waitForDeployment();

    // Set contract addresses
    await farmaverseCore.setContractAddresses(
      await treeID.getAddress(),
      await certification.getAddress(),
      await harvest.getAddress(),
      await supplyChain.getAddress(),
      await consumerVerification.getAddress(),
      await farmerReputation.getAddress(),
      await wasteManagement.getAddress(),
      await processing.getAddress()
    );
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await farmaverseCore.owner()).to.equal(owner.address);
    });

    it("Should set contract addresses correctly", async function () {
      expect(await farmaverseCore.treeIDAddress()).to.equal(await treeID.getAddress());
      expect(await farmaverseCore.certificationAddress()).to.equal(await certification.getAddress());
      expect(await farmaverseCore.harvestAddress()).to.equal(await harvest.getAddress());
      expect(await farmaverseCore.supplyChainAddress()).to.equal(await supplyChain.getAddress());
      expect(await farmaverseCore.consumerVerificationAddress()).to.equal(await consumerVerification.getAddress());
      expect(await farmaverseCore.farmerReputationAddress()).to.equal(await farmerReputation.getAddress());
      expect(await farmaverseCore.wasteManagementAddress()).to.equal(await wasteManagement.getAddress());
      expect(await farmaverseCore.processingAddress()).to.equal(await processing.getAddress());
    });

    it("Should emit ContractsDeployed event", async function () {
      const FarmaverseCoreFactory = await ethers.getContractFactory("FarmaverseCore");
      const newCore = await FarmaverseCoreFactory.deploy();
      await newCore.waitForDeployment();

      await expect(
        newCore.setContractAddresses(
          await treeID.getAddress(),
          await certification.getAddress(),
          await harvest.getAddress(),
          await supplyChain.getAddress(),
          await consumerVerification.getAddress(),
          await farmerReputation.getAddress(),
          await wasteManagement.getAddress(),
          await processing.getAddress()
        )
      ).to.emit(newCore, "ContractsDeployed");
    });
  });

  describe("Farm Registration", function () {
    it("Should register farm successfully", async function () {
      const treeId = await farmaverseCore.connect(farmer1).registerFarm(
        "Maharashtra, India",
        "Alphonso Mango",
        Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        "ipfs://tree-metadata",
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );

      expect(treeId).to.equal(1);
      
      const tree = await treeID.getTreeById(treeId);
      expect(tree.location).to.equal("Maharashtra, India");
      expect(tree.variety).to.equal("Alphonso Mango");
    });

    it("Should emit CompleteTraceabilityCreated event", async function () {
      await expect(
        farmaverseCore.connect(farmer1).registerFarm(
          "Maharashtra, India",
          "Alphonso Mango",
          Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
          "ipfs://tree-metadata",
          "John Farmer",
          "Maharashtra, India",
          "ipfs://farmer-profile"
        )
      ).to.emit(farmaverseCore, "CompleteTraceabilityCreated");
    });

    it("Should handle farmer already registered in reputation system", async function () {
      // Register farmer first
      await farmerReputation.connect(farmer1).registerFarmer(
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );

      // Register farm (should not fail)
      const treeId = await farmaverseCore.connect(farmer1).registerFarm(
        "Maharashtra, India",
        "Alphonso Mango",
        Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        "ipfs://tree-metadata",
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );

      expect(treeId).to.equal(1);
    });
  });

  describe("Harvest Process", function () {
    let treeId: number;

    beforeEach(async function () {
      treeId = await farmaverseCore.connect(farmer1).registerFarm(
        "Maharashtra, India",
        "Alphonso Mango",
        Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        "ipfs://tree-metadata",
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );
    });

    it("Should complete harvest with quality metrics", async function () {
      const harvestId = await farmaverseCore.connect(farmer1).completeHarvest(
        treeId,
        ethers.parseEther("100"), // 100 kg
        "Premium",
        8, // ripeness level
        true, // isOrganic
        "Hand Picking",
        "ipfs://harvest-metadata",
        85, // size
        15, // sweetness
        8, // firmness
        9, // color score
        5, // defect percentage
        true, // meets export standards
        "Excellent quality harvest"
      );

      expect(harvestId).to.equal(1);
      
      const harvestData = await harvest.getHarvest(harvestId);
      expect(harvestData.quantity).to.equal(ethers.parseEther("100"));
      expect(harvestData.qualityGrade).to.equal("Premium");
    });

    it("Should update farmer reputation with harvest quality", async function () {
      await farmaverseCore.connect(farmer1).completeHarvest(
        treeId,
        ethers.parseEther("100"),
        "Premium",
        8,
        true,
        "Hand Picking",
        "ipfs://harvest-metadata",
        85, // size
        15, // sweetness
        8, // firmness
        9, // color score
        5, // defect percentage
        true,
        "Excellent quality harvest"
      );

      // Check if reputation event was recorded
      const events = await farmerReputation.getFarmerEvents(farmer1.address);
      expect(events.length).to.equal(1);
    });
  });

  describe("Certification Process", function () {
    let treeId: number;

    beforeEach(async function () {
      treeId = await farmaverseCore.connect(farmer1).registerFarm(
        "Maharashtra, India",
        "Alphonso Mango",
        Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        "ipfs://tree-metadata",
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );

      // Authorize lab
      await certification.connect(owner).authorizeLab(lab.address, true);
    });

    it("Should complete certification with lab test", async function () {
      const [certificationId, labTestId] = await farmaverseCore.connect(farmer1).completeCertification(
        treeId,
        "Organic",
        Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60), // 1 year from now
        "NPOP Authority",
        "ipfs://cert-docs",
        "Test Lab",
        "Pesticide Test",
        true, // passed
        "ipfs://lab-results",
        10, // pesticide level
        5, // heavy metal level
        true // microbial safe
      );

      expect(certificationId).to.equal(1);
      expect(labTestId).to.equal(1);
      
      const cert = await certification.getCertification(certificationId);
      expect(cert.certificationType).to.equal("Organic");
    });

    it("Should update farmer reputation with certification", async function () {
      await farmaverseCore.connect(farmer1).completeCertification(
        treeId,
        "Organic",
        Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60),
        "NPOP Authority",
        "ipfs://cert-docs",
        "Test Lab",
        "Pesticide Test",
        true,
        "ipfs://lab-results",
        10,
        5,
        true
      );

      const events = await farmerReputation.getFarmerEvents(farmer1.address);
      expect(events.length).to.equal(1);
    });
  });

  describe("Supply Chain Management", function () {
    let treeId: number;
    let harvestId: number;

    beforeEach(async function () {
      treeId = await farmaverseCore.connect(farmer1).registerFarm(
        "Maharashtra, India",
        "Alphonso Mango",
        Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        "ipfs://tree-metadata",
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );

      harvestId = await farmaverseCore.connect(farmer1).completeHarvest(
        treeId,
        ethers.parseEther("100"),
        "Premium",
        8,
        true,
        "Hand Picking",
        "ipfs://harvest-metadata",
        85,
        15,
        8,
        9,
        5,
        true,
        "Excellent quality harvest"
      );
    });

    it("Should create batch and transfer ownership", async function () {
      const batchId = await farmaverseCore.connect(farmer1).createBatchAndTransfer(
        [harvestId],
        "BATCH001",
        "ipfs://qr-code",
        processor.address,
        "Distributor",
        "Processing Facility",
        "ipfs://transfer-docs",
        25, // temperature
        60, // humidity
        "Refrigerated"
      );

      expect(batchId).to.equal(1);
      
      const batch = await supplyChain.getBatchTraceability(batchId);
      expect(batch.batch.batchCode).to.equal("BATCH001");
    });
  });

  describe("Consumer Verification", function () {
    let batchId: number;

    beforeEach(async function () {
      // Register consumer
      await consumerVerification.connect(consumer1).registerConsumer("Jane Consumer", "jane@example.com");
      
      // Create a batch
      const treeId = await farmaverseCore.connect(farmer1).registerFarm(
        "Maharashtra, India",
        "Alphonso Mango",
        Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        "ipfs://tree-metadata",
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );

      const harvestId = await farmaverseCore.connect(farmer1).completeHarvest(
        treeId,
        ethers.parseEther("100"),
        "Premium",
        8,
        true,
        "Hand Picking",
        "ipfs://harvest-metadata",
        85,
        15,
        8,
        9,
        5,
        true,
        "Excellent quality harvest"
      );

      batchId = await farmaverseCore.connect(farmer1).createBatchAndTransfer(
        [harvestId],
        "BATCH001",
        "ipfs://qr-code",
        consumer1.address,
        "Consumer",
        "Retail Store",
        "ipfs://transfer-docs",
        25,
        60,
        "Ambient"
      );
    });

    it("Should complete consumer verification", async function () {
      const verificationId = await farmaverseCore.connect(consumer1).completeConsumerVerification(
        batchId,
        true, // isAuthentic
        "Product looks authentic and fresh",
        5, // rating
        "Excellent quality, would buy again",
        "ipfs://verification-docs"
      );

      expect(verificationId).to.equal(1);
      
      const verification = await consumerVerification.getVerification(verificationId);
      expect(verification.isAuthentic).to.equal(true);
      expect(verification.rating).to.equal(5);
    });
  });

  describe("Waste Management", function () {
    let batchId: number;

    beforeEach(async function () {
      // Create a batch
      const treeId = await farmaverseCore.connect(farmer1).registerFarm(
        "Maharashtra, India",
        "Alphonso Mango",
        Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        "ipfs://tree-metadata",
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );

      const harvestId = await farmaverseCore.connect(farmer1).completeHarvest(
        treeId,
        ethers.parseEther("100"),
        "Premium",
        8,
        true,
        "Hand Picking",
        "ipfs://harvest-metadata",
        85,
        15,
        8,
        9,
        5,
        true,
        "Excellent quality harvest"
      );

      batchId = await farmaverseCore.connect(farmer1).createBatchAndTransfer(
        [harvestId],
        "BATCH001",
        "ipfs://qr-code",
        processor.address,
        "Distributor",
        "Processing Facility",
        "ipfs://transfer-docs",
        25,
        60,
        "Refrigerated"
      );

      // Authorize reporter
      await wasteManagement.connect(owner).authorizeReporter(processor.address, true);
    });

    it("Should report waste successfully", async function () {
      const wasteEventId = await farmaverseCore.connect(processor).reportWaste(
        batchId,
        ethers.parseEther("5"), // 5 kg waste
        "Processing",
        "Damaged",
        "Physical damage during processing",
        "Compost",
        true, // isRecycled
        "ipfs://waste-docs",
        ethers.parseEther("0.1") // cost
      );

      expect(wasteEventId).to.equal(1);
      
      const wasteEvent = await wasteManagement.getWasteEvent(wasteEventId);
      expect(wasteEvent.quantity).to.equal(ethers.parseEther("5"));
      expect(wasteEvent.stage).to.equal("Processing");
    });
  });

  describe("Processing Management", function () {
    let batchId: number;

    beforeEach(async function () {
      // Create a batch
      const treeId = await farmaverseCore.connect(farmer1).registerFarm(
        "Maharashtra, India",
        "Alphonso Mango",
        Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        "ipfs://tree-metadata",
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );

      const harvestId = await farmaverseCore.connect(farmer1).completeHarvest(
        treeId,
        ethers.parseEther("100"),
        "Premium",
        8,
        true,
        "Hand Picking",
        "ipfs://harvest-metadata",
        85,
        15,
        8,
        9,
        5,
        true,
        "Excellent quality harvest"
      );

      batchId = await farmaverseCore.connect(farmer1).createBatchAndTransfer(
        [harvestId],
        "BATCH001",
        "ipfs://qr-code",
        processor.address,
        "Distributor",
        "Processing Facility",
        "ipfs://transfer-docs",
        25,
        60,
        "Refrigerated"
      );

      // Register processing facility
      await processing.connect(processor).registerFacility(
        "Mango Processing Plant",
        "Maharashtra, India",
        "Primary",
        "CERT001"
      );

      // Authorize facility
      await processing.connect(owner).authorizeFacility(processor.address, true);
    });

    it("Should start processing successfully", async function () {
      const processingEventId = await farmaverseCore.connect(processor).startProcessing(
        batchId,
        ethers.parseEther("100"), // input quantity
        "Washing and Sorting",
        "Plastic",
        "1kg",
        "ipfs://processing-docs"
      );

      expect(processingEventId).to.equal(1);
      
      const processingEvent = await processing.getProcessingEvent(processingEventId);
      expect(processingEvent.processingMethod).to.equal("Washing and Sorting");
    });

    it("Should complete processing successfully", async function () {
      const processingEventId = await farmaverseCore.connect(processor).startProcessing(
        batchId,
        ethers.parseEther("100"),
        "Washing and Sorting",
        "Plastic",
        "1kg",
        "ipfs://processing-docs"
      );

      await farmaverseCore.connect(processor).completeProcessing(
        processingEventId,
        ethers.parseEther("95"), // output quantity (5% waste)
        95, // package count
        true, // quality passed
        "All quality checks passed",
        ethers.parseEther("0.5") // cost
      );

      const processingEvent = await processing.getProcessingEvent(processingEventId);
      expect(processingEvent.outputQuantity).to.equal(ethers.parseEther("95"));
      expect(processingEvent.qualityPassed).to.equal(true);
    });
  });

  describe("Complete Traceability", function () {
    let batchId: number;

    beforeEach(async function () {
      // Create complete traceability chain
      const treeId = await farmaverseCore.connect(farmer1).registerFarm(
        "Maharashtra, India",
        "Alphonso Mango",
        Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        "ipfs://tree-metadata",
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );

      const harvestId = await farmaverseCore.connect(farmer1).completeHarvest(
        treeId,
        ethers.parseEther("100"),
        "Premium",
        8,
        true,
        "Hand Picking",
        "ipfs://harvest-metadata",
        85,
        15,
        8,
        9,
        5,
        true,
        "Excellent quality harvest"
      );

      batchId = await farmaverseCore.connect(farmer1).createBatchAndTransfer(
        [harvestId],
        "BATCH001",
        "ipfs://qr-code",
        consumer1.address,
        "Consumer",
        "Retail Store",
        "ipfs://transfer-docs",
        25,
        60,
        "Ambient"
      );
    });

    it("Should return complete traceability data", async function () {
      const [batch, transfers, harvestIds, treeIds, trees] = await farmaverseCore.getCompleteTraceability(batchId);

      expect(batch.batchCode).to.equal("BATCH001");
      expect(harvestIds.length).to.equal(1);
      expect(treeIds.length).to.equal(1);
      expect(trees.length).to.equal(1);
      expect(trees[0].variety).to.equal("Alphonso Mango");
    });

    it("Should return farmer complete profile", async function () {
      const [reputation, quality, tier, treeIds, harvestIds] = await farmaverseCore.getFarmerCompleteProfile(farmer1.address);

      expect(reputation.farmerName).to.equal("John Farmer");
      expect(treeIds.length).to.equal(1);
      expect(harvestIds.length).to.equal(1);
    });
  });

  describe("System Statistics", function () {
    beforeEach(async function () {
      // Create some data
      const treeId = await farmaverseCore.connect(farmer1).registerFarm(
        "Maharashtra, India",
        "Alphonso Mango",
        Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        "ipfs://tree-metadata",
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );

      const harvestId = await farmaverseCore.connect(farmer1).completeHarvest(
        treeId,
        ethers.parseEther("100"),
        "Premium",
        8,
        true,
        "Hand Picking",
        "ipfs://harvest-metadata",
        85,
        15,
        8,
        9,
        5,
        true,
        "Excellent quality harvest"
      );

      await farmaverseCore.connect(farmer1).createBatchAndTransfer(
        [harvestId],
        "BATCH001",
        "ipfs://qr-code",
        consumer1.address,
        "Consumer",
        "Retail Store",
        "ipfs://transfer-docs",
        25,
        60,
        "Ambient"
      );
    });

    it("Should return correct system statistics", async function () {
      const [
        totalTrees,
        totalHarvests,
        totalBatches,
        totalVerifications,
        totalReputationEvents,
        totalWasteEvents,
        totalProcessingEvents
      ] = await farmaverseCore.getSystemStats();

      expect(totalTrees).to.equal(1);
      expect(totalHarvests).to.equal(1);
      expect(totalBatches).to.equal(1);
      expect(totalVerifications).to.equal(0);
      expect(totalReputationEvents).to.equal(1);
      expect(totalWasteEvents).to.equal(0);
      expect(totalProcessingEvents).to.equal(0);
    });
  });

  describe("Access Control", function () {
    it("Should not allow non-owner to set contract addresses", async function () {
      await expect(
        farmaverseCore.connect(addr1).setContractAddresses(
          await treeID.getAddress(),
          await certification.getAddress(),
          await harvest.getAddress(),
          await supplyChain.getAddress(),
          await consumerVerification.getAddress(),
          await farmerReputation.getAddress(),
          await wasteManagement.getAddress(),
          await processing.getAddress()
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should reject zero addresses", async function () {
      await expect(
        farmaverseCore.setContractAddresses(
          ethers.ZeroAddress, // Invalid TreeID address
          await certification.getAddress(),
          await harvest.getAddress(),
          await supplyChain.getAddress(),
          await consumerVerification.getAddress(),
          await farmerReputation.getAddress(),
          await wasteManagement.getAddress(),
          await processing.getAddress()
        )
      ).to.be.revertedWith("Invalid TreeID address");
    });
  });

  describe("Quality Score Calculation", function () {
    it("Should calculate correct quality score", async function () {
      // Test the quality score calculation logic
      const treeId = await farmaverseCore.connect(farmer1).registerFarm(
        "Maharashtra, India",
        "Alphonso Mango",
        Math.floor(Date.now() / 1000) - (365 * 24 * 60 * 60),
        "ipfs://tree-metadata",
        "John Farmer",
        "Maharashtra, India",
        "ipfs://farmer-profile"
      );

      // High quality harvest
      await farmaverseCore.connect(farmer1).completeHarvest(
        treeId,
        ethers.parseEther("100"),
        "Premium",
        8,
        true,
        "Hand Picking",
        "ipfs://harvest-metadata",
        85, // size
        15, // sweetness
        8, // firmness
        9, // color score
        5, // defect percentage
        true,
        "Excelle