# Claude PR Automation Setup Guide

This guide explains how to set up the automated PR description generation using Claude API.

## What This Workflow Does

1. **Triggers**: Automatically runs when you push to any branch (except main/master)
2. **Analyzes**: Gets all changes compared to the main branch (diff, changed files, commit messages)
3. **Generates**: Sends the changes to Claude API to generate a professional PR description
4. **Creates/Updates**: Either creates a new PR or updates an existing one with the generated description

## Setup Instructions

### 1. Add Claude API Key to GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `CLAUDE_API_KEY`
5. Value: `--ADD-HERE-YOUR-VALUE--` (replace with your actual Claude API key)

### 2. Required Permissions

Make sure your repository has the following permissions enabled:
- **Settings** → **Actions** → **General** → **Workflow permissions**
- Select **Read and write permissions**
- Check **Allow GitHub Actions to create and approve pull requests**

### 3. How to Use

1. Create a new branch: `git checkout -b feature/my-awesome-feature`
2. Make your changes and commit them
3. Push the branch: `git push origin feature/my-awesome-feature`
4. The workflow will automatically:
   - Analyze your changes
   - Generate a PR description using Claude
   - Create a new PR or update existing one

## Workflow Features

### Smart Branch Detection
- Automatically detects if your repo uses `main` or `master` as the default branch
- Compares changes against the correct base branch

### PR Management
- **New Branch**: Creates a new PR with generated description
- **Existing PR**: Updates the existing PR description with fresh analysis
- **Smart Titles**: Auto-generates PR titles based on branch names

### Rich Context for Claude
The workflow sends Claude:
- Complete git diff of all changes
- List of modified files
- Commit messages from the branch
- Structured prompt for consistent output

### Error Handling
- Graceful fallback if Claude API fails
- Detailed logging for debugging
- Artifact uploads for inspection

## Customization Options

### Modify the Claude Prompt
Edit the prompt in the workflow file (around line 50) to customize how Claude analyzes your changes:

```yaml
# Prepare the prompt for Claude
cat > prompt.txt << 'EOF'
You are a technical writing assistant. Based on the following code changes, generate a clear and professional Pull Request description.

# Add your custom instructions here
EOF
```

### Change Trigger Conditions
Modify the `on:` section to change when the workflow runs:

```yaml
on:
  push:
    branches:
      - 'feature/**'  # Only feature branches
      - 'bugfix/**'   # Only bugfix branches
```

### Adjust Claude Model
Change the model in the API call (around line 80):

```yaml
"model": "claude-3-5-sonnet-20241022",  # or claude-3-opus-20240229
```

## Troubleshooting

### Common Issues

1. **"CLAUDE_API_KEY not found"**
   - Make sure you added the secret correctly in repository settings
   - Check the secret name matches exactly: `CLAUDE_API_KEY`

2. **"Permission denied" errors**
   - Verify workflow permissions are set to "Read and write"
   - Enable "Allow GitHub Actions to create and approve pull requests"

3. **No PR created**
   - Check if you're pushing to main/master (workflow skips these)
   - Look at the workflow logs in the Actions tab

4. **Claude API errors**
   - Verify your API key is valid and has sufficient credits
   - Check the workflow artifacts for the actual API response

### Viewing Workflow Results

1. Go to **Actions** tab in your repository
2. Click on the latest workflow run
3. Expand the job steps to see detailed logs
4. Download artifacts to see the generated description and prompt

## Cost Considerations

- Each workflow run makes one API call to Claude
- Typical cost: ~$0.01-0.05 per run (depending on change size)
- The workflow limits Claude responses to 1000 tokens to control costs

## Advanced Usage

### Manual Trigger
You can also trigger the workflow manually:

1. Go to **Actions** tab
2. Select "Auto PR Description with Claude"
3. Click "Run workflow"
4. Choose your branch

### Integration with Other Tools
The workflow saves the generated description as an artifact, which you can use in other workflows or tools.

## Security Notes

- The workflow only has access to your repository code (what you're already committing)
- Claude API key is stored securely in GitHub secrets
- No sensitive data is sent to Claude beyond your code changes 