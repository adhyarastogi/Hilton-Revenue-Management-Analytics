-- creating a new database
CREATE DATABASE hilton_revenue_analytics;
SHOW DATABASES;

USE hilton_revenue_analytics;

-- creating tables
-- booking
CREATE TABLE bookings (
    Reservation_ID VARCHAR(20),
    Booking_Date DATE,
    Check_In_Date DATE,
    Check_Out_Date DATE,
    Booking_Window_Days INT,
    Room_Type VARCHAR(50),
    Booking_Channel VARCHAR(50),
    Customer_Segment VARCHAR(50),
    Country VARCHAR(50),
    Loyalty_Status VARCHAR(50),
    Length_of_Stay INT,
    Cancelled INT,
    Room_Rate DECIMAL(10,2),
    Total_Revenue DECIMAL(10,2),
    Adults INT,
    Children INT,
    Revenue_Per_Night DECIMAL(10,2),
    Booking_Month VARCHAR(20),
    Check_In_Month VARCHAR(20),
    Stay_Category VARCHAR(30)
);

-- hotel_kpi_daily
CREATE TABLE hotel_kpi_daily (
    Date DATE,
    Available_Rooms INT,
    Season VARCHAR(50),
    Demand_Level VARCHAR(50),
    Occupancy_Rate DECIMAL(5,3),
    Occupied_Rooms INT,
    ADR DECIMAL(10,2),
    Room_Revenue DECIMAL(12,2),
    RevPAR DECIMAL(10,2),
    Month VARCHAR(20),
    Year INT,
    Calculated_RevPAR DECIMAL(10,2)
);

-- competitor_pricing
CREATE TABLE competitor_pricing (
    Date DATE,
    Competitor_Hotel VARCHAR(100),
    Room_Type VARCHAR(50),
    Competitor_ADR DECIMAL(10,2),
    Hilton_ADR DECIMAL(10,2),
    ADR_Gap DECIMAL(10,2),
    Market_Position VARCHAR(50),
    Market_Average_ADR DECIMAL(10,2),
    Pricing_Index DECIMAL(5,3)
);

-- market events
CREATE TABLE market_events (
    Event_ID VARCHAR(20),
    Date DATE,
    Event_Name VARCHAR(100),
    Event_Type VARCHAR(50),
    Expected_Demand VARCHAR(50),
    Event_Month VARCHAR(20)
);

-- guest_reviews
CREATE TABLE guest_reviews (
    Review_ID VARCHAR(20),
    Reservation_ID VARCHAR(20),
    Review_Date DATE,
    Rating INT,
    Sentiment VARCHAR(20),
    Review_Category VARCHAR(50),
    Comments TEXT,
    Review_Month VARCHAR(20),
    Rating_Category VARCHAR(30)
);

USE hilton_revenue_analytics;

SHOW TABLES;

-- =====================================================
-- MODULE 1: REVENUE PERFORMANCE ANALYSIS
-- =====================================================

-- Q1. Which room types generate the highest revenue and contribute most to profitability?

SELECT Room_Type,
    COUNT(Reservation_ID) AS Total_Bookings,
    ROUND(SUM(Total_Revenue),2) AS Total_Revenue,
    ROUND(AVG(Room_Rate),2) AS Average_Room_Rate,
    ROUND(
        SUM(Total_Revenue) * 100 /
        (SELECT SUM(Total_Revenue)
         FROM bookings
         WHERE Cancelled = 0),
        2
    ) AS Revenue_Contribution_Percentage
FROM bookings
WHERE Cancelled = 0
GROUP BY Room_Type
ORDER BY Total_Revenue DESC;

-- Q2. How does hotel revenue performance change by month and season?

SELECT MONTHNAME(Date) AS Revenue_Month,
    Season,
    ROUND(AVG(Occupancy_Rate)*100,2) AS Average_Occupancy_Percentage,
    ROUND(AVG(ADR),2) AS Average_ADR,
    ROUND(SUM(Room_Revenue),2) AS Total_Revenue,
    ROUND(AVG(RevPAR),2) AS Average_RevPAR
FROM hotel_kpi_daily
GROUP BY
    MONTHNAME(Date),
    Season
ORDER BY Total_Revenue DESC;

-- =====================================================
-- MODULE 2: PRICING STRATEGY & DEMAND OPTIMIZATION
-- =====================================================

-- Q3. During which periods should Hilton increase or decrease room prices?

SELECT Season,
    Demand_Level,
    ROUND(AVG(Occupancy_Rate)*100,2) AS Average_Occupancy_Percentage,
    ROUND(AVG(ADR),2) AS Average_ADR,
    ROUND(AVG(RevPAR),2) AS Average_RevPAR,
    COUNT(*) AS Number_of_Days,
    CASE
        WHEN AVG(Occupancy_Rate) >= 0.80
             AND Demand_Level IN ('High','Very High')
        THEN 'Increase ADR Opportunity'
        WHEN AVG(Occupancy_Rate) <= 0.50
             AND Demand_Level = 'Low'
        THEN 'Discount / Promotion Opportunity'
        ELSE 'Maintain Pricing Strategy'
    END AS Pricing_Strategy
FROM hotel_kpi_daily
GROUP BY
    Season,
    Demand_Level
ORDER BY
    Average_Occupancy_Percentage DESC;
    
    -- Q4. What is the relationship between occupancy rate and ADR?

SELECT
    CASE
        WHEN Occupancy_Rate < 0.50 THEN 'Low Occupancy'
        WHEN Occupancy_Rate BETWEEN 0.50 AND 0.75 
        THEN 'Medium Occupancy'
        ELSE 'High Occupancy'
    END AS Occupancy_Category,
    ROUND(AVG(Occupancy_Rate)*100,2) AS Average_Occupancy_Percentage,
    ROUND(AVG(ADR),2) AS Average_ADR,
    ROUND(AVG(RevPAR),2) AS Average_RevPAR,
    COUNT(*) AS Number_of_Days
