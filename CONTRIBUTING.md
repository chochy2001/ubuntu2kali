# Contributing to ubuntu2kali

Thank you for your interest in contributing to this project. Your help is appreciated.

## How to Contribute

### Reporting Issues

- Open an issue on GitHub with a clear description of the problem.
- Include your Ubuntu version, kernel version, and any relevant error output.
- Paste the relevant lines from `~/kali-tools-install.log` or `~/kali-tools-failed.log`.

### Suggesting New Tools

- Open an issue with the title "Tool Request: <tool-name>".
- Explain what the tool does and which category it belongs to.
- If possible, include the installation method (apt, pip, go install, git clone).

### Submitting Changes

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/my-improvement`
3. Make your changes to `install-kali-tools.sh`.
4. Test the changes on a clean Ubuntu 24.04 installation (a VM is recommended). The project uses dynamic user detection and works for any Ubuntu 24.04 user -- do not hardcode usernames.
5. Commit with a clear message describing what was changed and why.
6. Push your branch and open a Pull Request.

### Code Style

- Follow the existing structure of the script (sections, logging functions, error handling).
- Use `log`, `warn`, and `error` functions for output instead of raw `echo`.
- Suppress verbose output with `| tail -N` and always include a fallback `|| warn "..."`.
- Group tools by category to keep the script organized.

### Testing

- Always test on a fresh Ubuntu 24.04 system or VM before submitting.
- Verify that existing tools still install correctly after your changes.
- Check both `~/kali-tools-install.log` and `~/kali-tools-failed.log` after a run.

## Code of Conduct

Be respectful and constructive. This is a security tools project -- use it responsibly and legally, only on systems you own or have explicit permission to test.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
