# Cross Exchange Daemon - Public Distribution

**⚠️ This is an obfuscated version of the Cross Exchange Daemon for public distribution.**

## About

The Cross Exchange Daemon is a powerful tool for cross-exchange data collection and cryptocurrency services management. This public version contains obfuscated source code to protect intellectual property while maintaining full functionality.

## System Requirements

- **Node.js**: Version 16.0.0 or higher
- **Operating System**: Windows, macOS, or Linux
- **Memory**: Minimum 4GB RAM recommended
- **Storage**: 1GB free space

## Native Module Dependencies

This application uses several native Node.js modules that require compilation:

- **sqlite3**: Database operations
- **keytar**: Secure credential storage (optional with fallback)
- **bcrypt**: Password hashing (with bcryptjs fallback)

### Installation

```bash
# Install dependencies
npm install

# For systems with compilation issues, install with fallbacks
npm install --no-optional

# If native modules fail, rebuild them
npm rebuild sqlite3 keytar bcrypt
```

## Quick Start

### Using Pre-built Binaries (Recommended)

1. Download the appropriate binary for your system from [Releases](../../releases)
2. Extract the archive
3. Run the executable:
   - **Linux/macOS**: `./cross-exchange-daemon`
   - **Windows**: `cross-exchange-daemon.exe`

### Using Node.js

```bash
# Clone this repository
git clone https://github.com/cryptween/cross-exchange-daemon-public.git
cd cross-exchange-daemon-public

# Install dependencies
npm install

# Start the daemon
npm start
```

### Using Docker

```bash
# Pull the Docker image
docker pull cryptween/cross-exchange-daemon:latest

# Run with docker-compose
docker-compose up -d
```

## Configuration

Create a configuration file or set environment variables:

```bash
# Example environment variables
export NODE_ENV=production
export DATABASE_PATH=./data/daemon.db
export LOG_LEVEL=info
```

## Native Module Troubleshooting

### SQLite3 Issues

If SQLite3 fails to compile:

```bash
# Try rebuilding with specific Python version
npm rebuild sqlite3 --python=python3

# Or use the pre-compiled binaries
npm install sqlite3 --build-from-source=false
```

### Keytar Issues

If keytar fails (credential storage):

```bash
# Install system dependencies
# Ubuntu/Debian:
sudo apt-get install libsecret-1-dev

# RHEL/CentOS:
sudo yum install libsecret-devel

# macOS: (usually works out of the box)
# Windows: Requires Visual Studio Build Tools
```

### Bcrypt Issues

If bcrypt fails:

```bash
# The application will automatically fall back to bcryptjs
# No action required - functionality is maintained
```

## Docker Usage

The Docker image handles all native module compilation automatically:

```yaml
version: '3.8'
services:
  daemon:
    image: cryptween/cross-exchange-daemon:latest
    environment:
      - NODE_ENV=production
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    ports:
      - "3000:3000"
```

## API Documentation

Once running, API documentation is available at:
- Local: `http://localhost:3000/docs`
- Swagger UI with full endpoint documentation

## Support

### Common Issues

1. **Native module compilation errors**
   - Ensure you have build tools installed
   - Use Docker for easiest deployment
   - Use pre-built binaries when available

2. **Database connection issues**
   - Check file permissions
   - Ensure SQLite3 is properly installed
   - Verify database path is writable

3. **Network connectivity**
   - Check firewall settings
   - Verify exchange API access
   - Check proxy configuration if applicable

### Getting Help

- 📖 **Documentation**: Check the `/docs` endpoint when running
- 🐛 **Issues**: Report bugs in this repository's issues
- 💬 **Discussions**: Use GitHub Discussions for questions

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Security Notice

This is obfuscated code for distribution purposes. While the code is protected, standard security practices still apply:

- Keep your dependencies updated
- Secure your API keys and credentials
- Run with appropriate user permissions
- Monitor logs for unusual activity

## Build Information

- **Obfuscated**: Yes
- **Build Date**: 2025-10-23T17:45:05.495Z
- **Node.js Version**: 18+
- **Native Modules**: sqlite3, keytar, bcrypt
- **Fallbacks Available**: Yes (bcryptjs, memory-based keytar)

---

**Note**: This is the public distribution version. Source code is obfuscated for intellectual property protection.