#!/usr/bin/env python3
"""
Trino MCP Server - Enables Claude to query your lakehouse
"""
import asyncio
from mcp.server import Server
from mcp.types import Tool, TextContent
import trino.dbapi
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Server("trino-lakehouse")

@app.list_tools()
async def list_tools() -> list[Tool]:
    """Define tools available to Claude"""
    return [
        Tool(
            name="query_trino",
            description="Execute SQL query on Trino lakehouse. Returns up to 20 rows.",
            inputSchema={
                "type": "object",
                "properties": {
                    "sql": {
                        "type": "string",
                        "description": "SQL query to execute (SELECT statements only)"
                    }
                },
                "required": ["sql"]
            }
        ),
        Tool(
            name="show_schemas",
            description="List all schemas in the lakehouse catalog",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        Tool(
            name="show_tables",
            description="List tables in a specific schema",
            inputSchema={
                "type": "object",
                "properties": {
                    "schema": {
                        "type": "string",
                        "description": "Schema name (e.g., dbt_marts, dbt_staging)"
                    }
                },
                "required": ["schema"]
            }
        )
    ]

@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    """Execute tool calls from Claude"""
    
    logger.info(f"Tool called: {name} with args: {arguments}")
    
    try:
        # Connect to Trino
        conn = trino.dbapi.connect(
            host='localhost',
            port=8080,
            user='admin',
            catalog='lakehouse',
            schema='dbt_marts'
        )
        cursor = conn.cursor()
        
        if name == "query_trino":
            sql = arguments["sql"]
            
            # Security: Only allow SELECT
            if not sql.strip().upper().startswith('SELECT'):
                return [TextContent(
                    type="text",
                    text="Error: Only SELECT queries are allowed"
                )]
            
            logger.info(f"Executing SQL: {sql}")
            cursor.execute(sql)
            rows = cursor.fetchall()
            columns = [desc[0] for desc in cursor.description] if cursor.description else []
            
            # Format results
            if not rows:
                result = "Query returned no rows"
            else:
                # Limit to 20 rows
                display_rows = rows[:20]
                result = f"Columns: {', '.join(columns)}\n\n"
                for row in display_rows:
                    result += f"{row}\n"
                
                if len(rows) > 20:
                    result += f"\n... and {len(rows) - 20} more rows (total: {len(rows)})"
            
            logger.info(f"Query returned {len(rows)} rows")
            return [TextContent(type="text", text=result)]
        
        elif name == "show_schemas":
            cursor.execute("SHOW SCHEMAS IN lakehouse")
            rows = cursor.fetchall()
            schemas = [row[0] for row in rows]
            result = "Schemas in lakehouse:\n" + "\n".join(schemas)
            logger.info(f"Found {len(schemas)} schemas")
            return [TextContent(type="text", text=result)]
        
        elif name == "show_tables":
            schema = arguments["schema"]
            cursor.execute(f"SHOW TABLES IN lakehouse.{schema}")
            rows = cursor.fetchall()
            tables = [row[0] for row in rows]
            result = f"Tables in lakehouse.{schema}:\n" + "\n".join(tables)
            logger.info(f"Found {len(tables)} tables in {schema}")
            return [TextContent(type="text", text=result)]
        
        else:
            return [TextContent(
                type="text",
                text=f"Unknown tool: {name}"
            )]
    
    except Exception as e:
        logger.error(f"Error: {str(e)}", exc_info=True)
        return [TextContent(
            type="text",
            text=f"Error: {str(e)}\n\nMake sure Trino is running: docker compose ps trino"
        )]

async def main():
    """Run the MCP server"""
    from mcp.server.stdio import stdio_server
    
    logger.info("Starting Trino MCP server...")
    
    async with stdio_server() as (read_stream, write_stream):
        await app.run(
            read_stream,
            write_stream,
            app.create_initialization_options()
        )

if __name__ == "__main__":
    asyncio.run(main())
