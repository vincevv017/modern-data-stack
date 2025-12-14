import streamlit as st
import ollama
from trino.dbapi import connect
from trino.exceptions import TrinoUserError
import pandas as pd
import time
from datetime import datetime
from anthropic import Anthropic
import os
from dotenv import load_dotenv
import json


# Load environment variables
load_dotenv()



# Configuration
TRINO_HOST = os.getenv("TRINO_HOST", "localhost")
TRINO_PORT = int(os.getenv("TRINO_PORT", "8080"))
TRINO_USER = os.getenv("TRINO_USER", "admin")
TRINO_CATALOG = os.getenv("TRINO_CATALOG", "lakehouse")
TRINO_SCHEMA = os.getenv("TRINO_SCHEMA", "dbt_marts")

OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5-coder:7b")
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")

CLAUDE_MODEL = os.getenv("CLAUDE_MODEL", "claude-sonnet-4-20250514")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")

# Initialize clients
if ANTHROPIC_API_KEY:
    anthropic_client = Anthropic(api_key=ANTHROPIC_API_KEY)
else:
    anthropic_client = None

# Page config
st.set_page_config(
    page_title="Trino Query Assistant - Dual Mode",
    page_icon="🗄️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .stMetric {
        background-color: #1e1e1e;
        padding: 15px;
        border-radius: 10px;
        border: 1px solid #333;
    }
    .stMetric label {
        color: #ffffff !important;
    }
    .stMetric [data-testid="stMetricValue"] {
        color: #ffffff !important;
    }
    .stMetric [data-testid="stMetricDelta"] {
        color: #ffffff !important;
    }
    .comparison-box {
        border: 2px solid #e0e0e0;
        border-radius: 10px;
        padding: 20px;
        margin: 10px 0;
    }
</style>
""", unsafe_allow_html=True)

# Initialize session state
if 'messages' not in st.session_state:
    st.session_state.messages = []
if 'comparison_history' not in st.session_state:
    st.session_state.comparison_history = []
if 'schema_context' not in st.session_state:
    st.session_state.schema_context = None
if 'connection_tested' not in st.session_state:
    st.session_state.connection_tested = False




def test_trino_connection():
    """Test Trino connection and return status"""
    try:
        conn = connect(
            host=TRINO_HOST,
            port=TRINO_PORT,
            user=TRINO_USER,
            catalog=TRINO_CATALOG,
            http_scheme='http'
        )
        cursor = conn.cursor()
        cursor.execute("SELECT 1 as test")
        result = cursor.fetchone()
        cursor.close()
        conn.close()
        return True, "Connection successful"
    except Exception as e:
        return False, str(e)

def get_trino_connection():
    """Create Trino connection with error handling"""
    try:
        conn = connect(
            host=TRINO_HOST,
            port=TRINO_PORT,
            user=TRINO_USER,
            catalog=TRINO_CATALOG,
            http_scheme='http'
        )
        return conn
    except Exception as e:
        raise ConnectionError(
            f"Failed to connect to Trino at {TRINO_HOST}:{TRINO_PORT}. "
            f"Make sure your docker-compose stack is running.\n"
            f"Run: docker-compose ps\n"
            f"Error: {str(e)}"
        )

def get_schema_context():
    """Fetch schema information from Trino"""
    try:
        conn = get_trino_connection()
        cursor = conn.cursor()
        
        # Get schemas
        cursor.execute("SHOW SCHEMAS")
        schemas = [row[0] for row in cursor.fetchall()]
        
        schema_info = {}
        skipped_schemas = []
        
        for schema in schemas:
            # Skip system schemas
            if schema in ['information_schema', 'system']:
                continue
            
            try:
                cursor.execute(f"SHOW TABLES FROM {schema}")
                tables = [row[0] for row in cursor.fetchall()]
                
                if not tables:
                    continue
                
                schema_info[schema] = {}
                
                for table in tables:
                    try:
                        cursor.execute(f"DESCRIBE {schema}.{table}")
                        columns = cursor.fetchall()
                        schema_info[schema][table] = [
                            {"name": col[0], "type": col[1]} for col in columns
                        ]
                    except Exception as e:
                        st.warning(f"Could not describe {schema}.{table}: {str(e)}")
                        continue
                        
            except Exception as e:
                skipped_schemas.append(f"{schema} ({str(e)})")
                continue
        
        cursor.close()
        conn.close()
        
        if skipped_schemas:
            st.info(f"Skipped schemas: {', '.join(skipped_schemas)}")
        
        return schema_info
        
    except ConnectionError as e:
        st.error(str(e))
        return None
    except Exception as e:
        st.error(f"Error loading schema: {str(e)}")
        return None

def format_schema_for_prompt(schema_context: dict, max_tables_per_schema: int = 10) -> str:
    """Format schema context for LLM prompt with limits"""
    if not schema_context:
        return "No schema information available."
    
    schema_desc = "Available schemas and tables in the Trino lakehouse:\n\n"
    
    for schema, tables in schema_context.items():
        schema_desc += f"Schema: {schema}\n"
        
        table_count = 0
        for table, columns in tables.items():
            if table_count >= max_tables_per_schema:
                schema_desc += f"  ... and {len(tables) - table_count} more tables\n"
                break
                
            schema_desc += f"  Table: {table}\n"
            
            # Limit columns shown
            for col in columns[:15]:
                schema_desc += f"    - {col['name']} ({col['type']})\n"
            
            if len(columns) > 15:
                schema_desc += f"    ... and {len(columns) - 15} more columns\n"
            
            table_count += 1
        
        schema_desc += "\n"
    
    return schema_desc

def generate_sql_with_ollama(user_query: str, schema_context: dict) -> tuple:
    """Use Ollama to generate SQL from natural language"""
    start_time = time.time()
    
    schema_desc = format_schema_for_prompt(schema_context)
    
    prompt = f"""You are a SQL expert specializing in Trino SQL. Based on the user's question, provide:
