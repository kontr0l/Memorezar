# CLAUDE.md - AI Assistant Guidelines for Memorezar

This document provides essential context and guidelines for AI assistants working with the Memorezar codebase.

## Project Overview

**Repository:** Memorezar
**Status:** Initial Development
**Primary Branch:** `main` (or as specified)

Memorezar is a project under active development. This document will be updated as the codebase evolves.

---

## Repository Structure

```
Memorezar/
├── CLAUDE.md           # This file - AI assistant guidelines
├── README.md           # Project documentation (to be added)
├── src/                # Source code (to be added)
├── tests/              # Test files (to be added)
├── docs/               # Documentation (to be added)
└── .github/            # GitHub workflows and templates (to be added)
```

> **Note:** This structure will be updated as the project develops.

---

## Development Environment

### Prerequisites

- Git
- (Additional requirements will be documented as the project develops)

### Setup Instructions

```bash
# Clone the repository
git clone <repository-url>
cd Memorezar

# Additional setup steps will be added
```

---

## Code Conventions

### General Guidelines

1. **Code Style**
   - Follow consistent formatting across all files
   - Use meaningful variable and function names
   - Keep functions focused and single-purpose
   - Add comments for complex logic only (code should be self-documenting)

2. **File Organization**
   - Group related functionality together
   - Use clear, descriptive file names
   - Maintain a flat structure where possible

3. **Documentation**
   - Update this CLAUDE.md when adding new patterns or conventions
   - Document public APIs and interfaces
   - Keep README.md current with setup instructions

### Commit Messages

Follow conventional commit format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

---

## Working with This Repository

### For AI Assistants

When working on this codebase:

1. **Before Making Changes**
   - Read relevant files to understand existing patterns
   - Check for existing solutions before creating new ones
   - Review recent commits to understand ongoing work

2. **Making Changes**
   - Follow existing code conventions and patterns
   - Keep changes focused and minimal
   - Avoid over-engineering solutions
   - Don't add unnecessary features or abstractions

3. **Testing**
   - Run existing tests before and after changes
   - Add tests for new functionality
   - Ensure no regressions are introduced

4. **Git Workflow**
   - Create feature branches from the main branch
   - Use descriptive branch names: `feature/`, `fix/`, `docs/`
   - Write clear commit messages
   - Keep commits atomic and focused

### Branch Naming

```
feature/<description>    # New features
fix/<description>        # Bug fixes
docs/<description>       # Documentation updates
refactor/<description>   # Code refactoring
test/<description>       # Test additions/updates
```

---

## Commands Reference

### Common Commands

```bash
# Git operations
git status                    # Check current status
git branch -a                 # List all branches
git log --oneline -10         # View recent commits

# (Project-specific commands will be added)
```

---

## Architecture Guidelines

### Design Principles

1. **Simplicity First**
   - Prefer simple, readable code over clever solutions
   - Only abstract when there's clear repetition

2. **Single Responsibility**
   - Each module/function should do one thing well
   - Avoid mixing concerns

3. **Explicit Over Implicit**
   - Make dependencies and behavior clear
   - Avoid hidden side effects

---

## Troubleshooting

### Common Issues

*(This section will be populated as common issues are identified)*

---

## Project-Specific Notes

### Key Files

*(Important files will be documented as the project develops)*

### Important Patterns

*(Design patterns and conventions specific to this project will be documented here)*

### Known Limitations

*(Current limitations and workarounds will be documented here)*

---

## Updating This Document

This CLAUDE.md should be updated when:

- New technologies or dependencies are added
- Code conventions change
- New patterns or architectural decisions are made
- Common issues and solutions are identified
- Project structure changes significantly

Keep this document concise and actionable. Focus on information that helps AI assistants work effectively with the codebase.

---

*Last Updated: January 2026*