FROM hotel_kpi_daily
GROUP BY Occupancy_Category
ORDER BY Average_Occupancy_Percentage;

-- =====================================================
-- MODULE 3: COMPETITIVE MARKET ANALYSIS
-- =====================================================

-- Q5. How does Hilton's ADR compare against competitors?

SELECT Competitor_Hotel,
    ROUND(AVG(Competitor_ADR),2) AS Average_Competitor_ADR,
    ROUND(AVG(Hilton_ADR),2) AS Average_Hilton_ADR,
    ROUND(
        AVG(Hilton_ADR - Competitor_ADR), 2
    ) AS Average_Price_Difference,
    CASE
        WHEN AVG(Hilton_ADR - Competitor_ADR) > 0
        THEN 'Hilton Priced Higher'
        WHEN AVG(Hilton_ADR - Competitor_ADR) < 0
        THEN 'Hilton Priced Lower'
        ELSE 'Market Aligned'
    END AS Hilton_Position
FROM competitor_pricing
GROUP BY Competitor_Hotel
ORDER BY Average_Price_Difference;

-- Q6. Which room categories have the biggest pricing opportunities compared to competitors?

SELECT Room_Type,
    ROUND(AVG(Competitor_ADR),2) AS Average_Competitor_ADR,
    ROUND(AVG(Hilton_ADR),2) AS Average_Hilton_ADR,
    ROUND(AVG(Competitor_ADR - Hilton_ADR), 2) AS Pricing_Gap,
    CASE
        WHEN AVG(Competitor_ADR - Hilton_ADR) > 25
        THEN 'Increase ADR Opportunity'
        WHEN AVG(Competitor_ADR - Hilton_ADR) < -25
        THEN 'Hilton Already Premium Priced'
        ELSE 'Market Competitive'
    END AS Pricing_Action
FROM competitor_pricing
GROUP BY Room_Type
ORDER BY Pricing_Gap DESC;

-- =====================================================
-- MODULE 4: MARKET EVENTS & DEMAND FORECASTING
-- =====================================================

-- Q7. Do major events increase hotel demand?

SELECT e.Event_Name,
    e.Event_Type,
    e.Expected_Demand,
    ROUND(AVG(h.Occupancy_Rate)*100,2) AS Average_Occupancy_Percentage,
    ROUND(AVG(h.ADR),2) AS Average_ADR,
    ROUND(AVG(h.RevPAR),2) AS Average_RevPAR,
    COUNT(h.Date) AS Event_Days
FROM market_events e
JOIN hotel_kpi_daily h
ON e.Date = h.Date
GROUP BY
    e.Event_Name,
    e.Event_Type,
    e.Expected_Demand
HAVING Event_Days >= 2
ORDER BY Average_Occupancy_Percentage DESC;

-- Q8. Which events should Hilton prioritize for revenue optimization?

SELECT e.Event_Name,
    ROUND(SUM(h.Room_Revenue),2) AS Total_Revenue,
    ROUND(AVG(h.Occupancy_Rate)*100,2) AS Average_Occupancy_Percentage,
    ROUND(AVG(h.ADR),2) AS Average_ADR,
    ROUND(AVG(h.RevPAR),2) AS Average_RevPAR,
    COUNT(h.Date) AS Event_Days,
    CASE
        WHEN AVG(h.Occupancy_Rate) >= 0.85
             AND AVG(h.ADR) >= 400
        THEN 'High Revenue Opportunity'
        WHEN AVG(h.Occupancy_Rate) >= 0.70
        THEN 'Moderate Revenue Opportunity'
        ELSE 'Low Revenue Opportunity'
    END AS Revenue_Category
FROM market_events e
JOIN hotel_kpi_daily h
ON e.Date = h.Date
GROUP BY
    e.Event_Name
ORDER BY Total_Revenue DESC;

-- =====================================================
-- MODULE 5: GUEST EXPERIENCE & REVENUE IMPACT
-- =====================================================

-- Q9. What guest experience factors impact satisfaction the most?

SELECT Review_Category,
    COUNT(Review_ID) AS Total_Reviews,
    ROUND(AVG(Rating),2) AS Average_Rating,
    SUM(
        CASE 
            WHEN Sentiment = 'Positive' 
            THEN 1 
            ELSE 0 
        END
    ) AS Positive_Reviews,
    SUM(
        CASE 
            WHEN Sentiment = 'Negative' 
            THEN 1 
            ELSE 0 
        END
    ) AS Negative_Reviews,
    ROUND((SUM(
            CASE 
                WHEN Sentiment='Positive'
                THEN 1
                ELSE 0
            END
        ) 
        /
        COUNT(Review_ID))*100, 2) AS Positive_Sentiment_Percentage
FROM guest_reviews
GROUP BY Review_Category
ORDER BY Average_Rating DESC;

-- Q10. Does guest satisfaction influence booking value?

SELECT gr.Sentiment,
    ROUND(AVG(gr.Rating),2) AS Average_Rating,
    COUNT(gr.Review_ID) AS Total_Reviews,
    ROUND(AVG(b.Total_Revenue),2) AS Average_Booking_Revenue,
    ROUND(AVG(b.Length_of_Stay),2) AS Average_Length_of_Stay,
    ROUND(SUM(b.Total_Revenue), 2) AS Total_Revenue_Generated
FROM guest_reviews gr
JOIN bookings b
ON gr.Reservation_ID = b.Reservation_ID
GROUP BY gr.Sentiment
ORDER BY Average_Booking_Revenue DESC;