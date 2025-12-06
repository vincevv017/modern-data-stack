cube('Orders', {
  sql: `SELECT * FROM lakehouse.dbt_marts.fct_orders`,
  
  measures: {
    // ========== REVENUE METRICS ==========
    totalRevenue: {
      sql: `revenue`,
      type: `sum`,
      format: `currency`,
      description: 'Total revenue from all orders'
    },
    
    avgOrderValue: {
      sql: `revenue`,
      type: `avg`,
      format: `currency`,
      description: 'Average order value'
    },
    
    // ========== BEHAVIORAL METRICS FROM LAKEHOUSE ==========
    totalPageViews: {
      sql: `customer_page_views`,
      type: `sum`,
      description: 'Total page views from lakehouse data'
    },
    
    totalCartAdds: {
      sql: `customer_cart_adds`,
      type: `sum`,
      description: 'Total items added to cart'
    },
    
    totalPurchases: {
      sql: `customer_purchases`,
      type: `sum`,
      description: 'Total purchase events'
    },
    
    // ========== COMPLEX CALCULATED METRICS ==========
    
    conversionRate: {
      sql: `
        CASE 
          WHEN SUM(${CUBE}.customer_page_views) > 0 
          THEN (CAST(SUM(${CUBE}.customer_purchases) AS DOUBLE) / CAST(SUM(${CUBE}.customer_page_views) AS DOUBLE)) * 100
          ELSE 0 
        END
      `,
      type: `number`,
      format: `percent`,
      description: 'Purchase conversion rate'
    },
    
    cartConversionRate: {
      sql: `
        CASE 
          WHEN SUM(${CUBE}.customer_cart_adds) > 0 
          THEN (CAST(SUM(${CUBE}.customer_purchases) AS DOUBLE) / CAST(SUM(${CUBE}.customer_cart_adds) AS DOUBLE)) * 100
          ELSE 0 
        END
      `,
      type: `number`,
      format: `percent`,
      description: 'Cart to purchase conversion'
    },
    
    revenuePerPageView: {
      sql: `
        CASE 
          WHEN SUM(${CUBE}.customer_page_views) > 0 
          THEN SUM(${CUBE}.revenue) / NULLIF(SUM(${CUBE}.customer_page_views), 0)
          ELSE 0 
        END
      `,
      type: `number`,
      format: `currency`,
      description: 'Revenue per page view'
    },
    
    // ========== SUSTAINABILITY METRICS ==========
    
    avgSustainabilityScore: {
      sql: `sustainability_score`,
      type: `avg`,
      format: `number`,
      description: 'Average sustainability score'
    },
    
    sustainableRevenue: {
      sql: `CASE WHEN sustainability_score >= 80 THEN revenue ELSE 0 END`,
      type: `sum`,
      format: `currency`,
      description: 'Revenue from sustainable suppliers'
    },
    
    sustainableRevenuePercent: {
      sql: `
        CASE 
          WHEN SUM(${CUBE}.revenue) > 0 
          THEN (SUM(CASE WHEN ${CUBE}.sustainability_score >= 80 THEN ${CUBE}.revenue ELSE 0 END) / SUM(${CUBE}.revenue)) * 100
          ELSE 0 
        END
      `,
      type: `number`,
      format: `percent`,
      description: 'Percent revenue from sustainable suppliers'
    },
    
    // ========== COUNT METRICS ==========
    
    orderCount: {
      sql: `order_id`,
      type: `count`,
      description: 'Number of orders'
    },
    
    customerCount: {
      sql: `customer_id`,
      type: `countDistinct`,
      description: 'Unique customers'
    },
    
    ordersPerCustomer: {
      sql: `COUNT(${CUBE}.order_id) / NULLIF(COUNT(DISTINCT ${CUBE}.customer_id), 0)`,
      type: `number`,
      description: 'Orders per customer'
    }
  },
  
  dimensions: {
    orderId: {
      sql: `order_id`,
      type: `number`,
      primaryKey: true
    },
    
    customerId: {
      sql: `customer_id`,
      type: `number`
    },
    
    // ========== TIME DIMENSION (CAST DATE TO TIMESTAMP) ==========
    
    orderDate: {
      sql: `CAST(order_date AS TIMESTAMP)`,
      type: `time`
    },
    
    // ========== PRODUCT DIMENSIONS ==========
    
    productName: {
      sql: `product_name`,
      type: `string`
    },
    
    productCategory: {
      sql: `product_category`,
      type: `string`
    },
    
    // ========== SUPPLIER DIMENSIONS ==========
    
    supplierName: {
      sql: `supplier_name`,
      type: `string`
    },
    
    supplierCountry: {
      sql: `supplier_country`,
      type: `string`
    },
    
    // ========== SEGMENTS ==========
    
    sustainabilityTier: {
      sql: `
        CASE 
          WHEN sustainability_score >= 85 THEN 'Excellent'
          WHEN sustainability_score >= 70 THEN 'Good'
          WHEN sustainability_score >= 50 THEN 'Fair'
          ELSE 'Needs Improvement'
        END
      `,
      type: `string`
    },
    
    revenueSegment: {
      sql: `
        CASE 
          WHEN revenue >= 500 THEN 'High Value'
          WHEN revenue >= 100 THEN 'Medium Value'
          ELSE 'Low Value'
        END
      `,
      type: `string`
    }
  },
  
  // ========== PRE-AGGREGATIONS ==========
  
  preAggregations: {
    // Monthly rollup by country and category
    monthlyRollup: {
      type: `rollup`,
      measures: [
        totalRevenue,
        orderCount,
        totalPageViews,
        totalCartAdds,
        avgSustainabilityScore
      ],
      dimensions: [
        supplierCountry,
        productCategory
      ],
      timeDimension: orderDate,
      granularity: `month`,
      refreshKey: {
        every: `1 hour`
      }
    },
    
    // Conversion metrics
    conversionMetrics: {
      type: `rollup`,
      measures: [
        totalPageViews,
        totalCartAdds,
        totalPurchases,
        orderCount
      ],
      dimensions: [
        productName,
        supplierCountry
      ],
      refreshKey: {
        every: `30 minutes`
      }
    }
  }
});
