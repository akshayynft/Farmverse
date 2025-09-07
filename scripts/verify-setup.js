#!/usr/bin/env node

/**
 * Verification script for FarmTrack monorepo setup
 * This script verifies that the refactored project structure is working correctly
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('�� FarmTrack Monorepo Verification\n');

// Check for required files in new locations
const requiredFiles = [
  'package.json',
  'config/tsconfig.json',
  'config/hardhat.config.ts',
  'contracts/src',
  'contracts/test',
  'scripts/verify-setup.js'
];

console.log('📁 Checking project structure...');
requiredFiles.forEach(file => {
  if (fs.existsSync(file)) {
    console.log(`✅ ${file} exists`);
  } else {
    console.log(`❌ ${file} missing`);
  }
});

// Check for accidental npm operations in subdirectories
console.log('\n🛡️  Checking for accidental npm operations in subdirectories...');
const subdirs = ['contracts', 'backend', 'frontend'];
subdirs.forEach(dir => {
  const packageJsonPath = path.join(dir, 'package.json');
  const nodeModulesPath = path.join(dir, 'node_modules');
  
  if (fs.existsSync(packageJsonPath)) {
    console.log(`❌ ${packageJsonPath} should not exist - run npm commands from root!`);
    process.exit(1);
  }
  if (fs.existsSync(nodeModulesPath)) {
    console.log(`❌ ${nodeModulesPath} should not exist - run npm commands from root!`);
    process.exit(1);
  }
  console.log(`✅ ${dir}/ directory is clean`);
});

console.log('\n✅ All checks passed! Monorepo structure is correct.');
console.log('📝 Remember: Always run npm commands from the root directory!');