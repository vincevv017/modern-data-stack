# Trino Query Assistant - Dual Mode

AI-powered natural language SQL generation comparing Claude API vs Local Ollama.

## Architecture

**Backend Comparison:**
- **Claude API**: Uses Anthropic's API (claude-sonnet-3-5) via HTTPS
- **Local Ollama**: Uses local inference (qwen2.5-coder:7b) on M2 chip
- **Trino**: Direct Python connection to query lakehouse catalog

**Infrastructure:**
- Streamlit + Ollama run natively on macOS for best M2 performance
- Trino + Polaris + MinIO run in Docker containers
- No MCP involved - direct API calls for simplicity

## Prerequisites

1. Docker Compose with Trino stack running
2. Python 3.11+
3. Ollama installed locally
4. Anthropic API key (optional - Ollama works standalone)

## Quick Start
```bash
# 1. Start Docker stack (from root directory)
cd /Users/vincent/Documents/ModernDataStack/modern-data-stack
docker-compose up -d

# 2. Setup Streamlit app
cd streamlit-app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. Configure environment
cp .env.example .env
# Edit .env and add your ANTHROPIC_API_KEY (or leave commented for Ollama-only)

# 4. Install Ollama (if not already installed)
brew install ollama
ollama serve &
ollama pull qwen2.5-coder:7b

# 5. Run the app
streamlit run app.py
```

## Usage

1. Open http://localhost:8501
2. Select backend mode in sidebar:
   - **Local Ollama**: 100% local, GDPR-compliant, free
   - **Claude API**: Cloud-based, fastest, requires API key
   - **Compare Both**: Side-by-side comparison
3. Ask natural language questions about your data
4. View generated SQL, explanations, and results

## Features

- ✅ Dual backend comparison (Claude API vs Ollama)
- ✅ Real-time performance metrics (generation time, row counts)
- ✅ English explanations alongside SQL
- ✅ Query history with statistics
- ✅ Export results to JSON
- ✅ Schema auto-discovery
- ✅ Connection health checks
- ✅ Data privacy mode (Ollama runs 100% local)

## Note on MCP

This app does **NOT** use MCP (Model Context Protocol). It uses direct API calls:
- Claude: Direct Anthropic API via `anthropic` Python library
- Ollama: Direct Ollama API via `ollama` Python library
- Trino: Direct connection via `trino` Python library

For MCP-based Trino integration, see the `mcp-servers/` directory in the parent project.

## Troubleshooting

**Trino connection failed:**
```bash
docker-compose ps  # Check if Trino is running
docker-compose logs trino  # Check logs
```

**Ollama not found:**
```bash
ollama serve &  # Start Ollama service
ollama list  # Verify models installed
```

**Schema loading slow:**
- Reduce schemas in get_schema_context()
- Focus on specific schemas only

## Performance

- **Ollama on M2 (24GB RAM)**: ~10-20 tokens/sec with 7B models
- **Claude API**: ~50-100 tokens/sec
- **SQL Generation**: Both typically <3 seconds
- **Query Execution**: Depends on Trino data size

## Cost Comparison

| Backend | Setup | Per Query | Privacy |
|---------|-------|-----------|---------|
| Ollama | Free | Free | 100% local |
| Claude API | $5 min | ~$0.01 | Sent to Anthropic |