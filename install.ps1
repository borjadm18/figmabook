$SkillsDir = "$env:USERPROFILE\.claude\skills"
# Pin to a release tag (e.g. "v1.0.0") for stability, or keep "main" for the latest.
# Breaking changes in main deploy immediately to all installs.
$Version  = if ($env:FIGMABOOK_VERSION) { $env:FIGMABOOK_VERSION } else { "main" }
$RepoRaw  = "https://raw.githubusercontent.com/borjadm18/figmabook/$Version/skills"

$Skills = @(
  "figma-to-storybook",
  "figma-extract",
  "figma-tokens",
  "figma-component",
  "figma-behaviour",
  "figma-pages",
  "figma-verify"
)

Write-Host "Installing figma-to-storybook skills to $SkillsDir..."
New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null

foreach ($skill in $Skills) {
  Write-Host "  -> $skill"
  Invoke-WebRequest -Uri "$RepoRaw/$skill.md" -OutFile "$SkillsDir\$skill.md"
}

Write-Host ""
Write-Host "Done! Run /figma-to-storybook in any Claude Code project to start a migration."