1. A brief explanation of what you'll query (1 sentence)
2. The SQL query

{schema_desc}

User question: {user_query}

Format your response exactly like this:
EXPLANATION: [one sentence explaining the query approach]
SQL:
[the SQL query without any markdown or code blocks]

Requirements for SQL:
- Use proper Trino SQL syntax
- Always specify schema.table format (e.g., dbt_marts.customers)
- Return only SELECT statements
- Use appropriate WHERE clauses, JOINs, and aggregations as needed
- Limit results to 100 rows unless user specifies otherwise

Response:"""

    try:
        response = ollama.generate(
            model=OLLAMA_MODEL,
            prompt=prompt,
            options={
                "temperature": 0.1,
                "num_predict": 500
            }
        )
        
        full_response = response['response'].strip()
        
        # Parse explanation and SQL
        explanation = ""
        sql = ""
        
        if "EXPLANATION:" in full_response and "SQL:" in full_response:
            parts = full_response.split("SQL:")
            explanation = parts[0].replace("EXPLANATION:", "").strip()
            sql = parts[1].strip()
        else:
            # Fallback if format not followed
            sql = full_response
        
        # Clean up SQL
        sql = sql.replace('```sql', '').replace('```', '').strip().rstrip(';')
        
        # Remove any explanatory text before/after the SQL
        lines = sql.split('\n')
        sql_lines = []
        in_sql = False
        
        for line in lines:
            line_upper = line.strip().upper()
            if line_upper.startswith(('SELECT', 'WITH')):
                in_sql = True
            if in_sql:
                sql_lines.append(line)
            if line_upper.endswith(';'):
                break
        
        sql = '\n'.join(sql_lines).strip().rstrip(';')
        
        elapsed_time = time.time() - start_time
        return sql, elapsed_time, None, explanation
        
    except Exception as e:
        elapsed_time = time.time() - start_time
        return None, elapsed_time, str(e), None

def generate_sql_with_claude(user_query: str, schema_context: dict) -> tuple:
    """Use Claude to generate SQL from natural language"""
    
    if not anthropic_client:
        return None, 0, "Anthropic API key not configured", None
    
    start_time = time.time()
    
    schema_desc = format_schema_for_prompt(schema_context)
    
    try:
        response = anthropic_client.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=1000,
            temperature=0.1,
            system=f"""You are a SQL expert specializing in Trino SQL. Based on user questions, provide:
1. A brief explanation of your query approach (1 sentence)
2. The SQL query

{schema_desc}

Format your response exactly like this:
EXPLANATION: [one sentence explaining the query approach]
SQL:
[the SQL query without markdown or code blocks]

