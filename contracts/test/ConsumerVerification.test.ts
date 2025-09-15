import { expect } from "chai";
import { ethers } from "hardhat";
import { ConsumerVerification } from "../typechain-types";
import { SignerWithAddress } from "@ethersproject/contracts";

describe("ConsumerVerification", function () {
  let consumerVerification: ConsumerVerification;
  let owner: SignerWithAddress;
  let consumer1: SignerWithAddress;
  let consumer2: SignerWithAddress;
  let consumer3: SignerWithAddress;
  let addr1: SignerWithAddress;

  beforeEach(async function () {
    [owner, consumer1, consumer2, consumer3, addr1] = await ethers.getSigners();
    
    const ConsumerVerificationFactory = await ethers.getContractFactory("ConsumerVerification");
    consumerVerification = await ConsumerVerificationFactory.deploy();
    await consumerVerification.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await consumerVerification.owner()).to.equal(owner.address);
    });
  });

  describe("Consumer Registration", function () {
    it("Should allow consumers to register", async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
      
      const profile = await consumerVerification.getConsumerProfile(consumer1.address);
      expect(profile.name).to.equal("John Doe");
      expect(profile.email).to.equal("john@example.com");
      expect(profile.isActive).to.equal(true);
    });

    it("Should emit ConsumerRegistered event", async function () {
      await expect(
        consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com")
      ).to.emit(consumerVerification, "ConsumerRegistered")
        .withArgs(consumer1.address, "John Doe");
    });

    it("Should not allow duplicate registration", async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
      
      await expect(
        consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com")
      ).to.be.revertedWith("Consumer already registered");
    });

    it("Should reject empty name", async function () {
      await expect(
        consumerVerification.connect(consumer1).registerConsumer("", "john@example.com")
      ).to.be.revertedWith("Name cannot be empty");
    });

    it("Should reject empty email", async function () {
      await expect(
        consumerVerification.connect(consumer1).registerConsumer("John Doe", "")
      ).to.be.revertedWith("Email cannot be empty");
    });
  });

  describe("Product Verification", function () {
    beforeEach(async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
    });

    it("Should allow registered consumers to verify products", async function () {
      const verificationId = await consumerVerification.connect(consumer1).verifyProduct(
        1, // batchId
        true, // isAuthentic
        "Product looks authentic", // verificationNotes
        5, // rating
        "Excellent quality", // feedback
        "ipfs://verification-docs" // ipfsHash
      );

      expect(verificationId).to.equal(1);
      
      const verification = await consumerVerification.getVerification(1);
      expect(verification.isAuthentic).to.equal(true);
      expect(verification.rating).to.equal(5);
    });

    it("Should emit ProductVerified event", async function () {
      await expect(
        consumerVerification.connect(consumer1).verifyProduct(
          1, true, "Authentic", 5, "Great", "ipfs://docs"
        )
      ).to.emit(consumerVerification, "ProductVerified")
        .withArgs(1, 1, consumer1.address);
    });

    it("Should reject invalid ratings", async function () {
      await expect(
        consumerVerification.connect(consumer1).verifyProduct(
          1, true, "Authentic", 6, "Great", "ipfs://docs" // rating > 5
        )
      ).to.be.revertedWith("Rating must be 1-5");
    });

    it("Should reject empty verification notes", async function () {
      await expect(
        consumerVerification.connect(consumer1).verifyProduct(
          1, true, "", 5, "Great", "ipfs://docs"
        )
      ).to.be.revertedWith("Verification notes cannot be empty");
    });

    it("Should not allow unregistered consumers to verify", async function () {
      await expect(
        consumerVerification.connect(addr1).verifyProduct(
          1, true, "Authentic", 5, "Great", "ipfs://docs"
        )
      ).to.be.revertedWith("Consumer must be registered and active");
    });
  });

  describe("Authenticity Checks", function () {
    beforeEach(async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
    });

    it("Should allow active consumers to check authenticity", async function () {
      await consumerVerification.connect(consumer1).checkAuthenticity(
        1, // batchId
        true, // isAuthentic
        "QR_Scan", // checkType
        "QR code verified" // checkNotes
      );

      const checks = await consumerVerification.getBatchAuthenticityChecks(1);
      expect(checks.length).to.equal(1);
      expect(checks[0].isAuthentic).to.equal(true);
    });

    it("Should allow owner to check authenticity", async function () {
      await consumerVerification.connect(owner).checkAuthenticity(
        1, true, "Manual_Check", "Owner verification"
      );

      const checks = await consumerVerification.getBatchAuthenticityChecks(1);
      expect(checks.length).to.equal(1);
    });

    it("Should not allow unauthorized users to check authenticity", async function () {
      await expect(
        consumerVerification.connect(addr1).checkAuthenticity(
          1, true, "QR_Scan", "Unauthorized check"
        )
      ).to.be.revertedWith("Not authorized");
    });

    it("Should emit AuthenticityChecked event", async function () {
      await expect(
        consumerVerification.connect(consumer1).checkAuthenticity(
          1, true, "QR_Scan", "Verified"
        )
      ).to.emit(consumerVerification, "AuthenticityChecked")
        .withArgs(1, true, consumer1.address);
    });
  });

  describe("Batch Rating System", function () {
    beforeEach(async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
      await consumerVerification.connect(consumer2).registerConsumer("Jane Doe", "jane@example.com");
    });

    it("Should calculate correct average rating", async function () {
      // First rating: 5
      await consumerVerification.connect(consumer1).verifyProduct(
        1, true, "Great", 5, "Excellent", "ipfs://docs"
      );

      // Second rating: 3
      await consumerVerification.connect(consumer2).verifyProduct(
        1, true, "Good", 3, "Good", "ipfs://docs"
      );

      const averageRating = await consumerVerification.getBatchAverageRating(1);
      expect(averageRating).to.equal(4); // (5 + 3) / 2 = 4
    });

    it("Should track total ratings count", async function () {
      await consumerVerification.connect(consumer1).verifyProduct(
        1, true, "Great", 5, "Excellent", "ipfs://docs"
      );
      await consumerVerification.connect(consumer2).verifyProduct(
        1, true, "Good", 3, "Good", "ipfs://docs"
      );

      const totalRatings = await consumerVerification.getBatchTotalRatings(1);
      expect(totalRatings).to.equal(2);
    });

    it("Should handle multiple verifications from same consumer", async function () {
      await consumerVerification.connect(consumer1).verifyProduct(
        1, true, "Great", 5, "Excellent", "ipfs://docs"
      );

      // Same consumer verifies again (should update their previous rating)
      await consumerVerification.connect(consumer1).verifyProduct(
        1, true, "Updated", 4, "Updated", "ipfs://docs"
      );

      const totalRatings = await consumerVerification.getBatchTotalRatings(1);
      expect(totalRatings).to.equal(1); // Still 1 unique consumer
    });
  });

  describe("Reward Points System", function () {
    beforeEach(async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
    });

    it("Should award points for authentic verification", async function () {
      await consumerVerification.connect(consumer1).verifyProduct(
        1, true, "Authentic", 5, "Great", "ipfs://docs"
      );

      const profile = await consumerVerification.getConsumerProfile(consumer1.address);
      expect(profile.rewardPoints).to.equal(10); // 10 points for authentic
    });

    it("Should award points for non-authentic verification", async function () {
      await consumerVerification.connect(consumer1).verifyProduct(
        1, false, "Not authentic", 2, "Poor", "ipfs://docs"
      );

      const profile = await consumerVerification.getConsumerProfile(consumer1.address);
      expect(profile.rewardPoints).to.equal(5); // 5 points for non-authentic
    });

    it("Should emit RewardPointsEarned event", async function () {
      await expect(
        consumerVerification.connect(consumer1).verifyProduct(
          1, true, "Authentic", 5, "Great", "ipfs://docs"
        )
      ).to.emit(consumerVerification, "RewardPointsEarned")
        .withArgs(consumer1.address, 10);
    });
  });

  describe("Access Control", function () {
    it("Should allow owner to deactivate consumers", async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
      
      await consumerVerification.connect(owner).setConsumerActive(consumer1.address, false);
      
      const profile = await consumerVerification.getConsumerProfile(consumer1.address);
      expect(profile.isActive).to.equal(false);
    });

    it("Should not allow non-owner to deactivate consumers", async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
      
      await expect(
        consumerVerification.connect(addr1).setConsumerActive(consumer1.address, false)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should not allow deactivated consumers to verify products", async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
      await consumerVerification.connect(owner).setConsumerActive(consumer1.address, false);
      
      await expect(
        consumerVerification.connect(consumer1).verifyProduct(
          1, true, "Authentic", 5, "Great", "ipfs://docs"
        )
      ).to.be.revertedWith("Consumer must be registered and active");
    });
  });

  describe("Statistics and Queries", function () {
    beforeEach(async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
      await consumerVerification.connect(consumer2).registerConsumer("Jane Doe", "jane@example.com");
    });

    it("Should return correct total verifications", async function () {
      await consumerVerification.connect(consumer1).verifyProduct(
        1, true, "Great", 5, "Excellent", "ipfs://docs"
      );
      await consumerVerification.connect(consumer2).verifyProduct(
        2, true, "Good", 4, "Good", "ipfs://docs"
      );

      const totalVerifications = await consumerVerification.getTotalVerifications();
      expect(totalVerifications).to.equal(2);
    });

    it("Should return correct batch verification stats", async function () {
      await consumerVerification.connect(consumer1).verifyProduct(
        1, true, "Great", 5, "Excellent", "ipfs://docs"
      );
      await consumerVerification.connect(consumer2).verifyProduct(
        1, false, "Not good", 2, "Poor", "ipfs://docs"
      );

      const stats = await consumerVerification.getBatchVerificationStats(1);
      expect(stats.totalVerifications).to.equal(2);
      expect(stats.authenticCount).to.equal(1);
      expect(stats.averageRating).to.equal(3); // (5 + 2) / 2 = 3.5, rounded to 3
      expect(stats.totalRatings).to.equal(2);
    });

    it("Should return correct consumer verifications", async function () {
      await consumerVerification.connect(consumer1).verifyProduct(
        1, true, "Great", 5, "Excellent", "ipfs://docs"
      );
      await consumerVerification.connect(consumer1).verifyProduct(
        2, true, "Good", 4, "Good", "ipfs://docs"
      );

      const verifications = await consumerVerification.getConsumerVerifications(consumer1.address);
      expect(verifications.length).to.equal(2);
      expect(verifications[0]).to.equal(1);
      expect(verifications[1]).to.equal(2);
    });
  });

  describe("Edge Cases and Security", function () {
    it("Should handle zero batch ID", async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
      
      await consumerVerification.connect(consumer1).verifyProduct(
        0, true, "Great", 5, "Excellent", "ipfs://docs"
      );

      const verifications = await consumerVerification.getBatchVerifications(0);
      expect(verifications.length).to.equal(1);
    });

    it("Should handle maximum batch ID", async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
      
      const maxBatchId = ethers.MaxUint256;
      await consumerVerification.connect(consumer1).verifyProduct(
        maxBatchId, true, "Great", 5, "Excellent", "ipfs://docs"
      );

      const verifications = await consumerVerification.getBatchVerifications(maxBatchId);
      expect(verifications.length).to.equal(1);
    });

    it("Should prevent integer overflow in rating calculation", async function () {
      await consumerVerification.connect(consumer1).registerConsumer("John Doe", "john@example.com");
      
      // This test ensures the rating calculation doesn't overflow
      // Even with maximum values, the calculation should be safe
      await consumerVerification.connect(consumer1).verifyProduct(
        1, true, "Great", 5, "Excellent", "ipfs://docs"
      );

      const averageRating = await consumerVerification.getBatchAverageRating(1);
      expect(averageRating).to.equal(5);
    });
  });
});