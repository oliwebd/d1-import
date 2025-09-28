#!/bin/bash

# D1 Import CLI Tool Installer
# Easy installation and setup for Cloudflare D1 database import tool

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Tool configuration
TOOL_NAME="d1-import"
INSTALL_DIR="$HOME/.d1-import"
BIN_DIR="$HOME/.local/bin"
CONFIG_FILE="$INSTALL_DIR/config.json"
DB_LIST_FILE="$INSTALL_DIR/.db_list.txt"

echo -e "${BLUE}🚀 D1 Import CLI Tool Installer${NC}"
echo "========================================"

# Check if Node.js is installed
check_nodejs() {
    echo -e "${YELLOW}Checking Node.js installation...${NC}"
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js is not installed. Please install Node.js LTS first.${NC}"
        echo "Visit: https://nodejs.org/"
        exit 1
    fi
    
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✅ Node.js found: $NODE_VERSION${NC}"
}

# Create directories
create_directories() {
    echo -e "${YELLOW}Creating directories...${NC}"
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"
    mkdir -p "$INSTALL_DIR/logs"
    echo -e "${GREEN}✅ Directories created${NC}"
}

# Generate main CLI tool
create_cli_tool() {
    echo -e "${YELLOW}Creating CLI tool...${NC}"
    
    cat > "$INSTALL_DIR/index.js" << 'EOF'
#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const { promisify } = require('util');
const { spawn } = require('child_process');

class D1ImportCLI {
    constructor() {
        this.configFile = path.join(__dirname, 'config.json');
        this.dbListFile = path.join(__dirname, '.db_list.txt');
        this.logFile = path.join(__dirname, 'logs', `d1-import-${new Date().toISOString().split('T')[0]}.log`);
        this.config = this.loadConfig();
    }

    log(message) {
        const timestamp = new Date().toISOString();
        const logMessage = `[${timestamp}] ${message}\n`;
        console.log(message);
        fs.appendFileSync(this.logFile, logMessage);
    }

    loadConfig() {
        try {
            if (fs.existsSync(this.configFile)) {
                return JSON.parse(fs.readFileSync(this.configFile, 'utf8'));
            }
        } catch (error) {
            this.log(`Warning: Could not load config: ${error.message}`);
        }
        return {};
    }

    saveConfig() {
        try {
            fs.writeFileSync(this.configFile, JSON.stringify(this.config, null, 2));
            this.log('Configuration saved successfully');
        } catch (error) {
            this.log(`Error saving config: ${error.message}`);
        }
    }

    loadDatabaseList() {
        try {
            if (fs.existsSync(this.dbListFile)) {
                const content = fs.readFileSync(this.dbListFile, 'utf8');
                const databases = {};
                content.split('\n').forEach(line => {
                    const trimmed = line.trim();
                    if (trimmed && trimmed.includes('=')) {
                        const [key, value] = trimmed.split('=');
                        databases[key] = value;
                    }
                });
                return databases;
            }
        } catch (error) {
            this.log(`Error loading database list: ${error.message}`);
        }
        return {};
    }

    async makeRequest(url, options = {}) {
        return new Promise((resolve, reject) => {
            const protocol = url.startsWith('https://') ? https : http;
            const req = protocol.request(url, options, (res) => {
                let data = '';
                res.on('data', chunk => data += chunk);
                res.on('end', () => {
                    try {
                        resolve({
                            statusCode: res.statusCode,
                            data: JSON.parse(data),
                            headers: res.headers
                        });
                    } catch (e) {
                        resolve({
                            statusCode: res.statusCode,
                            data: data,
                            headers: res.headers
                        });
                    }
                });
            });
            
            req.on('error', reject);
            
            if (options.body) {
                req.write(JSON.stringify(options.body));
            }
            
            req.end();
        });
    }

    async getD1Databases() {
        if (!this.config.accountId || !this.config.apiToken) {
            throw new Error('Please configure your Cloudflare credentials first using: d1-import config');
        }

        const url = `https://api.cloudflare.com/client/v4/accounts/${this.config.accountId}/d1/database`;
        const options = {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${this.config.apiToken}`,
                'Content-Type': 'application/json'
            }
        };

        try {
            const response = await this.makeRequest(url, options);
            if (response.data.success) {
                return response.data.result;
            } else {
                throw new Error(`API Error: ${JSON.stringify(response.data.errors)}`);
            }
        } catch (error) {
            this.log(`Error fetching D1 databases: ${error.message}`);
            throw error;
        }
    }

    async generateSQLFromSource(sourceName) {
        const databases = this.loadDatabaseList();
        const sourceUrl = databases[sourceName];
        
        if (!sourceUrl) {
            throw new Error(`Database source '${sourceName}' not found in .db_list.txt`);
        }

        this.log(`Generating SQL from source: ${sourceName}`);
        
        // Determine database type from URL
        let dbType = 'unknown';
        if (sourceUrl.includes('mysql://') || sourceUrl.includes('jdbc:mysql')) {
            dbType = 'mysql';
        } else if (sourceUrl.includes('postgresql://') || sourceUrl.includes('postgres://')) {
            dbType = 'postgresql';
        } else if (sourceUrl.includes('mongodb://')) {
            dbType = 'mongodb';
        } else if (sourceUrl.includes('.sqlite') || sourceUrl.includes('.db')) {
            dbType = 'sqlite';
        }

        const outputFile = path.join(__dirname, 'temp', `${sourceName}-export.sql`);
        
        // Create temp directory
        const tempDir = path.dirname(outputFile);
        if (!fs.existsSync(tempDir)) {
            fs.mkdirSync(tempDir, { recursive: true });
        }

        // Generate appropriate SQL based on database type
        switch (dbType) {
            case 'mysql':
                return await this.exportFromMySQL(sourceUrl, outputFile);
            case 'postgresql':
                return await this.exportFromPostgreSQL(sourceUrl, outputFile);
            case 'mongodb':
                return await this.exportFromMongoDB(sourceUrl, outputFile);
            case 'sqlite':
                return await this.copyFromSQLite(sourceUrl, outputFile);
            default:
                throw new Error(`Unsupported database type detected from URL: ${sourceUrl}`);
        }
    }

    async exportFromMySQL(url, outputFile) {
        this.log('Exporting from MySQL database...');
        
        // Parse MySQL URL
        const urlParts = new URL(url);
        const host = urlParts.hostname;
        const port = urlParts.port || 3306;
        const username = urlParts.username;
        const password = urlParts.password;
        const database = urlParts.pathname.replace('/', '');

        // Use mysqldump if available
        try {
            await this.executeCommand('mysqldump', [
                `-h${host}`,
                `-P${port}`,
                `-u${username}`,
                `-p${password}`,
                '--no-create-info',
                '--skip-extended-insert',
                '--compact',
                database
            ], outputFile);
            
            // Convert MySQL syntax to SQLite compatible
            await this.convertToSQLiteFormat(outputFile);
            return outputFile;
        } catch (error) {
            this.log(`mysqldump not available, using Node.js MySQL client...`);
            return await this.exportMySQLWithNode(url, outputFile);
        }
    }

    async exportFromPostgreSQL(url, outputFile) {
        this.log('Exporting from PostgreSQL database...');
        
        try {
            await this.executeCommand('pg_dump', [
                url,
                '--data-only',
                '--inserts',
                '--no-owner',
                '--no-privileges'
            ], outputFile);
            
            await this.convertToSQLiteFormat(outputFile);
            return outputFile;
        } catch (error) {
            this.log(`pg_dump not available, using Node.js PostgreSQL client...`);
            return await this.exportPostgreSQLWithNode(url, outputFile);
        }
    }

    async exportFromMongoDB(url, outputFile) {
        this.log('Exporting from MongoDB database...');
        this.log('Note: MongoDB export will be converted to relational format');
        
        // This would require a more complex implementation
        // For now, create a placeholder that explains the limitation
        const placeholder = `-- MongoDB export to SQL conversion
-- This feature requires custom implementation based on your MongoDB schema
-- Please manually convert your MongoDB collections to SQL INSERT statements
-- Example:
-- INSERT INTO collection_name (field1, field2) VALUES ('value1', 'value2');
`;
        fs.writeFileSync(outputFile, placeholder);
        return outputFile;
    }

    async copyFromSQLite(url, outputFile) {
        this.log('Copying from SQLite database...');
        
        // If it's a file path, copy it directly
        if (fs.existsSync(url)) {
            fs.copyFileSync(url, outputFile);
            return outputFile;
        }
        
        throw new Error(`SQLite file not found: ${url}`);
    }

    async convertToSQLiteFormat(filePath) {
        this.log('Converting SQL to SQLite format...');
        
        let content = fs.readFileSync(filePath, 'utf8');
        
        // Basic conversions for SQLite compatibility
        content = content
            .replace(/AUTO_INCREMENT/gi, 'AUTOINCREMENT')
            .replace(/ENGINE=\w+/gi, '')
            .replace(/DEFAULT CHARSET=\w+/gi, '')
            .replace(/COLLATE=\w+/gi, '')
            .replace(/`/g, '"')
            .replace(/UNSIGNED/gi, '')
            .replace(/TINYINT\(\d+\)/gi, 'INTEGER')
            .replace(/SMALLINT\(\d+\)/gi, 'INTEGER')
            .replace(/MEDIUMINT\(\d+\)/gi, 'INTEGER')
            .replace(/BIGINT\(\d+\)/gi, 'INTEGER')
            .replace(/INT\(\d+\)/gi, 'INTEGER')
            .replace(/VARCHAR\(\d+\)/gi, 'TEXT')
            .replace(/CHAR\(\d+\)/gi, 'TEXT')
            .replace(/TINYTEXT/gi, 'TEXT')
            .replace(/MEDIUMTEXT/gi, 'TEXT')
            .replace(/LONGTEXT/gi, 'TEXT')
            .replace(/TINYBLOB/gi, 'BLOB')
            .replace(/MEDIUMBLOB/gi, 'BLOB')
            .replace(/LONGBLOB/gi, 'BLOB');
        
        fs.writeFileSync(filePath, content);
        this.log('SQL conversion completed');
    }

    async executeCommand(command, args, outputFile) {
        return new Promise((resolve, reject) => {
            const process = spawn(command, args);
            const output = fs.createWriteStream(outputFile);
            
            process.stdout.pipe(output);
            
            process.stderr.on('data', (data) => {
                this.log(`Error: ${data.toString()}`);
            });
            
            process.on('close', (code) => {
                output.close();
                if (code === 0) {
                    resolve();
                } else {
                    reject(new Error(`Command failed with code ${code}`));
                }
            });
        });
    }

    async importToD1(sqlFile, databaseId) {
        this.log(`Starting import to D1 database: ${databaseId}`);
        
        if (!fs.existsSync(sqlFile)) {
            throw new Error(`SQL file not found: ${sqlFile}`);
        }

        const fileContent = fs.readFileSync(sqlFile);
        
        // Step 1: Initialize import
        const initUrl = `https://api.cloudflare.com/client/v4/accounts/${this.config.accountId}/d1/database/${databaseId}/import`;
        const initOptions = {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${this.config.apiToken}`,
                'Content-Type': 'application/json'
            },
            body: {
                action: 'init',
                etag: this.generateEtag(fileContent)
            }
        };

        const initResponse = await this.makeRequest(initUrl, initOptions);
        
        if (!initResponse.data.success) {
            throw new Error(`Import initialization failed: ${JSON.stringify(initResponse.data.errors)}`);
        }

        const uploadUrl = initResponse.data.result.upload_url;
        
        // Step 2: Upload file
        this.log('Uploading SQL file...');
        await this.uploadFile(uploadUrl, fileContent);
        
        // Step 3: Start ingestion
        const ingestOptions = {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${this.config.apiToken}`,
                'Content-Type': 'application/json'
            },
            body: {
                action: 'ingest',
                etag: this.generateEtag(fileContent),
                filename: path.basename(sqlFile)
            }
        };

        const ingestResponse = await this.makeRequest(initUrl, ingestOptions);
        
        if (!ingestResponse.data.success) {
            throw new Error(`Import ingestion failed: ${JSON.stringify(ingestResponse.data.errors)}`);
        }

        // Step 4: Poll for completion
        await this.pollImportStatus(initUrl, initResponse.data.result.at_bookmark);
        
        this.log('Import completed successfully!');
    }

    generateEtag(content) {
        const crypto = require('crypto');
        return crypto.createHash('md5').update(content).digest('hex');
    }

    async uploadFile(uploadUrl, content) {
        return new Promise((resolve, reject) => {
            const url = new URL(uploadUrl);
            const options = {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/octet-stream',
                    'Content-Length': content.length
                }
            };

            const req = https.request(uploadUrl, options, (res) => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    resolve();
                } else {
                    reject(new Error(`Upload failed with status ${res.statusCode}`));
                }
            });

            req.on('error', reject);
            req.write(content);
            req.end();
        });
    }

    async pollImportStatus(url, bookmark) {
        this.log('Polling import status...');
        
        const pollOptions = {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${this.config.apiToken}`,
                'Content-Type': 'application/json'
            },
            body: {
                action: 'poll',
                current_bookmark: bookmark
            }
        };

        while (true) {
            await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
            
            const response = await this.makeRequest(url, pollOptions);
            
            if (response.data.success && response.data.result.status === 'complete') {
                this.log('Import status: Complete');
                break;
            } else if (response.data.result.status === 'error') {
                throw new Error(`Import failed: ${response.data.result.error}`);
            } else {
                this.log(`Import status: ${response.data.result.status}`);
            }
        }
    }

    async handleCommand() {
        const args = process.argv.slice(2);
        
        if (args.length === 0) {
            this.showHelp();
            return;
        }

        try {
            switch (args[0]) {
                case 'config':
                    await this.configure();
                    break;
                case 'list':
                    await this.listDatabases();
                    break;
                case 'import':
                    if (args.length < 2) {
                        console.log('Usage: d1-import import <source_name> [target_db_id]');
                        return;
                    }
                    await this.importData(args[1], args[2]);
                    break;
                case 'show-sources':
                    this.showDatabaseSources();
                    break;
                case 'help':
                default:
                    this.showHelp();
                    break;
            }
        } catch (error) {
            this.log(`Error: ${error.message}`);
            process.exit(1);
        }
    }

    async configure() {
        const readline = require('readline');
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });

        const question = (prompt) => new Promise(resolve => {
            rl.question(prompt, resolve);
        });

        console.log('Configuring D1 Import CLI...');
        
        this.config.accountId = await question('Cloudflare Account ID: ');
        this.config.apiToken = await question('Cloudflare API Token: ');
        
        rl.close();
        
        this.saveConfig();
        console.log('Configuration saved successfully!');
    }

    async listDatabases() {
        this.log('Fetching D1 databases...');
        const databases = await this.getD1Databases();
        
        console.log('\n📊 Available D1 Databases:');
        console.log('================================');
        databases.forEach((db, index) => {
            console.log(`${index + 1}. ${db.name} (${db.uuid})`);
            console.log(`   Created: ${new Date(db.created_at).toLocaleString()}`);
            console.log(`   Version: ${db.version}\n`);
        });
    }

    showDatabaseSources() {
        const databases = this.loadDatabaseList();
        console.log('\n🗄️  Configured Database Sources:');
        console.log('==================================');
        
        if (Object.keys(databases).length === 0) {
            console.log('No database sources configured.');
            console.log(`Please add sources to: ${this.dbListFile}`);
            console.log('Format: SOURCE_NAME=connection_string');
        } else {
            Object.entries(databases).forEach(([name, url]) => {
                console.log(`${name} = ${url}`);
            });
        }
    }

    async importData(sourceName, targetDbId) {
        this.log(`Starting import process for source: ${sourceName}`);
        
        // If no target DB specified, show list for selection
        if (!targetDbId) {
            const databases = await this.getD1Databases();
            console.log('\nSelect target D1 database:');
            databases.forEach((db, index) => {
                console.log(`${index + 1}. ${db.name} (${db.uuid})`);
            });
            
            const readline = require('readline');
            const rl = readline.createInterface({
                input: process.stdin,
                output: process.stdout
            });

            const selection = await new Promise(resolve => {
                rl.question('Enter database number: ', resolve);
            });
            rl.close();
            
            const selectedIndex = parseInt(selection) - 1;
            if (selectedIndex >= 0 && selectedIndex < databases.length) {
                targetDbId = databases[selectedIndex].uuid;
            } else {
                throw new Error('Invalid selection');
            }
        }

        // Generate SQL from source
        const sqlFile = await this.generateSQLFromSource(sourceName);
        
        // Import to D1
        await this.importToD1(sqlFile, targetDbId);
        
        this.log('Import process completed successfully!');
    }

    showHelp() {
        console.log(`
🚀 D1 Import CLI Tool
====================

Usage: d1-import <command> [options]

Commands:
  config           Configure Cloudflare credentials
  list             List available D1 databases
  show-sources     Show configured database sources
  import <source>  Import data from source to D1 database
  help             Show this help message

Examples:
  d1-import config
  d1-import list
  d1-import import MySQL_1
  d1-import import PostgreSQL_1 uuid-of-target-db

Configuration files:
  ${this.configFile}
  ${this.dbListFile}

Log files: ${path.dirname(this.logFile)}
        `);
    }
}

// Run CLI
const cli = new D1ImportCLI();
cli.handleCommand();
EOF

    chmod +x "$INSTALL_DIR/index.js"
    echo -e "${GREEN}✅ CLI tool created${NC}"
}

# Create executable script
create_executable() {
    echo -e "${YELLOW}Creating executable script...${NC}"
    
    cat > "$BIN_DIR/$TOOL_NAME" << EOF
#!/bin/bash
node "$INSTALL_DIR/index.js" "\$@"
EOF

    chmod +x "$BIN_DIR/$TOOL_NAME"
    echo -e "${GREEN}✅ Executable script created${NC}"
}

# Create sample database list file
create_sample_db_list() {
    echo -e "${YELLOW}Creating sample database list...${NC}"
    
    cat > "$DB_LIST_FILE" << 'EOF'
# Database connection strings
# Format: NAME=connection_string

# MySQL Examples
MySQL_1=mysql://user:password@localhost:3306/database_name
MySQL_2=mysql://user:password@host.example.com:3306/another_db

# PostgreSQL Examples
PostgreSQL_1=postgresql://user:password@localhost:5432/database_name
PostgreSQL_2=postgres://user:password@host.example.com:5432/another_db

# MongoDB Examples (Note: Limited conversion support)
MongoDB_1=mongodb://user:password@localhost:27017/database_name

# SQLite Examples
SQLite_1=/path/to/your/database.sqlite
SQLite_2=/path/to/your/database.db
EOF

    echo -e "${GREEN}✅ Sample database list created${NC}"
}

# Create package.json for dependencies
create_package_json() {
    echo -e "${YELLOW}Creating package.json...${NC}"
    
    cat > "$INSTALL_DIR/package.json" << 'EOF'
{
  "name": "d1-import-cli",
  "version": "1.0.0",
  "description": "CLI tool for importing data into Cloudflare D1 databases",
  "main": "index.js",
  "bin": {
    "d1-import": "./index.js"
  },
  "dependencies": {},
  "engines": {
    "node": ">=16.0.0"
  },
  "author": "D1 Import CLI",
  "license": "MIT"
}
EOF

    echo -e "${GREEN}✅ Package.json created${NC}"
}

# Setup initial configuration
setup_config() {
    echo -e "${YELLOW}Setting up initial configuration...${NC}"
    
    read -p "Would you like to configure Cloudflare credentials now? (y/n): " configure_now
    
    if [[ $configure_now =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Configuring Cloudflare credentials...${NC}"
        "$BIN_DIR/$TOOL_NAME" config
    else
        echo -e "${YELLOW}You can configure credentials later using: $TOOL_NAME config${NC}"
    fi
}

# Add to PATH if needed
add_to_path() {
    echo -e "${YELLOW}Checking PATH configuration...${NC}"
    
    # Check if BIN_DIR is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo -e "${YELLOW}Adding $BIN_DIR to PATH...${NC}"
        
        # Add to bash profile
        if [ -f "$HOME/.bashrc" ]; then
            echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$HOME/.bashrc"
            echo -e "${GREEN}✅ Added to ~/.bashrc${NC}"
        fi
        
        # Add to zsh profile
        if [ -f "$HOME/.zshrc" ]; then
            echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$HOME/.zshrc"
            echo -e "${GREEN}✅ Added to ~/.zshrc${NC}"
        fi
        
        # Export for current session
        export PATH="$BIN_DIR:$PATH"
        
        echo -e "${YELLOW}Please restart your terminal or run: source ~/.bashrc${NC}"
    else
        echo -e "${GREEN}✅ PATH already configured${NC}"
    fi
}

# Main installation process
main() {
    echo -e "${BLUE}Starting installation...${NC}"
    
    check_nodejs
    create_directories
    create_cli_tool
    create_executable
    create_sample_db_list
    create_package_json
    add_to_path
    setup_config
    
    echo ""
    echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Quick Start:${NC}"
    echo "1. Configure credentials: $TOOL_NAME config"
    echo "2. Edit database sources: $DB_LIST_FILE"
    echo "3. List D1 databases: $TOOL_NAME list"
    echo "4. Import data: $TOOL_NAME import MySQL_1"
    echo ""
    echo -e "${BLUE}Files created:${NC}"
    echo "- Tool directory: $INSTALL_DIR"
    echo "- Configuration: $CONFIG_FILE"
    echo "- Database list: $DB_LIST_FILE"
    echo "- Logs: $INSTALL_DIR/logs/"
    echo ""
    echo -e "${YELLOW}For help: $TOOL_NAME help${NC}"
}

# Run installation
main
