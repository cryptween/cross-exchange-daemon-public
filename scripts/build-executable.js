#!/usr/bin/env node

/**
 * Standalone executable builder for testing GitHub Actions workflows locally
 * This script mimics the build process from GitHub Actions
 */

const fs = require('fs-extra');
const path = require('path');
const { execSync, spawn } = require('child_process');

class ExecutableBuilder {
  constructor(options = {}) {
    this.options = {
      target: options.target || 'linux-x64',
      output: options.output || 'cross-exchange-daemon-linux',
      verbose: options.verbose || false,
      skipCleanup: options.skipCleanup || false,
      ...options
    };
    
    this.workDir = path.resolve(__dirname, '..');
    this.tempDir = path.join(this.workDir, 'temp-build');
  }

  log(message, type = 'info') {
    const timestamp = new Date().toISOString();
    const prefix = {
      'info': 'ℹ️',
      'success': '✅',
      'warning': '⚠️',
      'error': '❌'
    }[type] || 'ℹ️';
    
    console.log(`${prefix} [${timestamp}] ${message}`);
  }

  async cleanup() {
    if (!this.options.skipCleanup && fs.existsSync(this.tempDir)) {
      await fs.remove(this.tempDir);
      this.log('Cleaned up temporary build directory');
    }
  }

  async setupBuildEnvironment() {
    this.log('Setting up build environment...');
    
    // Cleanup and create temp directory
    await this.cleanup();
    await fs.ensureDir(this.tempDir);
    
    // Copy source files to temp directory
    const filesToCopy = [
      'src',
      'package.json',
      'package-lock.json',
      'assets',
      'contracts'
    ];
    
    for (const file of filesToCopy) {
      const srcPath = path.join(this.workDir, file);
      const destPath = path.join(this.tempDir, file);
      
      if (await fs.pathExists(srcPath)) {
        await fs.copy(srcPath, destPath);
        this.log(`Copied: ${file}`);
      }
    }
    
    this.log('Build environment setup completed', 'success');
  }

  async installDependencies() {
    this.log('Installing dependencies...');
    
    try {
      execSync('npm ci', { 
        cwd: this.tempDir, 
        stdio: this.options.verbose ? 'inherit' : 'pipe' 
      });
      
      // Install build tools
      execSync('npm install --no-save @vercel/ncc pkg', { 
        cwd: this.tempDir, 
        stdio: this.options.verbose ? 'inherit' : 'pipe' 
      });
      
      this.log('Dependencies installed successfully', 'success');
    } catch (error) {
      throw new Error(`Failed to install dependencies: ${error.message}`);
    }
  }

  async preparePkgConfiguration() {
    this.log('Preparing package.json for pkg...');
    
    const packageJsonPath = path.join(this.tempDir, 'package.json');
    const packageJson = await fs.readJson(packageJsonPath);
    
    // Configure pkg to handle native modules and problematic packages
    packageJson.pkg = {
      scripts: 'src/index.js',
      targets: [this.options.target],
      outputPath: 'dist',
      options: [
        '--enable-source-maps',
        '--no-bytecode'
      ],
      assets: [
        'assets/**/*',
        'contracts/**/*',
        'node_modules/sqlite3/lib/binding/**/*',
        'node_modules/keytar/build/**/*',
        'node_modules/bcrypt/lib/binding/**/*'
      ]
    };
    
    // Handle problematic crypto packages
    const problematicPackages = [
      'websocket',
      'web3',
      'web3-core', 
      'web3-providers-ws',
      'web3-core-requestmanager',
      '@truffle/contract',
      '@truffle/hdwallet-provider',
      '@truffle/codec',
      '@truffle/decoder',
      '@truffle/abi-utils',
      '@truffle/compile-common'
    ];
    
    if (!packageJson.browser) packageJson.browser = {};
    problematicPackages.forEach(packageName => {
      packageJson.browser[packageName] = false;
    });
    
    await fs.writeJson(packageJsonPath, packageJson, { spaces: 2 });
    this.log('Package.json configured for pkg', 'success');
  }

