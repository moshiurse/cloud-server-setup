# ============================================
# .gitignore for PHP Projects (Raw PHP)
# ============================================
# Copy to your project root as .gitignore

# ---- Dependencies ----
vendor/

# ---- Environment variables ----
.env
.env.*
!.env.example

# ---- Logs ----
*.log
logs/

# ---- Uploads (user-generated content) ----
uploads/*
!uploads/.gitkeep
storage/*
!storage/.gitkeep

# ---- Cache ----
cache/*
!cache/.gitkeep

# ---- Sessions ----
sessions/*
!sessions/.gitkeep

# ---- OS files ----
.DS_Store
Thumbs.db

# ---- IDE ----
.vscode/
.idea/
*.swp
*.swo
*~
.phpstorm.meta.php
_ide_helper.php

# ---- Misc ----
*.sql
*.sqlite
*.bak
