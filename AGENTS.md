# FarmTrack Agent Guidelines

## Build/Lint/Test Commands
- `npm run test:contracts` - Run all smart contract tests
- `npm run compile:contracts` - Compile contracts
- `npm run deploy:contracts` - Deploy contracts
- `npx hardhat test contracts/test/Filename.test.ts` - Run single test file
- `npm run lint` - Run linting across all projects

## Code Style Guidelines
- **Contracts**: PascalCase naming (`TreeIDContract`, `CertificationRegistry`)
- **Functions/Variables**: camelCase (`generateTreeId`, `farmerId`)
- **Constants**: SCREAMING_SNAKE_CASE (`POLYGON_RPC_URL`)
- **Files**: kebab-case (`farmer-dashboard.tsx`)
- Use Solidity 0.8.24 with OpenZeppelin contracts
- Follow Checks-Effects-Interactions pattern
- Emit events for all state changes
- Use TypeScript strict mode, proper typing
- Never commit secrets - use environment variables
- Store large files on IPFS, only hashes on-chain

## Testing Requirements
- Unit tests: Hardhat + Chai for contracts
- Integration tests: Full traceability flow
- Security testing: Fuzzing on critical functions
- Maintain 80%+ code coverage
- Test with realistic agricultural data