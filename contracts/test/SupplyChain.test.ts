import { expect } from "chai";
import { ethers } from "hardhat";
import { SupplyChain, TreeID, Harvest, Certification } from "../typechain-types";
import { SignerWithAddress } from "@ethersproject/contracts";

describe("SupplyChain", function () {
  let supplyChain: SupplyChain;
  let treeID: TreeID;
  let harvest: Harvest;
  let certification: Certification;
  let owner: SignerWithAddress;
  let farmer1: SignerWithAddress;
  let farmer2: SignerWithAddress;
  let distributor: SignerWithAddress;
  let retailer: SignerWithAddress;
  let consumer: SignerWithAddress;
  let addr1: SignerWithAddress;

  beforeEach(async function () {
    [owner, farmer1, farmer2, distributor, retailer, consumer, addr1] = await ethers.getSigners();
    
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
    
    const SupplyChainFactory = await ethers.getContractFactory("SupplyChain");
    supplyChain = await SupplyChainFactory.deploy();
    await supplyChain.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await supplyChain.owner()).to.equal(owner.address);
    });

    it("Should have correct contract name", async function () {
      expect(await supplyChain.name()).to.equal("Farmaverse Supply Chain");
    });
  });

  describe("Product Registration", function () {
    let treeId: number;
    let harvestId: number;
    let productData: any;

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

      productData = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        productName: "Alphonso Mangoes",
        productType: "Fresh Fruit",
        quantity: ethers.parseEther("50"), // 50 kg
        packagingType: "Cardboard Box",
        packagingDate: Math.floor(Date.now() / 1000),
        expiryDate: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60), // 30 days
        storageConditions: "Refrigerated",
        notes: "Premium quality Alphonso mangoes"
      };
    });

    it("Should allow farmers to register products", async function () {
      await supplyChain.connect(farmer1).registerProduct(productData);
      
      const productCount = await supplyChain.getProductCount(farmer1.address);
      expect(productCount).to.equal(1);
    });

    it("Should generate unique QR codes for products", async function () {
      await supplyChain.connect(farmer1).registerProduct(productData);
      
      const product = await supplyChain.getProduct(farmer1.address, 0);
      expect(product.qrCode).to.not.equal("");
      expect(product.qrCode).to.include("FARM");
    });

    it("Should emit ProductRegistered event", async function () {
      await expect(supplyChain.connect(farmer1).registerProduct(productData))
        .to.emit(supplyChain, "ProductRegistered")
        .withArgs(farmer1.address, 0, productData.productName, productData.quantity);
    });

    it("Should store correct product data", async function () {
      await supplyChain.connect(farmer1).registerProduct(productData);
      
      const product = await supplyChain.getProduct(farmer1.address, 0);
      expect(product.harvestId).to.equal(harvestId);
      expect(product.productName).to.equal(productData.productName);
      expect(product.packagingType).to.equal(productData.packagingType);
    });

    it("Should increment product counter for farmer", async function () {
      await supplyChain.connect(farmer1).registerProduct(productData);
      await supplyChain.connect(farmer1).registerProduct(productData);
      
      const productCount = await supplyChain.getProductCount(farmer1.address);
      expect(productCount).to.equal(2);
    });
  });

  describe("Ownership Transfers", function () {
    let treeId: number;
    let harvestId: number;
    let productId: number;

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

      // Register a product
      const productData = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        productName: "Alphonso Mangoes",
        productType: "Fresh Fruit",
        quantity: ethers.parseEther("50"),
        packagingType: "Cardboard Box",
        packagingDate: Math.floor(Date.now() / 1000),
        expiryDate: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60),
        storageConditions: "Refrigerated",
        notes: "Premium quality Alphonso mangoes"
      };
      
      await supplyChain.connect(farmer1).registerProduct(productData);
      productId = 0;
    });

    it("Should allow farmers to transfer products to processors", async function () {
      const transferData = {
        productId: productId,
        newOwner: distributor.address,
        transferType: "Processing",
        temperature: 4, // Celsius
        humidity: 85, // Percentage
        transferDate: Math.floor(Date.now() / 1000),
        notes: "Transfer to processing facility"
      };

      await supplyChain.connect(farmer1).transferOwnership(transferData);
      
      const product = await supplyChain.getProduct(farmer1.address, productId);
      expect(product.currentOwner).to.equal(distributor.address);
    });

    it("Should emit OwnershipTransferred event", async function () {
      const transferData = {
        productId: productId,
        newOwner: distributor.address,
        transferType: "Processing",
        temperature: 4,
        humidity: 85,
        transferDate: Math.floor(Date.now() / 1000),
        notes: "Transfer to processing facility"
      };

      await expect(supplyChain.connect(farmer1).transferOwnership(transferData))
        .to.emit(supplyChain, "OwnershipTransferred")
        .withArgs(farmer1.address, distributor.address, productId, "Processing");
    });

    it("Should track environmental conditions during transfer", async function () {
      const transferData = {
        productId: productId,
        newOwner: distributor.address,
        transferType: "Processing",
        temperature: 4,
        humidity: 85,
        transferDate: Math.floor(Date.now() / 1000),
        notes: "Transfer to processing facility"
      };

      await supplyChain.connect(farmer1).transferOwnership(transferData);
      
      const transfer = await supplyChain.getTransferHistory(productId, 0);
      expect(transfer.temperature).to.equal(4);
      expect(transfer.humidity).to.equal(85);
    });

    it("Should maintain transfer history", async function () {
      const transferData1 = {
        productId: productId,
        newOwner: distributor.address,
        transferType: "Processing",
        temperature: 4,
        humidity: 85,
        transferDate: Math.floor(Date.now() / 1000),
        notes: "Transfer to processing facility"
      };

      await supplyChain.connect(farmer1).transferOwnership(transferData1);

      const transferData2 = {
        productId: productId,
        newOwner: retailer.address,
        transferType: "Distribution",
        temperature: 6,
        humidity: 80,
        transferDate: Math.floor(Date.now() / 1000) + 3600,
        notes: "Transfer to distribution center"
      };

      await supplyChain.connect(distributor).transferOwnership(transferData2);
      
      const transferCount = await supplyChain.getTransferHistoryCount(productId);
      expect(transferCount).to.equal(2);
    });
  });

  describe("QR Code Verification", function () {
    let treeId: number;
    let harvestId: number;
    let productId: number;
    let qrCode: string;

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

      // Register a product
      const productData = {
        harvestId: harvestId,
        farmerAddress: farmer1.address,
        productName: "Alphonso Mangoes",
        productType: "Fresh Fruit",
        quantity: ethers.parseEther("50"),
        packagingType: "Cardboard Box",
        packagingDate: Math.floor(Date.now() / 1000),
        expiryDate: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60),
        storageConditions: "Refrigerated",
        notes: "Premium quality Alphonso mangoes"
      };
      
      await supplyChain.connect(farmer1).registerProduct(productData);
      productId = 0;

      const product = await supplyChain.getProduct(farmer1.address, productId);
      qrCode = product.qrCode;
    });

    it("Should verify valid QR codes", async function () {
      const isValid = await supplyChain.verifyQRCode(qrCode);
      expect(isValid).to.equal(true);
    });

    it("Should reject invalid QR codes", async function () {
      const isValid = await supplyChain.verifyQRCode("INVALID_QR_CODE");
      expect(isValid).to.equal(false);
    });

    it("Should return product details from QR code", async function () {
      const productDetails = await supplyChain.getProductByQRCode(qrCode);
      expect(productDetails.farmerAddress).to.equal(farmer1.address);
      expect(productDetails.productName).to.equal("Alphonso Mangoes");
    });

    it("Should return empty data for invalid QR codes", async function () {
      const productDetails = await supplyChain.getProductByQRCode("INVALID_QR_CODE");
      expect(productDetails.farmerAddress).to.equal(ethers.ZeroAddress);
      expect(productDetails.productName).to.equal("");
    });
  });

  describe("Supply Chain Queries", function () {
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

      // Record a harvest
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

      // Register a product
      const productData = {
        harvestId: 0,
        farmerAddress: farmer1.address,
        productName: "Alphonso Mangoes",
        productType: "Fresh Fruit",
        quantity: ethers.parseEther("50"),
        packagingType: "Cardboard Box",
        packagingDate: Math.floor(Date.now() / 1000),
        expiryDate: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60),
        storageConditions: "Refrigerated",
        notes: "Premium quality Alphonso mangoes"
      };
      
      await supplyChain.connect(farmer1).registerProduct(productData);
    });

    it("Should return correct product count for farmer", async function () {
      const count = await supplyChain.getProductCount(farmer1.address);
      expect(count).to.equal(1);
    });

    it("Should return correct product data", async function () {
      const product = await supplyChain.getProduct(farmer1.address, 0);
      expect(product.harvestId).to.equal(0);
      expect(product.productName).to.equal("Alphonso Mangoes");
    });

    it("Should return empty product data for non-existent product", async function () {
      const product = await supplyChain.getProduct(farmer1.address, 999);
      expect(product.harvestId).to.equal(0);
      expect(product.productName).to.equal("");
    });
  });

  describe("Access Control", function () {
    it("Should not allow non-farmers to register products", async function () {
      const productData = {
        harvestId: 0,
        farmerAddress: farmer1.address,
        productName: "Alphonso Mangoes",
        productType: "Fresh Fruit",
        quantity: ethers.parseEther("50"),
        packagingType: "Cardboard Box",
        packagingDate: Math.floor(Date.now() / 1000),
        expiryDate: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60),
        storageConditions: "Refrigerated",
        notes: "Test product"
      };

      await expect(
        supplyChain.connect(addr1).registerProduct(productData)
      ).to.be.revertedWith("Only harvest owner can register product");
    });

    it("Should not allow transferring non-existent products", async function () {
      const transferData = {
        productId: 999,
        newOwner: distributor.address,
        transferType: "Processing",
        temperature: 4,
        humidity: 85,
        transferDate: Math.floor(Date.now() / 1000),
        notes: "Test transfer"
      };

      await expect(
        supplyChain.connect(farmer1).transferOwnership(transferData)
      ).to.be.revertedWith("Product does not exist");
    });
  });

  describe("Owner Functions", function () {
    it("Should allow owner to transfer ownership", async function () {
      await supplyChain.transferOwnership(farmer1.address);
      expect(await supplyChain.owner()).to.equal(farmer1.address);
    });

    it("Should not allow non-owner to transfer ownership", async function () {
      await expect(
        supplyChain.connect(farmer1).transferOwnership(addr1.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});


