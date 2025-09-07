# 🌾 Farmaverse - Blockchain-Powered Farm-to-Fork Traceability

> **Blockchain-Powered Farm-to-Fork Traceability for India's Agriculture**

## 🎯 Problem Statement

India is the world's largest producer of fruits like mangoes and bananas, but the sector faces critical challenges:

- **Carbide Ripening**: 68% of mango and banana samples contain banned calcium carbide traces
- **Excessive Pesticides**: 60% of fruits/vegetables exceed permissible pesticide limits
- **Trust Gap**: 78% of consumers are skeptical of "organic" labels due to fake certifications
- **Farmer Exploitation**: Farmers receive only 25-30% of final consumer price

## 🚀 Our Solution - Farmaverse

Farmaverse is a blockchain-powered transparency ecosystem that:
- Creates unique TreeID for each crop with verified on-chain data
- Tracks every step from soil preparation to consumer delivery
- Empowers farmers with fair pricing and reputation building
- Provides consumers with tamper-proof traceability via QR codes

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    CONSUMER INTERFACE                       │
│  Web Dashboard (React.js) - QR Scanner + Traceability      │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                    FARMER INTERFACE                         │
│  Web Dashboard (React.js) - Data Input + IoT Integration   │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                    APPLICATION LAYER                        │
│  Node.js + Express.js Backend + PostgreSQL Database        │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                    IDENTITY LAYER                           │
│  Verifiable Digital IDs for Farmers, Distributors, Certifiers│
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                  SMART CONTRACT LAYER                       │
│  Verification Logic, Certification Records, Timestamping    │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   BLOCKCHAIN LAYER                          │
│  Polygon PoS - Immutable Traceability Data                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                IoT & DATA CAPTURE LAYER                     │
│  Sensors, QR Codes, Manual Entries, Lab Certificates       │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Phase-Wise Development Plan

### Phase 1: Core Web Platform (Months 1-3)
- [x] Project setup and architecture design
- [ ] Smart contract development (TreeID, certification, verification)
- [ ] Backend API development with farmer/consumer endpoints
- [ ] Database schema design for mango traceability
- [ ] Web interface for farmers to input data
- [ ] Web interface for consumers to verify mango details

### Phase 2: Pilot with Mango Bodies (Months 4-6)
- [ ] Partner with mango associations/organizations
- [ ] Onboard 5-10 initial farmers
- [ ] QR code generation and scanning system
- [ ] Manual data input system for farmers
- [ ] Basic IoT sensor integration (optional)
- [ ] Consumer verification interface

### Phase 3: Validation & Iteration (Months 7-9)
- [ ] Collect feedback from farmers and consumers
- [ ] Improve data input workflows
- [ ] Enhance verification interface
- [ ] Add more mango varieties
- [ ] Scale to 20-30 farmers

### Phase 4: Expansion (Months 10-12)
- [ ] Add certification partner integrations
- [ ] Implement reputation scoring for farmers
- [ ] Enhanced analytics and reporting
- [ ] Scale to 50+ farmers
- [ ] Prepare for token economy (Year 2)

### Phase 5: Token Economy (Year 2)
- [ ] Farmaverse Token (ERC-20) launch
- [ ] Microfunding and incentive systems
- [ ] Marketplace features
- [ ] 100+ farmers, 1000+ consumers

### Phase 6: Full Ecosystem (Years 3-5)
- [ ] Multi-crop expansion
- [ ] E-commerce integrations
- [ ] DAO governance implementation
- [ ] Carbon credits and sustainability features

## 🛠️ Technology Stack

### Core Stack (Year 1)
- **Frontend**: React.js (web-only) + Progressive Web App
- **Backend**: Node.js + Express.js + TypeScript
- **Database**: PostgreSQL + Redis (caching)
- **Blockchain**: Polygon PoS
- **Smart Contracts**: Solidity + Hardhat
- **Storage**: IPFS/Filecoin (for certifications/images)
- **Testing**: Jest + Chai + Ganache

### Development Tools
- **Hardhat** - Smart contract development framework
- **TypeScript** - Type safety across the stack
- **Prisma** - Database ORM with migrations
- **ESLint + Prettier** - Code quality
- **Docker** - Containerization

### Infrastructure
- **Vercel/Netlify** - Frontend deployment
- **Railway/Render** - Backend hosting
- **GitHub Actions** - CI/CD
- **Sentry** - Error tracking

## 🚀 Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd FarmTrack

# Install dependencies
npm run install:all

# Set up environment variables
cp .env.example .env

# Start development servers
npm run dev
```

## 📁 Project Structure

```
FarmTrack/
├── package.json        # Root workspace configuration with all dependencies
├── tsconfig.json      # Root TypeScript configuration
├── hardhat.config.ts  # Hardhat configuration for smart contracts
├── contracts/         # Smart contracts directory
│   ├── src/          # Solidity smart contracts
│   ├── test/         # Smart contract tests
│   └── scripts/      # Deployment scripts
├── backend/           # Node.js API server (TODO: Phase 2)
├── frontend/          # React.js web application (TODO: Phase 2)
├── docs/              # Documentation
└── node_modules/      # Shared dependencies (root level)
```

### 🚀 Future Frontend Integration
<!-- 
TODO: Frontend directory will be added in Phase 2 with:
- React.js application for farmer dashboard
- Consumer QR code scanning interface
- Progressive Web App (PWA) features
- Responsive design for mobile and desktop
- Integration with smart contracts via Web3
-->

## 🎯 Key Features (Year 1)

### Farmer Interface
- **Dashboard**: Overview of all mango trees and harvests
- **Data Input**: Manual entry for farming practices, pesticides, harvest dates
- **IoT Integration**: Optional sensor data upload
- **QR Generation**: Create QR codes for mango boxes
- **Certification**: Upload lab certificates and organic certifications

### Consumer Interface
- **QR Scanner**: Scan QR codes to view mango journey
- **Traceability**: Complete farm-to-fork story
- **Verification**: Authenticate organic claims and certifications
- **Farmer Profile**: View farmer details and practices

### Core Functionality
- **TreeID System**: Unique blockchain identity for each tree/group
- **Immutable Records**: All data stored on Polygon blockchain
- **Certification Verification**: Lab results and organic certifications
- **Reputation Building**: Farmer credibility scores

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Whitepaper](docs/whitepaper.md)
- [API Documentation](docs/api.md)
- [Smart Contract Documentation](docs/contracts.md)
- [Deployment Guide](docs/deployment.md)

---

**Building trust in India's agricultural value chain, one mango at a time.** 🌾✨ 