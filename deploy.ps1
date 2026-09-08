<#
.SYNOPSIS
  Regenerates the Vibe Coding Copilot site and publishes it to its own
  GitHub Pages repository in one command.

.DESCRIPTION
  Since 29 August 2026 the site lives in its OWN repository
  (sebplace/vibe-coding-copilot, branch main, served from the repo root).
  It is no longer a subfolder of the personal blog repo sebplace.github.io —
  pushing there would NOT update the live site any more. The public URL
  https://sebplace.github.io/vibe-coding-copilot/ is unchanged.

  This script always copies the same full, known-good file list, runs the
  link/case checkers first and aborts on any failure, and cleans up its
  temporary clone afterwards.

.PARAMETER Message
  Git commit message. Defaults to a timestamped generic message if omitted.

.PARAMETER SkipRegenerate
  Skip the `python generate_site.py` step (use if you already regenerated
  and just want to re-run the checks + deploy).

.EXAMPLE
  .\deploy.ps1 -Message "Add feedback widget"
#>
param(
    [string]$Message = "Update Vibe Coding Copilot site ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))",
    [switch]$SkipRegenerate
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$repoUrl = "https://github.com/sebplace/vibe-coding-copilot.git"
$branch = "main"

# Files/directories copied into the repository root on every deploy. Keep this
# list in sync with what generate_site.py actually produces + the repo docs.
# deploy.ps1 itself is included so the publication tool travels with the project.
$itemsToCopy = @(
    "fr", "nl", "en", "assets",
    "index.html", "sitemap.xml", "robots.txt", "README.md",
    "generate_site.py", "site_refresh.py", "check_links.py", "check_case.py",
    "deploy.ps1"
)

function Write-Step($text) {
    Write-Host "`n==> $text" -ForegroundColor Cyan
}

Push-Location $root
try {
    if (-not $SkipRegenerate) {
        Write-Step "Regenerating site (python generate_site.py)"
        python generate_site.py
        if ($LASTEXITCODE -ne 0) { throw "generate_site.py failed (exit $LASTEXITCODE)" }
    }

    Write-Step "Checking internal links (check_links.py)"
    python check_links.py
    if ($LASTEXITCODE -ne 0) { throw "check_links.py reported broken links — aborting deploy" }

    Write-Step "Checking path case-sensitivity (check_case.py)"
    python check_case.py
    if ($LASTEXITCODE -ne 0) { throw "check_case.py reported case mismatches — aborting deploy" }

    # Refuse to publish a partial build rather than silently skipping files.
    $missing = $itemsToCopy | Where-Object { -not (Test-Path (Join-Path $root $_)) }
    if ($missing) { throw "Missing build output, aborting deploy: $($missing -join ', ')" }

    $tmp = Join-Path $env:TEMP ("vibe-coding-copilot-deploy-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
    Write-Step "Cloning $repoUrl ($branch) to $tmp"
    git clone --depth 1 --branch $branch $repoUrl $tmp
    if ($LASTEXITCODE -ne 0) { throw "git clone failed" }

    Write-Step "Copying build output into the repository root"
    foreach ($item in $itemsToCopy) {
        $srcPath = Join-Path $root $item
        if (Test-Path $srcPath -PathType Container) {
            Copy-Item -Path $srcPath -Destination $tmp -Recurse -Force
        } else {
            Copy-Item -Path $srcPath -Destination $tmp -Force
        }
    }

    Push-Location $tmp
    try {
        git add -A
        $status = git status --porcelain
        if (-not $status) {
            Write-Step "No changes to deploy — build output is identical to the live site"
            return
        }
        Write-Step "Committing: $Message"
        git commit -m $Message
        if ($LASTEXITCODE -ne 0) { throw "git commit failed" }

        Write-Step "Pushing to $branch"
        git push origin $branch
        if ($LASTEXITCODE -ne 0) {
            throw "git push failed. Nothing was published; inspect the remote state before retrying so you don't publish twice."
        }

        Write-Host "`nPushed. GitHub Pages usually needs a minute to rebuild:" -ForegroundColor Green
        Write-Host "https://sebplace.github.io/vibe-coding-copilot/" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
finally {
    Pop-Location
    if ($tmp -and (Test-Path $tmp)) {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}