  async createNativeModulePatches() {
    this.log('Creating native module patches...');
    
    const patchesDir = path.join(this.tempDir, 'patches');
    await fs.ensureDir(patchesDir);
    
    // SQLite3 patch
    await fs.writeFile(path.join(patchesDir, 'sqlite3.js'), `
try {
  module.exports = require('sqlite3');
} catch (e) {
  console.warn('sqlite3 native module not available, using fallback');
  module.exports = null;
}
`);

    // Keytar patch
    await fs.writeFile(path.join(patchesDir, 'keytar.js'), `
try {
  module.exports = require('keytar');
} catch (e) {
  console.warn('keytar native module not available, using fallback');
  module.exports = {
    getPassword: () => Promise.resolve(null),
    setPassword: () => Promise.resolve(),
    deletePassword: () => Promise.resolve()
  };
}
`);

    // Bcrypt patch
    await fs.writeFile(path.join(patchesDir, 'bcrypt.js'), `
try {
  module.exports = require('bcrypt');
} catch (e) {
  console.warn('bcrypt native module not available, using bcryptjs fallback');
  module.exports = require('bcryptjs');
}
`);

    this.log('Native module patches created', 'success');
  }

  async executeCommand(command, options = {}) {
    return new Promise((resolve, reject) => {
      if (this.options.verbose) {
        this.log(`Executing: ${command}`);
      }
      
      const [cmd, ...args] = command.split(' ');
      const childProcess = spawn(cmd, args, {
        cwd: options.cwd || this.tempDir,
        stdio: this.options.verbose ? 'inherit' : ['pipe', 'pipe', 'pipe'],
        shell: true
      });

      let stdout = '';
      let stderr = '';

      if (!this.options.verbose) {
        childProcess.stdout.on('data', (data) => {
          stdout += data.toString();
        });

        childProcess.stderr.on('data', (data) => {
          stderr += data.toString();
        });
      }

      childProcess.on('close', (code) => {
        if (code === 0) {
          resolve({ stdout, stderr, code });
        } else {
          reject(new Error(`Command failed with code ${code}: ${stderr || stdout}`));
        }
      });

      childProcess.on('error', (error) => {
        reject(error);
      });
    });
  }

  async buildExecutable() {
    this.log(`Building executable for ${this.options.target}...`);
    
    // Method 1: Try ncc bundling
    try {
      this.log('Attempting ncc bundling approach...');
      
      const nccCommand = `npx ncc build src/index.js --out dist-bundle --minify --no-source-map-register ` +
        `--external sqlite3 --external keytar --external bcrypt --external bcryptjs ` +
        `--external websocket --external web3 --external web3-core ` +
        `--external web3-providers-ws --external web3-core-requestmanager ` +
        `--external @truffle/contract --external @truffle/hdwallet-provider ` +
        `--external @truffle/codec --external @truffle/decoder ` +
        `--external @truffle/abi-utils --external @truffle/compile-common`;
      
      await this.executeCommand(nccCommand);
      
      // Create final package structure
      const distDir = path.join(this.tempDir, 'dist');
      await fs.ensureDir(distDir);
      
      await fs.copy(path.join(this.tempDir, 'dist-bundle', 'index.js'), path.join(distDir, 'index.js'));
      await fs.copy(path.join(this.tempDir, 'package.json'), path.join(distDir, 'package.json'));
      
      // Copy assets if they exist
      for (const assetDir of ['assets', 'contracts']) {
        const srcAssetPath = path.join(this.tempDir, assetDir);
        const destAssetPath = path.join(distDir, assetDir);
        if (await fs.pathExists(srcAssetPath)) {
          await fs.copy(srcAssetPath, destAssetPath);
        }
      }
      
      // Create launcher script
      const launcherPath = path.join(this.workDir, this.options.output);
      
      if (this.options.target.includes('win')) {
        await fs.writeFile(launcherPath, `@echo off
cd /d "%~dp0\\temp-build\\dist"
node index.js %*
`);
      } else {
        await fs.writeFile(launcherPath, `#!/bin/bash
cd "$(dirname "$0")/temp-build/dist"
exec node index.js "$@"
`);
        await fs.chmod(launcherPath, '755');
      }
      
      this.log('✓ Executable built successfully with ncc bundling', 'success');
      return 'ncc';
      
    } catch (nccError) {
      this.log(`ncc bundling failed: ${nccError.message}`, 'warning');
      
      // Method 2: Try pkg
      try {
        this.log('Attempting pkg approach...');
        
        const pkgCommand = `npx pkg package.json --target ${this.options.target} --output ${this.options.output} --options no-bytecode,no-warnings`;
        await this.executeCommand(pkgCommand);
        
        // Move the executable to the main directory
        const builtExecutable = path.join(this.tempDir, this.options.output);
        const finalExecutable = path.join(this.workDir, this.options.output);
        
        if (await fs.pathExists(builtExecutable)) {
          await fs.move(builtExecutable, finalExecutable, { overwrite: true });
        }
        
        this.log('✓ Executable built successfully with pkg', 'success');
        return 'pkg';
        
      } catch (pkgError) {
        this.log(`pkg failed: ${pkgError.message}`, 'warning');
        
        // Method 3: Basic Node.js package
        this.log('Creating basic Node.js package...');
        
        const distDir = path.join(this.tempDir, 'dist');
        await fs.ensureDir(distDir);
        await fs.copy(path.join(this.tempDir, 'src'), path.join(distDir, 'src'));
        await fs.copy(path.join(this.tempDir, 'package.json'), path.join(distDir, 'package.json'));
        
        // Create launcher
        const launcherPath = path.join(this.workDir, this.options.output);
        
        if (this.options.target.includes('win')) {
          await fs.writeFile(launcherPath, `@echo off
cd /d "%~dp0\\temp-build\\dist"
node src/index.js %*
`);
        } else {
          await fs.writeFile(launcherPath, `#!/bin/bash
cd "$(dirname "$0")/temp-build/dist"
exec node src/index.js "$@"
`);
          await fs.chmod(launcherPath, '755');
        }
        
        this.log('✓ Basic Node.js package created', 'success');
        return 'basic';
      }
    }
  }

