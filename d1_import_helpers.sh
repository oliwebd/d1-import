#!/bin/bash

# ==============================================================================
# D1 Import CLI - Additional Helper Scripts
# ==============================================================================

# 1. UNINSTALLER SCRIPT
# ==============================================================================
create_uninstaller() {
    cat > "$HOME/.local/bin/d1-import-uninstall" << 'EOF'
#!/bin/bash

# D1 Import CLI Uninstaller

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

INSTALL_DIR="$HOME/.d1-import"
BIN_DIR="$HOME/.local/bin"
TOOL_NAME="d1-import"

echo -e "${BLUE}🗑️  D1 Import CLI Uninstaller${NC}"
echo "===================================="

# Confirm uninstallation
read -p "Are you sure you want to uninstall D1 Import CLI? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Backup configuration
read -p "Do you want to backup your configuration? (Y/n): " backup
if [[ ! $backup =~ ^[Nn]$ ]]; then
    backup_dir="$HOME/d1-import-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    if [ -f "$INSTALL_DIR/config.json" ]; then
        cp "$INSTALL_DIR/config.json" "$backup_dir/"
        echo -e "${GREEN}✅ Config backed up to: $backup_dir${NC}"
    fi
    
    if [ -f "$INSTALL_DIR/.db_list.txt" ]; then
        cp "$INSTALL_DIR/.db_list.txt" "$backup_dir/"
        echo -e "${GREEN}✅ Database list backed up to: $backup_dir${NC}"
    fi
fi

# Remove files
echo -e "${YELLOW}Removing files...${NC}"

# Remove main directory
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✅ Removed: $INSTALL_DIR${NC}"
fi

# Remove executables
if [ -f "$BIN_DIR/$TOOL_NAME" ]; then
    rm "$BIN_DIR/$TOOL_NAME"
    echo -e "${GREEN}✅ Removed: $BIN_DIR/$TOOL_NAME${NC}"
fi

if [ -f "$BIN_DIR/d1-import-uninstall" ]; then
    rm "$BIN_DIR/d1-import-uninstall"
    echo -e "${GREEN}✅ Removed: $BIN_DIR/d1-import-uninstall${NC}"
fi

if [ -f "$BIN_DIR/d1-import-update" ]; then
    rm "$BIN_DIR/d1-import-update"
    echo -e "${GREEN}✅ Removed: $BIN_DIR/d1-import-update${NC}"
fi

# Remove PATH entries (optional)
read -p "Remove PATH entries from shell profiles? (y/N): " remove_path
if [[ $remove_path =~ ^[Yy]$ ]]; then
    # Remove from .bashrc
    if [ -f "$HOME/.bashrc" ]; then
        sed -i '/# D1 Import CLI PATH/d' "$HOME/.bashrc"
        sed -i '\|export PATH="$HOME/.local/bin:$PATH"|d' "$HOME/.bashrc"
        echo -e "${GREEN}✅ Cleaned .bashrc${NC}"
    fi
    
    # Remove from .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        sed -i '/# D1 Import CLI PATH/d' "$HOME/.zshrc"
        sed -i '\|export PATH="$HOME/.local/bin:$PATH"|d' "$HOME/.zshrc"
        echo -e "${GREEN}✅ Cleaned .zshrc${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 D1 Import CLI has been successfully uninstalled!${NC}"
echo ""
if [[ ! $backup =~ ^[Nn]$ ]]; then
    echo -e "${BLUE}Your configuration backup is saved at: $backup_dir${NC}"
fi
echo -e "${YELLOW}Please restart your terminal to update PATH${NC}"
EOF

    chmod +x "$HOME/.local/bin/d1-import-uninstall"
}

