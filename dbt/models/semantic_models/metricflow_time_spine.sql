{{
    config(
        materialized='table',
        meta={
            'metricflow': {
                'time_spine': {
                    'standard_granularity_column': 'date_day'
                }
            }
        }
    )
}}

WITH date_spine AS (
    {{ dbt.date_spine(
        datepart="day",
        start_date="cast('2020-01-01' as date)",
        end_date="cast('2030-12-31' as date)"
    ) }}
)

SELECT
    date_day AS date_day
FROM date_spine
