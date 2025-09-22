    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.24;

    import "@openzeppelin/contracts/access/Ownable.sol";

    /**
    * @title TreeID
    * @dev Smart contract for managing unique tree identifiers in Farmaverse
    * Each tree or group of trees gets a unique TreeID for traceability
    */
    contract TreeID is Ownable {
        // Contract metadata
        string public constant name = "Farmaverse Tree ID";
        string public constant symbol = "TREE";
        
        // Counter for generating unique TreeIDs
        uint256 private _treeIdCounter;
        
        // Structure to store tree information
        struct Tree {
            uint256 treeId;
            address farmerAddress;
            string location;
            string variety;
            uint256 plantingDate;
            uint256 expectedHarvestDate;
            bool organicCertified;
            string irrigationType;
            string soilType;
            string coordinates;
            bool isActive;
            uint256 reputation;
            string ipfsHash; // For storing additional data
        }
        
        // Mapping from farmer address to tree index to Tree struct
        mapping(address => mapping(uint256 => Tree)) public farmerTrees;
        
        // Mapping from farmer address to their tree count
        mapping(address => uint256) public farmerTreeCount;
        
        // Mapping from treeId to Tree struct for direct lookup
        mapping(uint256 => Tree) public treesById;
        
        // Mapping from treeId to farmer address for quick lookup
        mapping(uint256 => address) public treeIdToFarmer;
        
        // Events
        event TreeRegistered(address indexed farmer, uint256 indexed treeIndex, string variety, string location);
        event TreeUpdated(address indexed farmer, uint256 indexed treeIndex, string field, string value);
        event ReputationUpdated(uint256 indexed treeId, uint256 newReputation);
        
        constructor() Ownable(msg.sender) {}
        
        /**
        * @dev Register a new tree or group of trees
        * @param treeData Complete tree data structure
        */
        function registerTree(Tree memory treeData) external returns (uint256) {
            require(bytes(treeData.location).length > 0, "Location cannot be empty");
            require(bytes(treeData.variety).length > 0, "Variety cannot be empty");
            require(treeData.plantingDate <= block.timestamp, "Planting date cannot be in future");
            require(treeData.farmerAddress == msg.sender, "Farmer address must match sender");
            
            _treeIdCounter++;                           // Increment counter (1, 2, 3...)
            uint256 newTreeId = _treeIdCounter;         // Get new unique ID
            uint256 treeIndex = farmerTreeCount[msg.sender]; // Get farmer's next tree slot

            treeData.treeId = newTreeId;                // Assign the unique ID
            treeData.isActive = true;                   // Mark tree as active
            treeData.reputation = 0;                    // Start with 0 reputation

            farmerTrees[msg.sender][treeIndex] = treeData;  // Store in farmer's list
            farmerTreeCount[msg.sender]++;              // Increase farmer's tree count

            treesById[newTreeId] = treeData;            // Store for direct lookup
            treeIdToFarmer[newTreeId] = msg.sender;     // Record ownership
            
            emit TreeRegistered(msg.sender, treeIndex, treeData.variety, treeData.location);
            
            return newTreeId;
        }
        
        /**
        * @dev Update tree location
        * @param treeIndex The tree index to update
        * @param newLocation New location
        */
    /**
    * @notice Updates the location of a specific tree owned by the caller (farmer)
    * @param treeIndex The index of the tree in the farmer's personal tree list
    * @param newLocation The new location string to assign to the tree
    */
        function updateTreeLocation(uint256 treeIndex, string memory newLocation) external {
            // Ensure the tree at the given index exists and is active
            require(farmerTrees[msg.sender][treeIndex].isActive, "Tree does not exist");

            // Ensure the new location string is not empty
            require(bytes(newLocation).length > 0, "Location cannot be empty");

            // Retrieve the unique tree ID from the farmer's tree list
            uint256 treeId = farmerTrees[msg.sender][treeIndex].treeId;

            // Update the location in the farmer's personal tree mapping
            farmerTrees[msg.sender][treeIndex].location = newLocation;

            // Update the location in the global tree registry (by tree ID)
            treesById[treeId].location = newLocation;

            // Emit an event to log the location update for transparency and tracking
            emit TreeUpdated(msg.sender, treeIndex, "location", newLocation);
        }

        
        /**
        * @dev Update tree irrigation type
        * @param treeIndex The tree index to update
        * @param newIrrigationType New irrigation type
        */
        function updateIrrigationType(uint256 treeIndex, string memory newIrrigationType) external {
            require(farmerTrees[msg.sender][treeIndex].isActive, "Tree does not exist");
            require(bytes(newIrrigationType).length > 0, "Irrigation type cannot be empty");
            
            uint256 treeId = farmerTrees[msg.sender][treeIndex].treeId;
            
            farmerTrees[msg.sender][treeIndex].irrigationType = newIrrigationType;
            treesById[treeId].irrigationType = newIrrigationType;
            
            emit TreeUpdated(msg.sender, treeIndex, "irrigationType", newIrrigationType);
        }
        
        /**
        * @dev Update tree organic certification
        * @param treeIndex The tree index to update
        * @param organicCertified New organic certification status
        */
        function updateOrganicCertification(uint256 treeIndex, bool organicCertified) external {
            require(farmerTrees[msg.sender][treeIndex].isActive, "Tree does not exist");
            
            uint256 treeId = farmerTrees[msg.sender][treeIndex].treeId;
            
            farmerTrees[msg.sender][treeIndex].organicCertified = organicCertified;
            treesById[treeId].organicCertified = organicCertified;
            
            emit TreeUpdated(msg.sender, treeIndex, "organicCertified", organicCertified ? "true" : "false");
        }
        
        /**
        * @dev Update tree reputation (only owner can call)
        * @param treeId The TreeID to update
        * @param newReputation New reputation score
        */
        function updateReputation(uint256 treeId, uint256 newReputation) external onlyOwner {
            require(newReputation <= 100, "Reputation cannot exceed 100");
            
            emit ReputationUpdated(treeId, newReputation);
        }
        
        /**
        * @dev Deactivate a tree
        * @param treeIndex The tree index to deactivate
        */
        function deactivateTree(uint256 treeIndex) external {
            require(farmerTrees[msg.sender][treeIndex].isActive, "Tree is already inactive");
            
            uint256 treeId = farmerTrees[msg.sender][treeIndex].treeId;
            
            farmerTrees[msg.sender][treeIndex].isActive = false;
            treesById[treeId].isActive = false;
        }
        
        /**
        * @dev Get tree information by farmer address and tree index
        * @param farmerAddress Address of the farmer
        * @param treeIndex Index of the tree for this farmer
        * @return Tree struct with all information
        */
        function getTree(address farmerAddress, uint256 treeIndex) external view returns (Tree memory) {
            require(farmerTrees[farmerAddress][treeIndex].isActive, "Tree does not exist");
            return farmerTrees[farmerAddress][treeIndex];
        }
        
        /**
        * @dev Get tree information by treeId (for traceability)
        * @param treeId The unique tree identifier
        * @return Tree struct with all information
        * @notice This function works for both active and deactivated trees to preserve traceability
        */
        function getTreeById(uint256 treeId) external view returns (Tree memory) {
            require(treesById[treeId].treeId != 0, "Tree does not exist");
            return treesById[treeId];
        }
        
        /**
        * @dev Check if a tree is active by treeId
        * @param treeId The unique tree identifier
        * @return True if tree exists and is active
        */
        function isTreeActiveById(uint256 treeId) external view returns (bool) {
            return treesById[treeId].treeId != 0 && treesById[treeId].isActive;
        }
        
        /**
        * @dev Get tree count for a farmer
        * @param farmerAddress Address of the farmer
        * @return Number of trees owned by the farmer
        */
        function getTreeCount(address farmerAddress) external view returns (uint256) {
            return farmerTreeCount[farmerAddress];
        }
        
        /**
        * @dev Get all trees for a farmer
        * @param farmer Address of the farmer
        * @return Array of TreeIDs owned by the farmer
        */
        function getFarmerTrees(address farmer) external view returns (uint256[] memory) {
            uint256[] memory treeIds = new uint256[](farmerTreeCount[farmer]);
            for (uint256 i = 0; i < farmerTreeCount[farmer]; i++) {
                treeIds[i] = farmerTrees[farmer][i].treeId;
            }
            return treeIds;
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
        * @param farmerAddress Address of the farmer
        * @param treeIndex Index of the tree for this farmer
        * @return True if tree exists and is active
        */
        function isTreeActive(address farmerAddress, uint256 treeIndex) external view returns (bool) {
            return farmerTrees[farmerAddress][treeIndex].isActive;
        }
    } 