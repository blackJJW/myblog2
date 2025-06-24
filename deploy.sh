#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

msg="rebuilding site $(date)"
if [ $# -eq 1 ]; then
  msg="$1"
fi

# Build the project.
hugo

# Deploy public/
cd public
git add .
git commit -m "$msg"
git push origin main
cd ..

# Commit source blog (theme, content, config, etc.)
git add .
git commit -m "$msg"
git push origin main