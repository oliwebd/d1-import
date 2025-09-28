# D1 Import CLI Tool

🚀 Easy-to-use command-line tool for importing data from various databases into Cloudflare D1 databases.

## Features

- ✅ **Multi-database support**: MySQL, PostgreSQL, MongoDB*, SQLite
- ✅ **One-time configuration**: Save credentials and database connections
- ✅ **Automatic SQL conversion**: Converts to SQLite-compatible format
- ✅ **Interactive selection**: Choose target D1 database from list
- ✅ **Comprehensive logging**: All operations logged with timestamps
- ✅ **Easy installation**: Single bash script setup

*MongoDB support includes basic conversion to relational format

## Quick Installation

```bash
# Download and run the installer
curl -fsSL https://raw.githubusercontent.com/oliwebd/d1-import/main/install.sh | bash

```
### Or
```bash
# download install.sh and run locally
chmod +x install.sh
./install.sh

```

## Manual Installation

1. **Prerequisites**: Node.js LTS (16+)
2. **Run installer**: Execute the provided `install.sh` script
3. **Configure**: Run `d1-import config` to set up Cloudflare credentials
4. **Add databases**: Edit `~/.d1-import/.db_list.txt` with your database connections

## Configuration

### 1. Cloudflare API Setup

Get your credentials from Cloudflare dashboard:
- **Account ID**: Found in the right sidebar of any Cloudflare dashboard page
- **API Token**: Create with D1:Edit permissions at https://dash.cloudflare.com/profile/api-tokens

```bash
d1-import config
```

### 2. Database Sources

Edit `~/.d1-import/.db_list.txt`:

```text
# MySQL
MySQL_prod=mysql://user:pass@host.example.com:3306/database
MySQL_dev=mysql://user:pass@localhost:3306/dev_db

# PostgreSQL
PostgreSQL_main=postgresql://user:pass@host.example.com:5432/database
PostgreSQL_test=postgres://user:pass@localhost:5432/test_db

# MongoDB (basic conversion)
MongoDB_main=mongodb://user:pass@host.example.com:27017/database

# SQLite
SQLite_local=/path/to/database.sqlite
SQLite_backup=/path/to/backup.db
```

## Usage

### List Available D1 Databases

```bash
d1-import list
```

Output:
```
📊 Available D1 Databases:
================================
1. my-production-db (uuid-1234-5678)
   Created: 12/1/2024, 10:30:00 AM
   Version: production

2. my-development-db (uuid-8765-4321)
   Created: 12/1/2024, 2:15:00 PM
   Version: development
```

### Show Configured Database Sources

```bash
d1-import show-sources
```

### Import Data

#### Interactive Mode (Recommended)
```bash
d1-import import MySQL_prod
# You'll be prompted to select the target D1 database
```

#### Direct Mode
```bash
d1-import import MySQL_prod uuid-of-target-d1-database
```

### View Help

```bash
d1-import help
```

## How It Works

### 1. SQL Generation
The tool generates SQLite-compatible SQL from your source database:

- **MySQL**: Uses `mysqldump` if available, falls back to Node.js client
- **PostgreSQL**: Uses `pg_dump` if available, falls back to Node.js client
- **SQLite**: Direct file copy or export
- **MongoDB**: Basic JSON-to-SQL conversion (requires manual schema mapping)

### 2. SQL Conversion
Automatically converts database-specific syntax to SQLite format:

```sql
-- MySQL/PostgreSQL → SQLite conversions
AUTO_INCREMENT → AUTOINCREMENT
VARCHAR(255) → TEXT
INT(11) → INTEGER
TINYINT → INTEGER
`backticks` → "quotes"
```

### 3. D1 Import Process
Uses Cloudflare's D1 API workflow:

1. **Initialize**: Create import session
2. **Upload**: Send SQL file to temporary URL
3. **Ingest**: Start processing
4. **Poll**: Monitor completion status

## API Integration

### Cloudflare D1 API Endpoints Used

#### List Databases
```bash
GET /accounts/{account_id}/d1/database
Authorization: Bearer {api_token}
```

#### Import Data
```bash
POST /accounts/{account_id}/d1/database/{database_id}/import
Content-Type: application/json
Authorization: Bearer {api_token}

# Step 1: Initialize
{
  "action": "init",
  "etag": "file-hash"
}

# Step 2: Ingest
{
  "action": "ingest", 
  "etag": "file-hash",
  "filename": "export.sql"
}

# Step 3: Poll
{
  "action": "poll",
  "current_bookmark": "bookmark-id"
}
```

## File Structure

```
~/.d1-import/
├── config.json           # Cloudflare credentials
├── .db_list.txt          # Database connection strings
├── index.js              # Main CLI application
├── package.json          # Node.js package info
├── temp/                 # Temporary SQL exports
│   ├── MySQL_1-export.sql
│   └── PostgreSQL_1-export.sql
└── logs/                 # Operation logs
    ├── d1-import-2024-12-01.log
    └── d1-import-2024-12-02.log
```

## Advanced Usage

