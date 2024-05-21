# Gitleaks Pre-commit Hook Installation Script

This script automates the installation of Gitleaks and sets up a pre-commit hook to scan for sensitive information before every commit in your Git repositories.

## Usage
To run the script, execute the following command:

```sh
curl -sSL https://raw.githubusercontent.com/anderson28/gitleaks-pre-commit/main/run.sh | sh
```
Ensure that you run this command in the project folder where there is a .git folder present.

For Windows users, it's recommended to use Git Bash to run the script.

To disable the gitleaks system, type in the terminal:  
```sh
git config hooks.gitleaks false
```
## What Happens
1. Gitleaks Installation:

- The script checks if Gitleaks is installed on your system.
- If not installed, it downloads and installs the latest version of Gitleaks.
- If an older version is detected, it prompts you to update to the latest version.

2. Pre-commit Hook Setup:

- After installing Gitleaks, the script sets up a pre-commit hook.
- This hook runs Gitleaks on staged changes before every commit to check for sensitive information.
- The pre-commit hook is automatically installed in the .git/hooks directory of your repository.

## Windows Compatibility:

- For Windows users, it's essential to use Git Bash to run the script.
- Git Bash provides a Unix-like command-line experience on Windows and ensures compatibility with the script.

## Notes
- Ensure you have curl installed on your system to download the script.
- Make sure you run the script in the root folder of your Git repository where the .git folder is located.

By using this script, you can enhance the security of your Git workflow by automatically scanning for potential leaks of sensitive information before committing changes.
