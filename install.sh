#!/usr/bin/env bash
set -e

SKILLS_DIR="$HOME/.claude/skills"
# Pin to a release tag (e.g. "v1.0.0") for stability, or keep "main" for the latest.
# Breaking changes in main deploy immediately to all installs.
VERSION="${FIGMABOOK_VERSION:-main}"
REPO_RAW="https://raw.githubusercontent.com/borjadm18/figmabook/${VERSION}/skills"

SKILLS=(
  figma-to-storybook
  figma-extract
  figma-tokens
  figma-component
  figma-behaviour
  figma-pages
  figma-verify
)

echo "Installing figma-to-storybook skills to $SKILLS_DIR..."
mkdir -p "$SKILLS_DIR"

for skill in "${SKILLS[@]}"; do
  echo "  → $skill"
  curl -fsSL "$REPO_RAW/$skill.md" -o "$SKILLS_DIR/$skill.md"
done

echo ""
echo "Done! Run /figma-to-storybook in any Claude Code project to start a migration."