Always use schema.table format. Return only SELECT statements.""",
            messages=[
                {"role": "user", "content": user_query}
            ]
        )
        
        full_response = response.content[0].text.strip()
        
        # Parse explanation and SQL
        explanation = ""
        sql = ""
        
        if "EXPLANATION:" in full_response and "SQL:" in full_response:
            parts = full_response.split("SQL:")
            explanation = parts[0].replace("EXPLANATION:", "").strip()
            sql = parts[1].strip()
        else:
            sql = full_response
        
        # Clean up formatting
        sql = sql.replace('```sql', '').replace('```', '').strip().rstrip(';')
        
        elapsed_time = time.time() - start_time
        return sql, elapsed_time, None, explanation
        
    except Exception as e:
        elapsed_time = time.time() - start_time
        return None, elapsed_time, str(e), None

def execute_sql(sql: str) -> tuple:
    """Execute SQL query against Trino and return DataFrame with timing"""
    start_time = time.time()
    
    try:
        conn = get_trino_connection()
        cursor = conn.cursor()
        
        cursor.execute(sql)
        
        # Get column names
        columns = [desc[0] for desc in cursor.description] if cursor.description else []
        
        # Fetch results
        rows = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        elapsed_time = time.time() - start_time
        
        if rows:
            df = pd.DataFrame(rows, columns=columns)
        else:
            df = pd.DataFrame(columns=columns)
        
        return df, elapsed_time, None
        
    except TrinoUserError as e:
        elapsed_time = time.time() - start_time
        return None, elapsed_time, f"Trino Error: {str(e)}"
    except Exception as e:
        elapsed_time = time.time() - start_time
        return None, elapsed_time, f"Execution Error: {str(e)}"

# Sidebar
with st.sidebar:
    st.header("⚙️ Configuration")
    
# Backend selection with custom Claude icon
    st.markdown("**Select Backend:**")
    
    # Create clickable options with custom styling
    backend_mode = st.radio(
    "Select Backend:",
    ["🦙 Local Ollama", "🤖 Claude API", "⚖️ Compare Both"],
    index=0,  # Ollama as default
    help="Choose which AI backend to use for SQL generation"
)
    
    if backend_mode == "🦙 Local Ollama":
        st.caption("✅ Data stays on your Mac - GDPR compliant")
    
    st.divider()
    
    # Connection status
    st.subheader("🔌 Connection Status")
    
    col1, col2 = st.columns(2)
    
    with col1:
        if st.button("Test Trino", use_container_width=True):
            with st.spinner("Testing..."):
                success, message = test_trino_connection()
                if success:
                    st.success("✅ Connected")
                    st.session_state.connection_tested = True
                else:
                    st.error("❌ Failed")
                    st.error(message)
                    st.session_state.connection_tested = False
    
    with col2:
        # Check Ollama
        try:
            ollama.list()
            st.success("✅ Ollama OK")
        except:
            st.error("❌ Ollama Down")
            st.caption("Run: `ollama serve`")
    
    # Show connection details
    with st.expander("Connection Details"):
        st.code(f"Trino: {TRINO_HOST}:{TRINO_PORT}")
        st.code(f"Catalog: {TRINO_CATALOG}")
        st.code(f"Schema: {TRINO_SCHEMA}")
        st.code(f"Ollama: {OLLAMA_HOST}")
    
    st.divider()
    
    # Model information
    st.subheader("🤖 Models")
    st.text(f"Claude: {CLAUDE_MODEL[:25]}...")
    st.text(f"Ollama: {OLLAMA_MODEL}")
    
    st.divider()
    
    # Schema management
    st.subheader("📊 Schema")
    
    col1, col2 = st.columns(2)
    
    with col1:
        if st.button("🔄 Refresh", use_container_width=True):
            with st.spinner("Loading schema..."):
                schema = get_schema_context()
                if schema:
                    st.session_state.schema_context = schema
                    st.success(f"✅ Loaded")
    
    with col2:
        if st.session_state.schema_context:
            total_tables = sum(len(tables) for tables in st.session_state.schema_context.values())
            st.metric("Tables", total_tables)
    
    # Show schema summary
    if st.session_state.schema_context:
        with st.expander("Schema Summary"):
            for schema, tables in st.session_state.schema_context.items():
                st.write(f"**{schema}**: {len(tables)} tables")
    
    st.divider()
    
    # Statistics
    st.subheader("📈 Statistics")
    
    if st.session_state.comparison_history:
        total_queries = len(st.session_state.comparison_history)
        st.metric("Total Queries", total_queries)
        
        # Calculate averages
        claude_times = [q.get('claude_gen_time', 0) for q in st.session_state.comparison_history if 'claude_gen_time' in q]
        ollama_times = [q.get('ollama_gen_time', 0) for q in st.session_state.comparison_history if 'ollama_gen_time' in q]
        
        if claude_times:
            st.metric("Avg Claude Time", f"{sum(claude_times)/len(claude_times):.2f}s")
        if ollama_times:
            st.metric("Avg Ollama Time", f"{sum(ollama_times)/len(ollama_times):.2f}s")
        
        # Success rates
        claude_success = sum(1 for q in st.session_state.comparison_history if q.get('claude_success'))
        ollama_success = sum(1 for q in st.session_state.comparison_history if q.get('ollama_success'))
        
        if claude_times:
            st.metric("Claude Success", f"{(claude_success/len(claude_times)*100):.0f}%")
        if ollama_times:
            st.metric("Ollama Success", f"{(ollama_success/len(ollama_times)*100):.0f}%")
    
    st.divider()
    
    # Docker commands helper
    with st.expander("🐳 Docker Commands"):
        st.code("docker-compose ps", language="bash")
        st.code("docker-compose logs trino -f", language="bash")
        st.code("docker-compose restart trino", language="bash")
    
    st.divider()
    
    # Example queries
    st.subheader("💡 Example Queries")
    example_queries = [
        "Show me all tables in dbt_marts",
        "Count rows in each table",
        "Show the first 10 rows from customers",
        "What are the top 5 customers by revenue?",
        "Group sales by month for 2024"
    ]
    
    for example in example_queries:
        if st.button(example, key=f"example_{example}", use_container_width=True):
            st.session_state.example_query = example

# Main content
st.title("🗄️ Trino Query Assistant - Dual Mode")
st.caption("Compare Claude API vs Local Ollama for SQL generation")

# Load schema if not already loaded
if st.session_state.schema_context is None:
    with st.spinner("🔄 Loading schema information..."):
        schema = get_schema_context()
        if schema:
            st.session_state.schema_context = schema
            st.success("✅ Schema loaded successfully!")
        else:
            st.error("❌ Failed to load schema. Check Trino connection.")
            st.stop()

# Query input
user_query = st.chat_input("Ask a question about your data...") or st.session_state.get('example_query')

if user_query:
    # Clear example query
    if 'example_query' in st.session_state:
        del st.session_state.example_query
    
    st.subheader(f"📝 Query: *{user_query}*")
    st.divider()
    
    comparison_result = {
        "timestamp": datetime.now().isoformat(),
        "query": user_query
    }
    
    # Determine which backends to run
    run_claude = backend_mode in ["🤖 Claude API", "⚖️ Compare Both"]
    run_ollama = backend_mode in ["🦙 Local Ollama", "⚖️ Compare Both"]
    
    # Create columns based on mode
    if backend_mode == "⚖️ Compare Both":
        claude_col, ollama_col = st.columns(2)
    else:
        claude_col = ollama_col = st.container()
    
    # Claude API
    if run_claude:
        with claude_col:
            st.markdown("### 🤖 Claude API")
            
            with st.spinner("Generating SQL with Claude..."):
                claude_sql, claude_gen_time, claude_error, claude_explanation = generate_sql_with_claude(
                    user_query,
                    st.session_state.schema_context
                )
                
                if claude_error:
                    st.error(f"❌ Generation Error: {claude_error}")
                    comparison_result['claude_error'] = claude_error
                    comparison_result['claude_success'] = False
                else:
                    # Show explanation
                    if claude_explanation:
                        st.info(f"💭 {claude_explanation}")
                    
                    st.code(claude_sql, language="sql")
                    st.caption(f"⏱️ Generation: {claude_gen_time:.2f}s")
                    
                    comparison_result['claude_sql'] = claude_sql
                    comparison_result['claude_gen_time'] = claude_gen_time
                    comparison_result['claude_explanation'] = claude_explanation
                    
                    # Execute query
                    with st.spinner("Executing..."):
                        df, exec_time, exec_error = execute_sql(claude_sql)
                        
                        if exec_error:
                            st.error(f"❌ {exec_error}")
                            comparison_result['claude_exec_error'] = exec_error
                            comparison_result['claude_success'] = False
                        else:
                            st.dataframe(df, use_container_width=True)
                            st.success(f"✅ {len(df)} rows in {exec_time:.2f}s")
                            
                            comparison_result['claude_exec_time'] = exec_time
                            comparison_result['claude_rows'] = len(df)
                            comparison_result['claude_success'] = True
    
    # Local Ollama
    if run_ollama:
        with ollama_col:
            st.markdown("### 🦙 Local Ollama")
            
            with st.spinner(f"Generating SQL with {OLLAMA_MODEL}..."):
                ollama_sql, ollama_gen_time, ollama_error, ollama_explanation  = generate_sql_with_ollama(
                    user_query,
                    st.session_state.schema_context
                )
                
                if ollama_error:
                    st.error(f"❌ Generation Error: {ollama_error}")
                    comparison_result['ollama_error'] = ollama_error
                    comparison_result['ollama_success'] = False
                else:
                    # Show explanation
                    if ollama_explanation:
                        st.info(f"💭 {ollama_explanation}")

                    st.code(ollama_sql, language="sql")
                    st.caption(f"⏱️ Generation: {ollama_gen_time:.2f}s")
                    
                    comparison_result['ollama_sql'] = ollama_sql
                    comparison_result['ollama_gen_time'] = ollama_gen_time
                    comparison_result['ollama_explanation'] = ollama_explanation
                    
                    # Execute query
                    with st.spinner("Executing..."):
                        df, exec_time, exec_error = execute_sql(ollama_sql)
                        
                        if exec_error:
                            st.error(f"❌ {exec_error}")
                            comparison_result['ollama_exec_error'] = exec_error
                            comparison_result['ollama_success'] = False
                        else:
                            st.dataframe(df, use_container_width=True)
                            st.success(f"✅ {len(df)} rows in {exec_time:.2f}s")
                            
                            comparison_result['ollama_exec_time'] = exec_time
                            comparison_result['ollama_rows'] = len(df)
                            comparison_result['ollama_success'] = True
    
    # Save comparison
    st.session_state.comparison_history.append(comparison_result)
    
    # Comparison summary (only in Compare Both mode)
    if backend_mode == "⚖️ Compare Both" and 'claude_sql' in comparison_result and 'ollama_sql' in comparison_result:
        st.divider()
        st.markdown("### 📊 Comparison Summary")
        
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            if comparison_result.get('claude_gen_time') and comparison_result.get('ollama_gen_time'):
                faster = "Claude" if comparison_result['claude_gen_time'] < comparison_result['ollama_gen_time'] else "Ollama"
                st.metric(
                    "Faster Generation",
                    faster,
                    f"{abs(comparison_result['claude_gen_time'] - comparison_result['ollama_gen_time']):.2f}s"
                )
        
        with col2:
            sql_match = (
                comparison_result.get('claude_sql', '').strip().lower() ==
                comparison_result.get('ollama_sql', '').strip().lower()
            )
            st.metric("SQL Match", "✅ Yes" if sql_match else "❌ No")
        
        with col3:
            if comparison_result.get('claude_rows') is not None and comparison_result.get('ollama_rows') is not None:
                results_match = comparison_result['claude_rows'] == comparison_result['ollama_rows']
                st.metric("Results Match", "✅ Yes" if results_match else "❌ No")
        
        with col4:
            both_success = (
                comparison_result.get('claude_success', False) and
                comparison_result.get('ollama_success', False)
            )
            st.metric("Both Succeeded", "✅ Yes" if both_success else "❌ No")

# Query History
if st.session_state.comparison_history:
    st.divider()
    with st.expander("📜 Query History (Last 10)", expanded=False):
        for i, result in enumerate(reversed(st.session_state.comparison_history[-10:])):
            idx = len(st.session_state.comparison_history) - i
            st.markdown(f"**Query {idx}**: `{result['query']}`")
            
            cols = st.columns(4)
            
            if 'claude_gen_time' in result:
                with cols[0]:
                    status = "✅" if result.get('claude_success') else "❌"
                    st.caption(f"{status} Claude: {result['claude_gen_time']:.2f}s")
            
            if 'ollama_gen_time' in result:
                with cols[1]:
                    status = "✅" if result.get('ollama_success') else "❌"
                    st.caption(f"{status} Ollama: {result['ollama_gen_time']:.2f}s")
            
            if 'claude_rows' in result:
                with cols[2]:
                    st.caption(f"Claude: {result['claude_rows']} rows")
            
            if 'ollama_rows' in result:
                with cols[3]:
                    st.caption(f"Ollama: {result['ollama_rows']} rows")
            
            st.divider()
        
        # Export button
        if st.button("💾 Export History as JSON"):
            json_str = json.dumps(st.session_state.comparison_history, indent=2)
            st.download_button(
                label="Download JSON",
                data=json_str,
                file_name=f"query_history_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json",
                mime="application/json"
            )