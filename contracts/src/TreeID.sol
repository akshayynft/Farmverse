// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TreeID
 * @dev Smart contract for managing unique tree identifiers in Farmaverse
 * Each tree or group of trees gets a unique TreeID for traceability
 */
contract TreeID is Ownable {
    // Counter for generating unique TreeIDs
    uint256 private _treeIdCounter;
    
    // Structure to store tree information
    struct Tree {
        uint256 treeId;
        address farmer;
        string location;
        string cropType;
        uint256 plantingDate;
        bool isActive;
        uint256 reputation;
        string ipfsHash; // For storing additional data
    }
    
    // Mapping from TreeID to Tree struct
    mapping(uint256 => Tree) public trees;
    
    // Mapping from farmer address to their tree IDs
    mapping(address => uint256[]) public farmerTrees;
    
    // Events
    event TreeRegistered(uint256 indexed treeId, address indexed farmer, string cropType);
    event TreeUpdated(uint256 indexed treeId, string ipfsHash);
    event ReputationUpdated(uint256 indexed treeId, uint256 newReputation);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Register a new tree or group of trees
     * @param location Geographic location of the tree(s)
     * @param cropType Type of crop (e.g., "Mango", "Banana")
     * @param plantingDate Timestamp of planting
     * @param ipfsHash IPFS hash for additional metadata
     */
    function registerTree(
        string memory location,
        string memory cropType,
        uint256 plantingDate,
        string memory ipfsHash
    ) external returns (uint256) {
        require(bytes(location).length > 0, "Location cannot be empty");
        require(bytes(cropType).length > 0, "Crop type cannot be empty");
        require(plantingDate <= block.timestamp, "Planting date cannot be in future");
        
        _treeIdCounter++;
        uint256 newTreeId = _treeIdCounter;
        
        Tree memory newTree = Tree({
            treeId: newTreeId,
            farmer: msg.sender,
            location: location,
            cropType: cropType,
            plantingDate: plantingDate,
            isActive: true,
            reputation: 0,
            ipfsHash: ipfsHash
        });
        
        trees[newTreeId] = newTree;
        farmerTrees[msg.sender].push(newTreeId);
        
        emit TreeRegistered(newTreeId, msg.sender, cropType);
        
        return newTreeId;
    }
    
    /**
     * @dev Update tree information
     * @param treeId The TreeID to update
     * @param ipfsHash New IPFS hash for updated metadata
     */
    function updateTree(uint256 treeId, string memory ipfsHash) external {
        require(trees[treeId].farmer == msg.sender, "Only tree owner can update");
        require(trees[treeId].isActive, "Tree must be active");
        
        trees[treeId].ipfsHash = ipfsHash;
        
        emit TreeUpdated(treeId, ipfsHash);
    }
    
    /**
     * @dev Update tree reputation (only owner can call)
     * @param treeId The TreeID to update
     * @param newReputation New reputation score
     */
    function updateReputation(uint256 treeId, uint256 newReputation) external onlyOwner {
        require(trees[treeId].isActive, "Tree must be active");
        require(newReputation <= 100, "Reputation cannot exceed 100");
        
        trees[treeId].reputation = newReputation;
        
        emit ReputationUpdated(treeId, newReputation);
    }
    
    /**
     * @dev Deactivate a tree
     * @param treeId The TreeID to deactivate
     */
    function deactivateTree(uint256 treeId) external {
        require(trees[treeId].farmer == msg.sender, "Only tree owner can deactivate");
        require(trees[treeId].isActive, "Tree is already inactive");
        
        trees[treeId].isActive = false;
    }
    
    /**
     * @dev Get tree information
     * @param treeId The TreeID to query
     * @return Tree struct with all information
     */
    function getTree(uint256 treeId) external view returns (Tree memory) {
        require(trees[treeId].treeId != 0, "Tree does not exist");
        return trees[treeId];
    }
    
    /**
     * @dev Get all trees for a farmer
     * @param farmer Address of the farmer
     * @return Array of TreeIDs owned by the farmer
     */
    function getFarmerTrees(address farmer) external view returns (uint256[] memory) {
        return farmerTrees[farmer];
    }
    
    /**
     * @dev Get total number of trees registered
     * @return Total count of trees
     */
    function getTotalTrees() external view returns (uint256) {
        return _treeIdCounter;
    }
    
    /**
     * @dev Check if a tree exists and is active
     * @param treeId The TreeID to check
     * @return True if tree exists and is active
     */
    function isTreeActive(uint256 treeId) external view returns (bool) {
        return trees[treeId].treeId != 0 && trees[treeId].isActive;
    }
} 