  async testExecutable() {
    this.log('Testing built executable...');
    
    const executablePath = path.join(this.workDir, this.options.output);
    
    if (!await fs.pathExists(executablePath)) {
      throw new Error('Executable not found');
    }
    
    try {
      // Test basic functionality (help command with timeout)
      const result = await Promise.race([
        this.executeCommand(`${executablePath} --help`, { cwd: this.workDir }),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Test timeout')), 10000)
        )
      ]);
      
      this.log('✓ Executable test passed', 'success');
      return true;
    } catch (error) {
      this.log(`Executable test failed: ${error.message}`, 'warning');
      return false;
    }
  }

  async run() {
    try {
      this.log(`Starting build process for ${this.options.target}`);
      
      await this.setupBuildEnvironment();
      await this.installDependencies();
      await this.preparePkgConfiguration();
      await this.createNativeModulePatches();
      
      const buildMethod = await this.buildExecutable();
      const testResult = await this.testExecutable();
      
      this.log('📦 Build Summary:', 'info');
      this.log(`  Target: ${this.options.target}`, 'info');
      this.log(`  Output: ${this.options.output}`, 'info');
      this.log(`  Method: ${buildMethod}`, 'info');
      this.log(`  Test: ${testResult ? 'PASSED' : 'FAILED'}`, testResult ? 'success' : 'warning');
      
      if (!this.options.skipCleanup) {
        await this.cleanup();
      }
      
      this.log('🎉 Build completed successfully!', 'success');
      
    } catch (error) {
      this.log(`Build failed: ${error.message}`, 'error');
      
      if (!this.options.skipCleanup) {
        await this.cleanup();
      }
      
      process.exit(1);
    }
  }
}

// CLI interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const options = {
    verbose: args.includes('--verbose') || args.includes('-v'),
    skipCleanup: args.includes('--skip-cleanup'),
    target: 'linux-x64',
    output: 'cross-exchange-daemon-linux'
  };
  
  // Parse target
  const targetIndex = args.indexOf('--target');
  if (targetIndex !== -1 && args[targetIndex + 1]) {
    options.target = args[targetIndex + 1];
    
    // Set appropriate output name based on target
    if (options.target.includes('win')) {
      options.output = 'cross-exchange-daemon-win.exe';
    } else if (options.target.includes('macos')) {
      options.output = 'cross-exchange-daemon-macos';
    }
  }
  
  // Parse output
  const outputIndex = args.indexOf('--output');
  if (outputIndex !== -1 && args[outputIndex + 1]) {
    options.output = args[outputIndex + 1];
  }
  
  // Show help
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
Cross Exchange Daemon - Local Executable Builder

Usage: node scripts/build-executable.js [options]

Options:
  --target TARGET      Target platform (default: linux-x64)
                       Available: linux-x64, win-x64, macos-x64
  --output OUTPUT      Output executable name
  --verbose, -v        Show detailed output
  --skip-cleanup       Keep temporary build files
  --help, -h          Show this help message

Examples:
  # Build for Linux (default)
  node scripts/build-executable.js

  # Build for Windows with verbose output
  node scripts/build-executable.js --target win-x64 --verbose

  # Build for macOS and keep temp files
  node scripts/build-executable.js --target macos-x64 --skip-cleanup
`);
    process.exit(0);
  }
  
  const builder = new ExecutableBuilder(options);
  builder.run();
}

module.exports = ExecutableBuilder;