### Custom Database Exports

For complex databases, you can manually create SQL files and place them in the temp directory:

```bash
# Create custom export
mysqldump -h host -u user -p database > ~/.d1-import/temp/custom-export.sql

# Import custom file (modify source code to support this)
d1-import import-file custom-export.sql target-db-uuid
```

### Batch Operations

```bash
# Import multiple databases
for db in MySQL_1 MySQL_2 PostgreSQL_1; do
    d1-import import "$db" target-uuid
done
```

### Logging and Debugging

All operations are logged with timestamps:

```bash
# View today's log
tail -f ~/.d1-import/logs/d1-import-$(date +%Y-%m-%d).log

# View all logs
ls ~/.d1-import/logs/
```

## Database-Specific Notes

### MySQL
- Requires `mysql` client for optimal export (falls back to Node.js)
- Automatically converts MySQL syntax to SQLite
- Handles AUTO_INCREMENT, data types, and constraints

### PostgreSQL
- Requires `postgresql-client` for optimal export
- Converts PostgreSQL-specific syntax
- Handles sequences and data types

### MongoDB
- **Limited support**: Requires manual schema design
- Converts documents to relational tables
- Best for simple document structures

### SQLite
- Direct file operations
- No conversion needed
- Fastest import method

## Troubleshooting

### Common Issues

#### 1. Command Not Found
```bash
# Add to PATH manually
export PATH="$HOME/.local/bin:$PATH"

# Or restart terminal after installation
```

#### 2. API Authentication Failed
```bash
# Reconfigure credentials
d1-import config

# Verify Account ID and API Token
```

#### 3. Database Connection Failed
```bash
# Check connection string in .db_list.txt
# Ensure database is accessible from your network
```

#### 4. SQL Conversion Issues
```bash
# Check logs for specific errors
tail ~/.d1-import/logs/d1-import-$(date +%Y-%m-%d).log

# Manual conversion may be needed for complex schemas
```

### Debug Mode

Add debug logging by modifying the configuration:

```json
// ~/.d1-import/config.json
{
  "accountId": "your-account-id",
  "apiToken": "your-api-token",
  "debug": true
}
```

## Security Best Practices

1. **API Token Permissions**: Use minimal required permissions (D1:Edit)
2. **Connection Strings**: Store securely, consider environment variables
3. **File Permissions**: Ensure config files are not world-readable
4. **Log Rotation**: Clean up old log files regularly

```bash
# Secure config file
chmod 600 ~/.d1-import/config.json
chmod 600 ~/.d1-import/.db_list.txt
```

## Extending the Tool

### Adding New Database Types

1. Add detection logic in `generateSQLFromSource()`
2. Implement export method (e.g., `exportFromOracle()`)
3. Add conversion rules in `convertToSQLiteFormat()`

### Custom Conversions

Modify the conversion rules in `convertToSQLiteFormat()`:

```javascript
// Add custom conversions
content = content
  .replace(/CUSTOM_TYPE/gi, 'TEXT')
  .replace(/CUSTOM_FUNCTION\(\)/gi, 'SQLITE_FUNCTION()');
```

## Examples

### Complete Workflow

```bash
# 1. Install
curl -fsSL https://example.com/install.sh | bash

# 2. Configure
d1-import config
# Enter your Cloudflare Account ID: abc123...
# Enter your API Token: token123...

# 3. Add database sources
echo "Production_MySQL=mysql://user:pass@prod.example.com:3306/app" >> ~/.d1-import/.db_list.txt

# 4. List D1 databases
d1-import list

# 5. Import data
d1-import import Production_MySQL
# Select target database: 1

# 6. View logs
tail ~/.d1-import/logs/d1-import-$(date +%Y-%m-%d).log
```

### Environment Variables

```bash
# Alternative configuration method
export D1_ACCOUNT_ID="your-account-id"
export D1_API_TOKEN="your-api-token"

# Tool will use these if config.json doesn't exist
```

## Performance Optimization

### Large Databases

For databases larger than 100MB:

1. **Split exports** by table or date ranges
2. **Use compression** on SQL files
3. **Import during off-peak hours**
4. **Monitor D1 usage limits**

### Batch Size Optimization

```sql
-- Optimize INSERT statements
-- Instead of single row inserts:
INSERT INTO table (col1, col2) VALUES ('val1', 'val2');
INSERT INTO table (col1, col2) VALUES ('val3', 'val4');

-- Use multi-row inserts:
INSERT INTO table (col1, col2) VALUES 
  ('val1', 'val2'),
  ('val3', 'val4');
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Submit pull request

## License

MIT License - feel free to use and modify

## Support

- 📖 Documentation: Check this README
- 🐛 Issues: Create GitHub issue
- 💬 Discussions: GitHub Discussions
- 📧 Email: support@example.com

## Changelog

### v1.0.0
- Initial release
- Support for MySQL, PostgreSQL, SQLite
- Basic MongoDB support
- Interactive database selection
- Comprehensive logging
- One-time configuration

---

Made with ❤️ for the Cloudflare D1 community
