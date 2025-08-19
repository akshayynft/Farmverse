#!/bin/bash

# Farmaverse Git Setup Script

echo "🌾 Setting up Git repository for Farmaverse..."

# Initialize git repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Farmaverse project foundation

- Project structure and monorepo setup
- Updated whitepaper (Markdown and DOCX)
- Installation guide and documentation
- Technology stack and roadmap
- Smart contract and backend architecture plans

Phase 1: Core web platform for mango traceability
- Web-only interface for farmers and consumers
- Polygon blockchain integration
- QR code generation and scanning system
- Farmer reputation and certification tracking"

echo "✅ Git repository initialized and first commit created!"

# Check if remote repository URL is provided
if [ -n "$1" ]; then
    echo "🔗 Adding remote repository: $1"
    git remote add origin "$1"
    echo "📤 Pushing to remote repository..."
    git push -u origin main
    echo "✅ Successfully pushed to GitHub!"
else
    echo "📝 To add a remote repository, run:"
    echo "   git remote add origin <your-github-repo-url>"
    echo "   git push -u origin main"
fi

echo "🎉 Farmaverse Git setup complete!" 