# 2. UPDATER SCRIPT
# ==============================================================================
create_updater() {
    cat > "$HOME/.local/bin/d1-import-update" << 'EOF'
#!/bin/bash

# D1 Import CLI Updater

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

INSTALL_DIR="$HOME/.d1-import"
UPDATE_URL="https://raw.githubusercontent.com/your-repo/d1-import-cli/main/install.sh"

echo -e "${BLUE}🔄 D1 Import CLI Updater${NC}"
echo "=========================="

# Check current version (if version tracking is implemented)
current_version="1.0.0"
echo "Current version: $current_version"

# Backup current configuration
echo -e "${YELLOW}Creating backup...${NC}"
backup_dir="$HOME/d1-import-update-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"

if [ -f "$INSTALL_DIR/config.json" ]; then
    cp "$INSTALL_DIR/config.json" "$backup_dir/"
fi

if [ -f "$INSTALL_DIR/.db_list.txt" ]; then
    cp "$INSTALL_DIR/.db_list.txt" "$backup_dir/"
fi

echo -e "${GREEN}✅ Backup created: $backup_dir${NC}"

# Download and run installer
echo -e "${YELLOW}Downloading latest version...${NC}"
temp_installer="/tmp/d1-import-install-$(date +%s).sh"

if curl -fsSL "$UPDATE_URL" -o "$temp_installer"; then
    chmod +x "$temp_installer"
    echo -e "${GREEN}✅ Downloaded installer${NC}"
    
    echo -e "${YELLOW}Running update...${NC}"
    bash "$temp_installer"
    
    # Restore configuration
    echo -e "${YELLOW}Restoring configuration...${NC}"
    if [ -f "$backup_dir/config.json" ]; then
        cp "$backup_dir/config.json" "$INSTALL_DIR/"
        echo -e "${GREEN}✅ Configuration restored${NC}"
    fi
    
    if [ -f "$backup_dir/.db_list.txt" ]; then
        cp "$backup_dir/.db_list.txt" "$INSTALL_DIR/"
        echo -e "${GREEN}✅ Database list restored${NC}"
    fi
    
    # Cleanup
    rm "$temp_installer"
    rm -rf "$backup_dir"
    
    echo ""
    echo -e "${GREEN}🎉 Update completed successfully!${NC}"
else
    echo -e "${RED}❌ Failed to download update${NC}"
    echo "Please check your internet connection or update manually"
    exit 1
fi
EOF

    chmod +x "$HOME/.local/bin/d1-import-update"
}

