# 🚀 Farmaverse Installation Guide

This guide will help you set up the Farmaverse development environment for blockchain-powered farm-to-fork traceability.

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** (v18.0.0 or higher)
- **npm** (v8.0.0 or higher)
- **Git**
- **Python 3** (for whitepaper conversion)
- **PostgreSQL** (for database)
- **Redis** (for caching)

## 🛠️ Installation Steps

### 1. Clone the Repository

```bash
git clone <repository-url>
cd FarmTrack
```

### 2. Install Dependencies

```bash
# Install all dependencies for the monorepo
npm run install:all
```

This will install dependencies for:
- Root project
- Smart contracts (Solidity/Hardhat)
- Backend (Node.js/Express)
- Frontend (React.js)

### 3. Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit the environment file with your configuration
nano .env
```

### 4. Database Setup

```bash
# Create PostgreSQL database
createdb farmaverse_dev

# Run database migrations
npm run db:migrate

# Seed with sample data (optional)
npm run db:seed
```

### 5. Blockchain Setup

```bash
# Install Hardhat globally (if not already installed)
npm install -g hardhat

# Deploy smart contracts to local network
npm run deploy:contracts
```

### 6. Start Development Servers

```bash
# Start all development servers
npm run dev
```

This will start:
- Backend API server (port 3001)
- Frontend web application (port 3000)
- Hardhat local blockchain (port 8545)

## 📁 Project Structure

```
FarmTrack/
├── contracts/          # Smart contracts (Solidity)
│   ├── src/           # Contract source files
│   ├── test/          # Contract tests
│   └── hardhat.config.js
├── backend/           # Node.js API server
│   ├── src/           # Source code
│   ├── prisma/        # Database schema
│   └── package.json
├── frontend/          # React.js web application
│   ├── src/           # Source code
│   ├── public/        # Static assets
│   └── package.json
├── docs/              # Documentation
│   ├── FARMAVERSE_WHITEPAPER.md
│   ├── FARMAVERSE_WHITEPAPER.docx
│   └── api.md
├── scripts/           # Utility scripts
└── tests/             # Integration tests
```

## 🔧 Development Commands

### Smart Contracts
```bash
# Compile contracts
cd contracts && npm run compile

# Run tests
npm run test:contracts

# Deploy to local network
npm run deploy:contracts

# Deploy to testnet
npm run deploy:testnet
```

### Backend
```bash
# Start development server
cd backend && npm run dev

# Run tests
npm run test:backend

# Database operations
npm run db:migrate
npm run db:seed
npm run db:reset
```

### Frontend
```bash
# Start development server
cd frontend && npm start

# Build for production
npm run build

# Run tests
npm run test:frontend
```

### All Services
```bash
# Start all services
npm run dev

# Run all tests
npm test

# Build all projects
npm run build

# Lint all code
npm run lint
```

## 🌐 Access Points

After starting the development servers:

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:3001
- **API Documentation**: http://localhost:3001/api/docs
- **Hardhat Console**: http://localhost:8545

## 📚 Documentation

- **Whitepaper**: `docs/FARMAVERSE_WHITEPAPER.md` (Markdown)
- **Whitepaper**: `docs/FARMAVERSE_WHITEPAPER.docx` (Word)
- **API Docs**: `docs/api.md`
- **Smart Contracts**: `docs/contracts.md`

## 🔍 Troubleshooting

### Common Issues

1. **Port already in use**
   ```bash
   # Kill process using port 3000
   lsof -ti:3000 | xargs kill -9
   ```

2. **Database connection failed**
   ```bash
   # Check PostgreSQL status
   sudo systemctl status postgresql
   
   # Start PostgreSQL
   sudo systemctl start postgresql
   ```

3. **Node modules issues**
   ```bash
   # Clear npm cache
   npm cache clean --force
   
   # Reinstall dependencies
   rm -rf node_modules package-lock.json
   npm install
   ```

4. **Smart contract deployment failed**
   ```bash
   # Check Hardhat network
   npx hardhat node
   
   # Reset local network
   npx hardhat clean
   ```

### Getting Help

- Check the [README.md](README.md) for project overview
- Review [docs/](docs/) for detailed documentation
- Open an issue on GitHub for bugs
- Contact the development team for support

## 🚀 Next Steps

After successful installation:

1. **Explore the Codebase**: Familiarize yourself with the project structure
2. **Run Tests**: Ensure everything is working correctly
3. **Read Documentation**: Understand the architecture and features
4. **Start Developing**: Begin with Phase 1 tasks from the roadmap

## 📞 Support

For technical support or questions:
- Create an issue on GitHub
- Contact: support@farmaverse.com
- Join our Discord: [Farmaverse Community](https://discord.gg/farmaverse)

---

**Happy coding! 🌾✨** 