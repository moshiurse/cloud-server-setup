# ============================================
# .dockerignore for PHP / Laravel Projects
# ============================================
# Prevents unnecessary files from being sent to the Docker build context
# Copy this to your project root as .dockerignore

# Dependencies (installed inside container)
vendor

# Environment files (use Docker env vars instead)
.env
.env.*
!.env.example

# Storage (mounted as volume in production)
storage/logs/*
storage/framework/cache/*
storage/framework/sessions/*
storage/framework/views/*
storage/app/public/*
bootstrap/cache/*

# Version control
.git
.gitignore
.gitattributes

# IDE / Editor
.vscode
.idea
.phpstorm.meta.php
_ide_helper.php
_ide_helper_models.php
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Testing
tests
phpunit.xml
.phpunit.result.cache
coverage

# CI/CD
.github
.gitlab-ci.yml

# Docker (avoid recursive copy)
Dockerfile*
docker-compose*
.dockerignore

# Documentation
*.md
LICENSE
docs

# Frontend build tools (if using Mix/Vite, built inside container)
node_modules
npm-debug.log*

# Misc
*.log