# 3. DATABASE SCHEMA INSPECTOR
# ==============================================================================
create_schema_inspector() {
    cat > "$INSTALL_DIR/schema-inspector.js" << 'EOF'
#!/usr/bin/env node

// D1 Import CLI - Database Schema Inspector
// Analyzes database schemas for conversion compatibility

const fs = require('fs');
const path = require('path');

class SchemaInspector {
    constructor() {
        this.installDir = path.dirname(__filename);
        this.dbListFile = path.join(this.installDir, '.db_list.txt');
    }

    loadDatabaseList() {
        try {
            if (fs.existsSync(this.dbListFile)) {
                const content = fs.readFileSync(this.dbListFile, 'utf8');
                const databases = {};
                content.split('\n').forEach(line => {
                    const trimmed = line.trim();
                    if (trimmed && trimmed.includes('=') && !trimmed.startsWith('#')) {
                        const [key, value] = trimmed.split('=');
                        databases[key] = value;
                    }
                });
                return databases;
            }
        } catch (error) {
            console.error(`Error loading database list: ${error.message}`);
        }
        return {};
    }

    analyzeConnectionString(connectionString) {
        const analysis = {
            type: 'unknown',
            host: 'unknown',
            port: 'default',
            database: 'unknown',
            ssl: false,
            compatibility: 'unknown'
        };

        try {
            if (connectionString.startsWith('mysql://')) {
                analysis.type = 'MySQL';
                analysis.compatibility = 'High - Full conversion support';
                const url = new URL(connectionString);
                analysis.host = url.hostname;
                analysis.port = url.port || '3306';
                analysis.database = url.pathname.replace('/', '');
                analysis.ssl = url.searchParams.has('ssl');
            } else if (connectionString.startsWith('postgresql://') || connectionString.startsWith('postgres://')) {
                analysis.type = 'PostgreSQL';
                analysis.compatibility = 'High - Full conversion support';
                const url = new URL(connectionString);
                analysis.host = url.hostname;
                analysis.port = url.port || '5432';
                analysis.database = url.pathname.replace('/', '');
                analysis.ssl = url.searchParams.has('sslmode');
            } else if (connectionString.startsWith('mongodb://')) {
                analysis.type = 'MongoDB';
                analysis.compatibility = 'Limited - Manual schema mapping required';
                const url = new URL(connectionString);
                analysis.host = url.hostname;
                analysis.port = url.port || '27017';
                analysis.database = url.pathname.replace('/', '');
            } else if (connectionString.includes('.sqlite') || connectionString.includes('.db')) {
                analysis.type = 'SQLite';
                analysis.compatibility = 'Perfect - No conversion needed';
                analysis.host = 'Local file';
                analysis.database = path.basename(connectionString);
            }
        } catch (error) {
            analysis.compatibility = `Error parsing connection string: ${error.message}`;
        }

        return analysis;
    }

    generateCompatibilityReport() {
        const databases = this.loadDatabaseList();
        
        console.log('\n🔍 Database Schema Compatibility Report');
        console.log('=====================================\n');

        if (Object.keys(databases).length === 0) {
            console.log('No databases configured in .db_list.txt');
            return;
        }

        Object.entries(databases).forEach(([name, connectionString]) => {
            const analysis = this.analyzeConnectionString(connectionString);
            
            console.log(`📊 ${name}`);
            console.log(`   Type: ${analysis.type}`);
            console.log(`   Host: ${analysis.host}:${analysis.port}`);
            console.log(`   Database: ${analysis.database}`);
            console.log(`   Compatibility: ${analysis.compatibility}`);
            
            // Add specific recommendations
            if (analysis.type === 'MySQL') {
                console.log('   💡 Recommendations:');
                console.log('      • Ensure mysqldump is installed for optimal performance');
                console.log('      • AUTO_INCREMENT will be converted to AUTOINCREMENT');
                console.log('      • VARCHAR types will become TEXT in SQLite');
            } else if (analysis.type === 'PostgreSQL') {
                console.log('   💡 Recommendations:');
                console.log('      • Ensure pg_dump is installed for optimal performance');
                console.log('      • SERIAL types will be converted to INTEGER');
                console.log('      • UUID types may need manual handling');
            } else if (analysis.type === 'MongoDB') {
                console.log('   ⚠️  Limitations:');
                console.log('      • Only basic document-to-table conversion');
                console.log('      • Complex nested structures require manual mapping');
                console.log('      • Consider flattening documents before import');
            } else if (analysis.type === 'SQLite') {
                console.log('   ✅ Perfect compatibility - direct import possible');
            }
            
            console.log('');
        });

        // Overall recommendations
        console.log('🎯 General Recommendations:');
        console.log('• Test with small datasets first');
        console.log('• Review generated SQL before importing to D1');
        console.log('• Consider data type mappings for your specific schema');
        console.log('• Use transactions for large imports');
        console.log('• Monitor D1 usage limits during import\n');
    }

    async testConnection(sourceName) {
        const databases = this.loadDatabaseList();
        const connectionString = databases[sourceName];
        
        if (!connectionString) {
            console.error(`Database source '${sourceName}' not found`);
            return;
        }

        console.log(`🔗 Testing connection to: ${sourceName}`);
        console.log(`Connection: ${connectionString}\n`);

        const analysis = this.analyzeConnectionString(connectionString);
        
        // Basic connectivity test (placeholder - would need actual database drivers)
        console.log('⚠️  Note: Full connectivity testing requires database-specific drivers');
        console.log('This tool provides schema analysis only.\n');
        
        console.log('📋 Connection Analysis:');
        console.log(`Type: ${analysis.type}`);
        console.log(`Compatibility: ${analysis.compatibility}`);
        
        if (analysis.type === 'SQLite') {
            // For SQLite, we can actually test file existence
            if (fs.existsSync(connectionString)) {
                console.log('✅ SQLite file exists and is accessible');
            } else {
                console.log('❌ SQLite file not found or not accessible');
            }
        }
    }

    showHelp() {
        console.log(`
🔍 D1 Import CLI - Schema Inspector
==================================

Usage: node schema-inspector.js <command> [options]

Commands:
  report               Generate compatibility report for all databases
  test <source_name>   Test connection to specific database source
  help                 Show this help message

Examples:
  node schema-inspector.js report
  node schema-inspector.js test MySQL_1
        `);
    }

    async run() {
        const args = process.argv.slice(2);
        
        if (args.length === 0 || args[0] === 'help') {
            this.showHelp();
            return;
        }

        switch (args[0]) {
            case 'report':
                this.generateCompatibilityReport();
                break;
            case 'test':
                if (args.length < 2) {
                    console.log('Usage: node schema-inspector.js test <source_name>');
                    return;
                }
                await this.testConnection(args[1]);
                break;
            default:
                console.log(`Unknown command: ${args[0]}`);
                this.showHelp();
                break;
        }
    }
}

// Run if called directly
if (require.main === module) {
    const inspector = new SchemaInspector();
    inspector.run();
}

module.exports = SchemaInspector;
EOF

    chmod +x "$INSTALL_DIR/schema-inspector.js"
}

