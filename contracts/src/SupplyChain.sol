// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title SupplyChain
 * @dev Smart contract for managing the complete supply chain from farm to consumer
 * Links TreeID, Certification, and Harvest data for complete traceability
 * Generates QR codes and manages ownership transfers
 */
contract SupplyChain is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    // Counter for product batch IDs
    Counters.Counter private _batchIdCounter;
    
    // Structure for product batch
    struct ProductBatch {
        uint256 batchId;
        uint256[] harvestIds; // Multiple harvests can be combined
        address farmer;
        uint256 creationDate;
        uint256 quantity; // Total quantity in grams
        string batchCode; // Human-readable batch code
        string qrCodeHash; // IPFS hash for QR code
        bool isActive;
        uint256 currentOwner; // Index in ownership chain
    }
    
    // Structure for ownership transfer
    struct OwnershipTransfer {
        uint256 batchId;
        address from;
        address to;
        uint256 transferDate;
        string transferType; // "Farmer", "Distributor", "Retailer", "Consumer"
        string location; // Transfer location
        string ipfsHash; // Transfer documents
        uint256 temperature; // Storage temperature
        uint256 humidity; // Storage humidity
        string transportMethod; // "Refrigerated", "Ambient", "Express"
    }
    
    // Structure for supply chain node
    struct SupplyChainNode {
        address nodeAddress;
        string nodeType; // "Farmer", "Distributor", "Retailer", "Consumer"
        string nodeName;
        string location;
        bool isVerified;
        uint256 verificationDate;
    }
    
    // Mappings
    mapping(uint256 => ProductBatch) public productBatches;
    mapping(uint256 => OwnershipTransfer[]) public batchTransfers; // batchId to transfers
    mapping(address => uint256[]) public nodeBatches; // node address to batch IDs
    mapping(address => SupplyChainNode) public supplyChainNodes;
    mapping(string => uint256) public qrCodeToBatch; // QR code hash to batch ID
    mapping(address => bool) public authorizedDistributors;
    mapping(address => bool) public authorizedRetailers;
    
    // Events
    event ProductBatchCreated(uint256 indexed batchId, address indexed farmer, uint256 quantity);
    event OwnershipTransferred(uint256 indexed batchId, address indexed from, address indexed to, string transferType);
    event SupplyChainNodeRegistered(address indexed nodeAddress, string nodeType);
    event QRCodeGenerated(uint256 indexed batchId, string qrCodeHash);
    event BatchVerified(uint256 indexed batchId, bool verified);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Create a new product batch from harvests
     * @param harvestIds Array of harvest IDs to combine
     * @param batchCode Human-readable batch code
     * @param qrCodeHash IPFS hash for QR code
     */
    function createProductBatch(
        uint256[] memory harvestIds,
        string memory batchCode,
        string memory qrCodeHash
    ) external nonReentrant returns (uint256) {
        require(harvestIds.length > 0, "Must include at least one harvest");
        require(bytes(batchCode).length > 0, "Batch code cannot be empty");
        require(bytes(qrCodeHash).length > 0, "QR code hash cannot be empty");
        
        _batchIdCounter.increment();
        uint256 newBatchId = _batchIdCounter.current();
        
        // Calculate total quantity from harvests
        uint256 totalQuantity = 0;
        for (uint256 i = 0; i < harvestIds.length; i++) {
            // Get actual harvest quantity from Harvest contract
            // Note: This requires Harvest contract to be deployed and accessible
            // For now, we'll use a placeholder until contracts are deployed
            totalQuantity += 1000; // Placeholder: 1kg per harvest
            // TODO: Replace with: totalQuantity += harvestContract.getHarvest(harvestIds[i]).quantity;
        }
        
        // Note: Waste will be tracked separately in WasteManagement contract
        // This quantity represents the initial harvest quantity before any waste
        
        ProductBatch memory newBatch = ProductBatch({
            batchId: newBatchId,
            harvestIds: harvestIds,
            farmer: msg.sender,
            creationDate: block.timestamp,
            quantity: totalQuantity,
            batchCode: batchCode,
            qrCodeHash: qrCodeHash,
            isActive: true,
            currentOwner: 0
        });
        
        productBatches[newBatchId] = newBatch;
        nodeBatches[msg.sender].push(newBatchId);
        qrCodeToBatch[qrCodeHash] = newBatchId;
        
        // Create initial ownership transfer
        OwnershipTransfer memory initialTransfer = OwnershipTransfer({
            batchId: newBatchId,
            from: address(0),
            to: msg.sender,
            transferDate: block.timestamp,
            transferType: "Farmer",
            location: "Farm",
            ipfsHash: "",
            temperature: 25, // Default temperature
            humidity: 60, // Default humidity
            transportMethod: "None"
        });
        
        batchTransfers[newBatchId].push(initialTransfer);
        
        emit ProductBatchCreated(newBatchId, msg.sender, totalQuantity);
        emit QRCodeGenerated(newBatchId, qrCodeHash);
        
        return newBatchId;
    }
    
    /**
     * @dev Transfer ownership of a product batch
     * @param batchId The batch ID to transfer
     * @param to Recipient address
     * @param transferType Type of transfer
     * @param location Transfer location
     * @param ipfsHash Transfer documents
     * @param temperature Storage temperature
     * @param humidity Storage humidity
     * @param transportMethod Transport method used
     */
    function transferOwnership(
        uint256 batchId,
        address to,
        string memory transferType,
        string memory location,
        string memory ipfsHash,
        uint256 temperature,
        uint256 humidity,
        string memory transportMethod
    ) external nonReentrant {
        require(productBatches[batchId].isActive, "Batch must be active");
        require(productBatches[batchId].farmer == msg.sender || 
                isAuthorizedNode(msg.sender, transferType), "Not authorized to transfer");
        require(to != address(0), "Cannot transfer to zero address");
        require(bytes(transferType).length > 0, "Transfer type cannot be empty");
        
        OwnershipTransfer memory transfer = OwnershipTransfer({
            batchId: batchId,
            from: msg.sender,
            to: to,
            transferDate: block.timestamp,
            transferType: transferType,
            location: location,
            ipfsHash: ipfsHash,
            temperature: temperature,
            humidity: humidity,
            transportMethod: transportMethod
        });
        
        batchTransfers[batchId].push(transfer);
        productBatches[batchId].currentOwner = batchTransfers[batchId].length - 1;
        
        // Update node batches
        nodeBatches[to].push(batchId);
        
        emit OwnershipTransferred(batchId, msg.sender, to, transferType);
    }
    
    /**
     * @dev Register a supply chain node (distributor, retailer, etc.)
     * @param nodeType Type of node
     * @param nodeName Name of the organization
     * @param location Physical location
     */
    function registerSupplyChainNode(
        string memory nodeType,
        string memory nodeName,
        string memory location
    ) external {
        require(bytes(nodeType).length > 0, "Node type cannot be empty");
        require(bytes(nodeName).length > 0, "Node name cannot be empty");
        require(bytes(location).length > 0, "Location cannot be empty");
        
        SupplyChainNode memory node = SupplyChainNode({
            nodeAddress: msg.sender,
            nodeType: nodeType,
            nodeName: nodeName,
            location: location,
            isVerified: false,
            verificationDate: 0
        });
        
        supplyChainNodes[msg.sender] = node;
        
        emit SupplyChainNodeRegistered(msg.sender, nodeType);
    }
    
    /**
     * @dev Verify a supply chain node (only owner)
     * @param nodeAddress Address of the node to verify
     * @param verified Whether to verify or revoke verification
     */
    function verifySupplyChainNode(address nodeAddress, bool verified) external onlyOwner {
        require(supplyChainNodes[nodeAddress].nodeAddress != address(0), "Node does not exist");
        
        supplyChainNodes[nodeAddress].isVerified = verified;
        supplyChainNodes[nodeAddress].verificationDate = verified ? block.timestamp : 0;
    }
    
    /**
     * @dev Get complete traceability data for a batch
     * @param batchId The batch ID
     * @return batch Product batch data
     * @return transfers Array of ownership transfers
     */
    function getBatchTraceability(uint256 batchId) external view returns (
        ProductBatch memory batch,
        OwnershipTransfer[] memory transfers
    ) {
        require(productBatches[batchId].batchId != 0, "Batch does not exist");
        
        batch = productBatches[batchId];
        transfers = batchTransfers[batchId];
    }
    
    /**
     * @dev Get batch by QR code hash
     * @param qrCodeHash The QR code hash
     * @return batchId The corresponding batch ID
     */
    function getBatchByQRCode(string memory qrCodeHash) external view returns (uint256) {
        uint256 batchId = qrCodeToBatch[qrCodeHash];
        require(batchId != 0, "QR code not found");
        return batchId;
    }
    
    /**
     * @dev Get all batches for a node
     * @param nodeAddress Address of the node
     * @return Array of batch IDs
     */
    function getNodeBatches(address nodeAddress) external view returns (uint256[] memory) {
        return nodeBatches[nodeAddress];
    }
    
    /**
     * @dev Check if a node is authorized for a transfer type
     * @param nodeAddress Address to check
     * @param transferType Type of transfer
     * @return True if authorized
     */
    function isAuthorizedNode(address nodeAddress, string memory transferType) internal view returns (bool) {
        if (keccak256(bytes(transferType)) == keccak256(bytes("Distributor"))) {
            return authorizedDistributors[nodeAddress];
        } else if (keccak256(bytes(transferType)) == keccak256(bytes("Retailer"))) {
            return authorizedRetailers[nodeAddress];
        }
        return false;
    }
    
    /**
     * @dev Authorize a distributor (only owner)
     * @param distributorAddress Address of the distributor
     * @param authorized Whether to authorize or revoke
     */
    function authorizeDistributor(address distributorAddress, bool authorized) external onlyOwner {
        authorizedDistributors[distributorAddress] = authorized;
    }
    
    /**
     * @dev Authorize a retailer (only owner)
     * @param retailerAddress Address of the retailer
     * @param authorized Whether to authorize or revoke
     */
    function authorizeRetailer(address retailerAddress, bool authorized) external onlyOwner {
        authorizedRetailers[retailerAddress] = authorized;
    }
    
    /**
     * @dev Get current owner of a batch
     * @param batchId The batch ID
     * @return Current owner address
     */
    function getCurrentOwner(uint256 batchId) external view returns (address) {
        require(productBatches[batchId].batchId != 0, "Batch does not exist");
        require(batchTransfers[batchId].length > 0, "No transfers found");
        
        uint256 currentOwnerIndex = productBatches[batchId].currentOwner;
        return batchTransfers[batchId][currentOwnerIndex].to;
    }
    
    /**
     * @dev Check if batch is still in supply chain
     * @param batchId The batch ID
     * @return True if batch is active
     */
    function isBatchActive(uint256 batchId) external view returns (bool) {
        return productBatches[batchId].isActive;
    }
    
    /**
     * @dev Get total number of batches
     * @return Total count of batches
     */
    function getTotalBatches() external view returns (uint256) {
        return _batchIdCounter.current();
    }
}