# 4. LOG ANALYZER
# ==============================================================================
create_log_analyzer() {
    cat > "$HOME/.local/bin/d1-import-logs" << 'EOF'
#!/bin/bash

# D1 Import CLI - Log Analyzer

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

INSTALL_DIR="$HOME/.d1-import"
LOG_DIR="$INSTALL_DIR/logs"

show_help() {
    echo -e "${BLUE}📊 D1 Import CLI - Log Analyzer${NC}"
    echo "================================"
    echo ""
    echo "Usage: d1-import-logs <command> [options]"
    echo ""
    echo "Commands:"
    echo "  today           Show today's logs"
    echo "  yesterday       Show yesterday's logs"
    echo "  list            List all log files"
    echo "  errors          Show error messages from all logs"
    echo "  stats           Show import statistics"
    echo "  clean [days]    Clean logs older than N days (default: 30)"
    echo "  tail            Follow today's log in real-time"
    echo ""
    echo "Examples:"
    echo "  d1-import-logs today"
    echo "  d1-import-logs errors"
    echo "  d1-import-logs clean 7"
}

show_today() {
    today_log="$LOG_DIR/d1-import-$(date +%Y-%m-%d).log"
    
    if [ -f "$today_log" ]; then
        echo -e "${BLUE}📅 Today's Import Log${NC}"
        echo "===================="
        cat "$today_log"
    else
        echo -e "${YELLOW}No log file found for today${NC}"
    fi
}

show_yesterday() {
    yesterday_log="$LOG_DIR/d1-import-$(date -d yesterday +%Y-%m-%d).log"
    
    if [ -f "$yesterday_log" ]; then
        echo -e "${BLUE}📅 Yesterday's Import Log${NC}"
        echo "========================"
        cat "$yesterday_log"
    else
        echo -e "${YELLOW}No log file found for yesterday${NC}"
    fi
}

list_logs() {
    echo -e "${BLUE}📂 Available Log Files${NC}"
    echo "====================="
    
    if [ -d "$LOG_DIR" ] && [ "$(ls -A $LOG_DIR)" ]; then
        ls -la "$LOG_DIR"/*.log 2>/dev/null | while read line; do
            echo "$line"
        done
    else
        echo -e "${YELLOW}No log files found${NC}"
    fi
}

show_errors() {
    echo -e "${RED}🚨 Error Messages${NC}"
    echo "=================="
    
    if [ -d "$LOG_DIR" ]; then
        grep -h "Error\|ERROR\|Failed\|FAILED" "$LOG_DIR"/*.log 2>/dev/null || echo -e "${GREEN}No errors found in logs${NC}"
    else
        echo -e "${YELLOW}No log directory found${NC}"
    fi
}

show_stats() {
    echo -e "${BLUE}📊 Import Statistics${NC}"
    echo "===================="
    
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${YELLOW}No log directory found${NC}"
        return
    fi
    
    total_imports=$(grep -h "Starting import process" "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    successful_imports=$(grep -h "Import completed successfully" "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    failed_imports=$(grep -h "Import failed\|Error:" "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    
    echo "Total import attempts: $total_imports"
    echo "Successful imports: $successful_imports"
    echo "Failed imports: $failed_imports"
    
    if [ "$total_imports" -gt 0 ]; then
        success_rate=$(( successful_imports * 100 / total_imports ))
        echo "Success rate: ${success_rate}%"
    fi
    
    echo ""
    echo "Most imported databases:"
    grep -h "Starting import process for source:" "$LOG_DIR"/*.log 2>/dev/null | \
    sed 's/.*source: //' | sort | uniq -c | sort -nr | head -5
}

clean_logs() {
    days=${1:-30}
    echo -e "${YELLOW}🧹 Cleaning logs older than $days days...${NC}"
    
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${YELLOW}No log directory found${NC}"
        return
    fi
    
    find "$LOG_DIR" -name "*.log" -type f -mtime +$days -delete
    
    remaining_logs=$(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    echo -e "${GREEN}✅ Cleanup completed. $remaining_logs log files remaining.${NC}"
}

tail_logs() {
    today_log="$LOG_DIR/d1-import-$(date +%Y-%m-%d).log"
    
    echo -e "${BLUE}👀 Following today's log (Press Ctrl+C to stop)${NC}"
    echo "=============================================="
    
    # Create log file if it doesn't exist
    touch "$today_log"
    
    tail -f "$today_log"
}

# Main command handling
case "$1" in
    "today")
        show_today
        ;;
    "yesterday")
        show_yesterday
        ;;
    "list")
        list_logs
        ;;
    "errors")
        show_errors
        ;;
    "stats")
        show_stats
        ;;
    "clean")
        clean_logs "$2"
        ;;
    "tail")
        tail_logs
        ;;
    "help"|"")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
EOF

    chmod +x "$HOME/.local/bin/d1-import-logs"
}

# 5. CONFIGURATION VALIDATOR
# ==============================================================================
create_config_validator() {
    cat > "$INSTALL_DIR/validate-config.js" << 'EOF'
#!/usr/bin/env node

// D1 Import CLI - Configuration Validator

const fs = require('fs');
const path = require('path');
const https = require('https');

class ConfigValidator {
    constructor() {
        this.installDir = path.dirname(__filename);
        this.configFile = path.join(this.installDir, 'config.json');
        this.dbListFile = path.join(this.installDir, '.db_list.txt');
    }

    loadConfig() {
        try {
            if (fs.existsSync(this.configFile)) {
                return JSON.parse(fs.readFileSync(this.configFile, 'utf8'));
            }
        } catch (error) {
            console.error(`❌ Error loading config: ${error.message}`);
        }
        return null;
    }

    async validateCloudflareCredentials(config) {
        console.log('🔐 Validating Cloudflare credentials...');
        
        if (!config.accountId) {
            console.log('❌ Account ID is missing');
            return false;
        }
        
        if (!config.apiToken) {
            console.log('❌ API Token is missing');
            return false;
        }

        // Test API call
        try {
            const url = `https://api.cloudflare.com/client/v4/accounts/${config.accountId}/d1/database`;
            const response = await this.makeRequest(url, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${config.apiToken}`,
                    'Content-Type': 'application/json'
                }
            });

            if (response.statusCode === 200 && response.data.success) {
                console.log('✅ Cloudflare credentials are valid');
                console.log(`   Found ${response.data.result.length} D1 database(s)`);
                return true;
            } else {
                console.log('❌ Invalid credentials or insufficient permissions');
                console.log(`   Status: ${response.statusCode}`);
                if (response.data.errors) {
                    response.data.errors.forEach(error => {
                        console.log(`   Error: ${error.message}`);
                    });
                }
                return false;
            }
        } catch (error) {
            console.log(`❌ API test failed: ${error.message}`);
            return false;
        }
    }

    async makeRequest(url, options = {}) {
        return new Promise((resolve, reject) => {
            const req = https.request(url, options, (res) => {
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
            req.end();
        });
    }

    validateDatabaseList() {
        console.log('🗄️  Validating database list...');
        
        if (!fs.existsSync(this.dbListFile)) {
            console.log('❌ Database list file not found');
            return false;
        }

        try {
            const content = fs.readFileSync(this.dbListFile, 'utf8');
            const lines = content.split('\n').filter(line => 
                line.trim() && !line.trim().startsWith('#')
            );

            if (lines.length === 0) {
                console.log('⚠️  Database list is empty');
                return true; // Not an error, just empty
            }

            let validCount = 0;
            let invalidCount = 0;

            lines.forEach((line, index) => {
                const trimmed = line.trim();
                if (trimmed.includes('=')) {
                    const [name, connectionString] = trimmed.split('=');
                    if (name && connectionString) {
                        console.log(`✅ ${name.trim()} - ${this.getDbType(connectionString.trim())}`);
                        validCount++;
                    } else {
                        console.log(`❌ Line ${index + 1}: Invalid format - ${trimmed}`);
                        invalidCount++;
                    }
                } else {
                    console.log(`❌ Line ${index + 1}: Missing '=' separator - ${trimmed}`);
                    invalidCount++;
                }
            });

            console.log(`\n📊 Summary: ${validCount} valid, ${invalidCount} invalid entries`);
            return invalidCount === 0;
        } catch (error) {
            console.log(`❌ Error reading database list: ${error.message}`);
            return false;
        }
    }

    getDbType(connectionString) {
        if (connectionString.startsWith('mysql://')) return 'MySQL';
        if (connectionString.startsWith('postgresql://') || connectionString.startsWith('postgres://')) return 'PostgreSQL';
        if (connectionString.startsWith('mongodb://')) return 'MongoDB';
        if (connectionString.includes('.sqlite') || connectionString.includes('.db')) return 'SQLite';
        return 'Unknown';
    }

    validateDirectories() {
        console.log('📁 Validating directories...');
        
        const requiredDirs = [
            path.join(this.installDir, 'temp'),
            path.join(this.installDir, 'logs')
        ];

        let allValid = true;

        requiredDirs.forEach(dir => {
            if (!fs.existsSync(dir)) {
                console.log(`⚠️  Creating missing directory: ${dir}`);
                try {
                    fs.mkdirSync(dir, { recursive: true });
                    console.log(`✅ Created: ${dir}`);
                } catch (error) {
                    console.log(`❌ Failed to create: ${dir} - ${error.message}`);
                    allValid = false;
                }
            } else {
                console.log(`✅ Directory exists: ${path.basename(dir)}`);
            }
        });

        return allValid;
    }

    validatePermissions() {
        console.log('🔒 Validating file permissions...');
        
        const files = [
            { path: this.configFile, name: 'config.json' },
            { path: this.dbListFile, name: '.db_list.txt' },
            { path: path.join(this.installDir, 'index.js'), name: 'index.js' }
        ];

        let allValid = true;

        files.forEach(file => {
            if (fs.existsSync(file.path)) {
                try {
                    fs.accessSync(file.path, fs.constants.R_OK);
                    console.log(`✅ ${file.name} - readable`);
                    
                    if (file.name === 'index.js') {
                        fs.accessSync(file.path, fs.constants.X_OK);
                        console.log(`✅ ${file.name} - executable`);
                    }
                } catch (error) {
                    console.log(`❌ ${file.name} - permission denied`);
                    allValid = false;
                }
            }
        });

        return allValid;
    }

    async runFullValidation() {
        console.log('🔍 Running full configuration validation...\n');
        
        let allValid = true;
        
        // 1. Load and validate config
        const config = this.loadConfig();
        if (!config) {
            console.log('❌ Configuration file is missing or invalid');
            allValid = false;
        } else {
            console.log('✅ Configuration file loaded successfully');
        }

        // 2. Validate directories
        const dirsValid = this.validateDirectories();
        allValid = allValid && dirsValid;

        // 3. Validate permissions  
        const permsValid = this.validatePermissions();
        allValid = allValid && permsValid;

        // 4. Validate database list
        const dbListValid = this.validateDatabaseList();
        allValid = allValid && dbListValid;

        // 5. Validate Cloudflare credentials (if config exists)
        if (config) {
            const credsValid = await this.validateCloudflareCredentials(config);
            allValid = allValid && credsValid;
        }

        console.log('\n' + '='.repeat(50));
        if (allValid) {
            console.log('🎉 All validations passed! Configuration is ready.');
        } else {
            console.log('❌ Some validations failed. Please fix the issues above.');
        }
        console.log('='.repeat(50));

        return allValid;
    }

    showHelp() {
        console.log(`
🔍 D1 Import CLI - Configuration Validator
==========================================

Usage: node validate-config.js [command]

Commands:
  full        Run all validations (default)
  config      Validate Cloudflare configuration only
  databases   Validate database list only
  dirs        Validate directories only
  help        Show this help message

Examples:
  node validate-config.js
  node validate-config.js config
  node validate-config.js databases
        `);
    }

    async run() {
        const args = process.argv.slice(2);
        const command = args[0] || 'full';

        try {
            switch (command) {
                case 'full':
                    await this.runFullValidation();
                    break;
                case 'config':
                    const config = this.loadConfig();
                    if (config) {
                        await this.validateCloudflareCredentials(config);
                    }
                    break;
                case 'databases':
                    this.validateDatabaseList();
                    break;
                case 'dirs':
                    this.validateDirectories();
                    break;
                case 'help':
                    this.showHelp();
                    break;
                default:
                    console.log(`Unknown command: ${command}`);
                    this.showHelp();
                    break;
            }
        } catch (error) {
            console.error(`❌ Validation failed: ${error.message}`);
            process.exit(1);
        }
    }
}

// Run if called directly
if (require.main === module) {
    const validator = new ConfigValidator();
    validator.run();
}

module.exports = ConfigValidator;
EOF

    chmod +x "$INSTALL_DIR/validate-config.js"
}

# 6. BATCH IMPORT SCRIPT
# ==============================================================================
create_batch_importer() {
    cat > "$HOME/.local/bin/d1-import-batch" << 'EOF'
#!/bin/bash

# D1 Import CLI - Batch Import Tool

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    echo -e "${BLUE}📦 D1 Import CLI - Batch Import Tool${NC}"
    echo "===================================="
    echo ""
    echo "Usage: d1-import-batch <batch_file> [target_db_uuid]"
    echo ""
    echo "Batch file format (one source per line):"
    echo "  MySQL_1"
    echo "  PostgreSQL_1"
    echo "  SQLite_1"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help"
    echo "  -v, --verbose   Verbose output"
    echo "  -c, --continue  Continue on errors"
    echo ""
    echo "Examples:"
    echo "  d1-import-batch sources.txt"
    echo "  d1-import-batch sources.txt db-uuid-1234"
    echo "  d1-import-batch -v -c sources.txt"
}

# Parse command line arguments
VERBOSE=false
CONTINUE_ON_ERROR=false
BATCH_FILE=""
TARGET_DB=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--continue)
            CONTINUE_ON_ERROR=true
            shift
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
        *)
            if [ -z "$BATCH_FILE" ]; then
                BATCH_FILE="$1"
            elif [ -z "$TARGET_DB" ]; then
                TARGET_DB="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$BATCH_FILE" ]; then
    echo -e "${RED}Error: Batch file is required${NC}"
    show_help
    exit 1
fi

if [ ! -f "$BATCH_FILE" ]; then
    echo -e "${RED}Error: Batch file not found: $BATCH_FILE${NC}"
    exit 1
fi

# Read sources from batch file
mapfile -t SOURCES < <(grep -v '^#' "$BATCH_FILE" | grep -v '^[[:space:]]*)

if [ ${#SOURCES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No sources found in batch file${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Starting batch import...${NC}"
echo "=============================="
echo "Batch file: $BATCH_FILE"
echo "Sources: ${#SOURCES[@]}"
if [ -n "$TARGET_DB" ]; then
    echo "Target DB: $TARGET_DB"
fi
echo "Continue on error: $CONTINUE_ON_ERROR"
echo ""

# Counters
TOTAL=${#SOURCES[@]}
SUCCESS=0
FAILED=0
SKIPPED=0

# Process each source
for i in "${!SOURCES[@]}"; do
    SOURCE="${SOURCES[$i]}"
    CURRENT=$((i + 1))
    
    echo -e "${BLUE}[$CURRENT/$TOTAL] Processing: $SOURCE${NC}"
    
    if [ $VERBOSE = true ]; then
        echo "Command: d1-import import $SOURCE $TARGET_DB"
    fi
    
    # Run the import
    if d1-import import "$SOURCE" $TARGET_DB; then
        echo -e "${GREEN}✅ Success: $SOURCE${NC}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "${RED}❌ Failed: $SOURCE${NC}"
        FAILED=$((FAILED + 1))
        
        if [ $CONTINUE_ON_ERROR = false ]; then
            echo -e "${RED}Stopping batch import due to error${NC}"
            break
        fi
    fi
    
    echo ""
    
    # Small delay between imports
    sleep 2
done

# Summary
echo "=============================="
echo -e "${BLUE}📊 Batch Import Summary${NC}"
echo "=============================="
echo "Total sources: $TOTAL"
echo -e "${GREEN}Successful: $SUCCESS${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"

if [ $SUCCESS -eq $TOTAL ]; then
    echo -e "${GREEN}🎉 All imports completed successfully!${NC}"
    exit 0
elif [ $FAILED -gt 0 ]; then
    echo -e "${RED}⚠️  Some imports failed. Check logs for details.${NC}"
    exit 1
else
    echo -e "${YELLOW}ℹ️  Batch completed with mixed results.${NC}"
    exit 0
fi
EOF

    chmod +x "$HOME/.local/bin/d1-import-batch"
}

# 7. MAIN INSTALLER ENHANCEMENT
# ==============================================================================
enhance_main_installer() {
    echo -e "${YELLOW}Creating additional helper tools...${NC}"
    
    create_uninstaller
    create_updater
    create_schema_inspector
    create_log_analyzer
    create_config_validator
    create_batch_importer
    
    echo -e "${GREEN}✅ All helper tools created${NC}"
}

# 8. CREATE SAMPLE BATCH FILES
# ==============================================================================
create_sample_files() {
    echo -e "${YELLOW}Creating sample files...${NC}"
    
    # Sample batch import file
    cat > "$INSTALL_DIR/sample-batch.txt" << 'EOF'
# Sample Batch Import File
# One database source per line
# Lines starting with # are ignored

# Production databases
MySQL_prod
PostgreSQL_prod

# Development databases  
MySQL_dev
PostgreSQL_dev

# Local testing
SQLite_local
EOF

    # Sample environment configuration
    cat > "$INSTALL_DIR/.env.example" << 'EOF'
# Environment Configuration Example
# Copy to .env and fill in your values

# Cloudflare Configuration
D1_ACCOUNT_ID=your-account-id-here
D1_API_TOKEN=your-api-token-here

# Optional: Default target database
D1_DEFAULT_DB=your-default-db-uuid

# Optional: Logging level (debug, info, warn, error)
LOG_LEVEL=info

# Optional: Maximum import file size (in MB)
MAX_IMPORT_SIZE=100
EOF

    # Quick start script
    cat > "$INSTALL_DIR/quick-start.sh" << 'EOF'
#!/bin/bash

# D1 Import CLI - Quick Start Script

echo "🚀 D1 Import CLI Quick Start"
echo "============================"
echo ""

# Check if configured
if [ ! -f "$HOME/.d1-import/config.json" ]; then
    echo "1. Setting up Cloudflare credentials..."
    d1-import config
    echo ""
fi

# Validate configuration
echo "2. Validating configuration..."
node "$HOME/.d1-import/validate-config.js"
echo ""

# Show database sources
echo "3. Available database sources:"
d1-import show-sources
echo ""

# Show D1 databases
echo "4. Available D1 databases:"
d1-import list
echo ""

echo "🎉 Quick start completed!"
echo ""
echo "Next steps:"
echo "• Edit database sources: ~/.d1-import/.db_list.txt"
echo "• Import data: d1-import import <source_name>"
echo "• View logs: d1-import-logs today"
echo "• Get help: d1-import help"
EOF

    chmod +x "$INSTALL_DIR/quick-start.sh"
    
    echo -e "${GREEN}✅ Sample files created${NC}"
}

# 9. ADD COMMAND ALIASES
# ==============================================================================
create_aliases() {
    echo -e "${YELLOW}Creating command aliases...${NC}"
    
    # Create alias script
    cat > "$HOME/.local/bin/d1" << 'EOF'
#!/bin/bash

# D1 Import CLI - Short alias
d1-import "$@"
EOF

    chmod +x "$HOME/.local/bin/d1"
    
    # Create validation alias
    cat > "$HOME/.local/bin/d1-validate" << 'EOF'
#!/bin/bash

# D1 Import CLI - Configuration validation alias
node "$HOME/.d1-import/validate-config.js" "$@"
EOF

    chmod +x "$HOME/.local/bin/d1-validate"
    
    # Create schema inspector alias
    cat > "$HOME/.local/bin/d1-inspect" << 'EOF'
#!/bin/bash

# D1 Import CLI - Schema inspector alias  
node "$HOME/.d1-import/schema-inspector.js" "$@"
EOF

    chmod +x "$HOME/.local/bin/d1-inspect"
    
    echo -e "${GREEN}✅ Command aliases created${NC}"
    echo "   • d1 (short alias for d1-import)"
    echo "   • d1-validate (configuration validation)"  
    echo "   • d1-inspect (schema inspection)"
    echo "   • d1-import-logs (log analyzer)"
    echo "   • d1-import-batch (batch import)"
}

# 10. FINAL SETUP MESSAGE
# ==============================================================================
show_completion_message() {
    echo ""
    echo -e "${GREEN}🎉 Enhanced D1 Import CLI Installation Complete!${NC}"
    echo "================================================"
    echo ""
    echo -e "${BLUE}📦 Installed Tools:${NC}"
    echo "• d1-import          - Main CLI tool"
    echo "• d1                 - Short alias"
    echo "• d1-validate        - Configuration validator"
    echo "• d1-inspect         - Schema inspector"  
    echo "• d1-import-logs     - Log analyzer"
    echo "• d1-import-batch    - Batch import tool"
    echo "• d1-import-update   - Update tool"
    echo "• d1-import-uninstall - Uninstaller"
    echo ""
    echo -e "${BLUE}📁 File Locations:${NC}"
    echo "• Installation: $INSTALL_DIR"
    echo "• Configuration: $INSTALL_DIR/config.json"
    echo "• Database list: $INSTALL_DIR/.db_list.txt"
    echo "• Logs: $INSTALL_DIR/logs/"
    echo "• Samples: $INSTALL_DIR/sample-*"
    echo ""
    echo -e "${BLUE}🚀 Quick Commands:${NC}"
    echo "• Get started: $INSTALL_DIR/quick-start.sh"
    echo "• Configure: d1-import config"
    echo "• Validate: d1-validate"
    echo "• Import: d1-import import MySQL_1"
    echo "• View logs: d1-import-logs today"
    echo ""
    echo -e "${YELLOW}💡 Pro Tips:${NC}"
    echo "• Use 'd1' as a short alias for 'd1-import'"
    echo "• Run 'd1-validate' to check your setup"
    echo "• Use 'd1-inspect report' to analyze database compatibility"
    echo "• Create batch files for multiple imports with 'd1-import-batch'"
    echo "• Monitor imports in real-time with 'd1-import-logs tail'"
}

# Execute all enhancements
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # This script is being run directly
    echo -e "${BLUE}🔧 Installing Enhanced D1 Import CLI Tools${NC}"
    echo "==========================================="
    
    INSTALL_DIR="$HOME/.d1-import"
    
    enhance_main_installer
    create_sample_files  
    create_aliases
    show_completion_message
fi