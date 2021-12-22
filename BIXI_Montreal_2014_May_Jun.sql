
/*
About BIXI: BIXI Montréal is a non-profit organization created in 2014 by the city of Montreal to manage its bike-sharing system. 
The BIXI network has more than 9,000 bikes and 680 stations spread out across the areas of Montreal, Laval, Longueuil, Westmount, 
Town of Mount Royal and Montreal East.
Data is taken from Open Data available from bixi.com. From May-2014 to June 2014

*/

# Create database

CREATE SCHEMA IF NOT EXISTS BIXI_Montreal_open_data;

USE BIXI_Montreal_open_data;

# Create tables A. Stations, B. Trips

CREATE TABLE `bixi_montreal_open_data`.`stations` (
  `code` INT NOT NULL,
  `station_name` VARCHAR(55) NULL,
  `latitude` DOUBLE NULL,
  `longitude` DOUBLE NULL,
  PRIMARY KEY (`code`));
  
  CREATE TABLE `bixi_montreal_open_data`.`trips` (
  `start_date` VARCHAR(45) NOT NULL, # date is loaded as text first and then partitioned into date and time inside SQL
  `start_station_code` INT NOT NULL,
  `end_date` VARCHAR(45) NOT NULL,
  `end_station_code` INT NOT NULL,
  `duration_sec` INT NOT NULL,
  `is_member` TINYINT NOT NULL);

-- DROP TABLE trips;

# stations table imported with import wizard- Rows: 459
# trips table loaded with LOAD FILE command - Rows: 981124

LOAD DATA LOCAL INFILE '/Users/HP/Desktop/trips_2014-May-June.csv' INTO TABLE trips
FIELDS terminated by ','
LINES terminated by '\n'
IGNORE 1 ROWS
(start_date, start_station_code, end_date, end_station_code, duration_sec, is_member);

SELECT * FROM stations
LIMIT 5;

SELECT * FROM trips
LIMIT 5;

# Data cleaning

SELECT count(*) FROM trips;
SELECT count(*) FROM stations;

SELECT * FROM stations
WHERE code is null or station_name is null or latitude is null or longitude is null;

SELECT * FROM trips
WHERE start_date is null or start_station_code is null or end_date is null or
	end_station_code is null or duration_sec is null or is_member is null;

# There are no missing data

SELECT DISTINCT is_member FROM trips;

# is_member column has 1 for member and 0 for casual users

### DATA ANALYSIS section contains the following questions: 

### 1. How many total trips were made by members and casuals what is %membership?

SELECT DISTINCT
(SELECT count(is_member) FROM trips WHERE is_member=0) as casual_users,
(SELECT count(is_member) FROM trips WHERE is_member=1) as Members,
(SELECT count(is_member) FROM trips WHERE is_member=1)/count(is_member) as Percent_membership
FROM trips;

#Casual users: 124538, Members: 856586	
# 87% of the users are members

### 2. What is the average trip duration for members and casual users? What is the max trip duration for casual and member?

SELECT IF(is_member=0, 'Casual users', 'Members') as User_type, count(is_member) as Trips, 
round(avg(duration_sec)/60,1) as Avg_duration_minutes
FROM trips
GROUP BY is_member;

/* From the summary table, we find even though 87% of the trips are made by members, average trip duration of members is almost
 12 minutes and 30 seconds whereas casual members have trips of average 21 minutes.
 */
 

### 3. What is the total number of trips each month?

WITH month_table as (
SELECT month(str_to_date(start_date, "%m/%d/%Y")) as trip_month
FROM trips)

SELECT (CASE WHEN trip_month=5 THEN 'May' ELSE 'June' END) as trip_month, 
count(trip_month) as trip_count
FROM month_table
GROUP BY trip_month;

# May- 455,261 trips; June- 525,863 trips

### 4. What is the % increase of trips from May to June?

CREATE TEMPORARY TABLE trip_increase (
may_trips INT NULL,
june_trips INT NULL);

insert into trip_increase values(
455261, 525863);

SELECT *, round((june_trips-may_trips)/may_trips,3) as percent_increase_in_trips FROM trip_increase;

# There is 15.5% increase in trips from May to June month

-- drop temporary table user_increase;

### 5. Give the top 5 station names where trips are starting

SELECT t.start_station_code as Station_code, s.station_name, count(start_station_code) as num_trips,
 round((count(start_station_code)/981124)*100,2) as percent_of_total
FROM trips t
JOIN stations s
ON t.start_station_code= s.code
GROUp BY start_station_code
ORDER BY num_trips DESC
LIMIT 5;


###6. What is the usage ratio of members and casual users in weekdays and weekends?
# We use WEEKDAY(date) to get weekday. Here 0 is Monday and 6 is Sunday
# 0-4 are weekdays, 5 and 6 are weekends. 

WITH weekday_table AS (
	SELECT str_to_date(start_date,'%m/%d/%Y') AS start_date, 
		is_member, duration_sec 
	FROM trips)
SELECT IF(weekday(start_date)>4, "Weekend", "Weekdays") as week_day, 
IF(is_member=0, 'Casual users', 'Members') as User_type, 
count(is_member) as num_trips, 
IF(is_member=1, concat(round((count(is_member)/856586)*100),'%'), 
	concat(round((count(is_member)/124538)*100),'%')) as percent_usage
FROM weekday_table
GROUP BY User_type, week_day
ORDER BY User_type;

# Thus, from this we see that casual users use almost equally on weekdays and weekends whereas members use 75% of their trips on work days.

###7. What is the time where most number of trips are made?

WITH demo as (
SELECT  left(right(start_date, 5),2) as time_in_hours, right(right(start_date, 5),2) as time_in_min,
round((left(right(start_date, 5),2) + (right(right(start_date, 5),2)/60)),2) as hour_min,
count(is_member) as num_trips
FROM TRIPS
GROUP BY time_in_hours, time_in_min)
SELECT
(CASE WHEN hour_min between 0 and 6 THEN "12:00AM to 06:00AM" WHEN hour_min between 6 and 9 THEN "06:00AM to 09:00AM" 
	WHEN hour_min between 9 and 12 THEN "09:00AM to 12:00PM" WHEN hour_min between 12 and 16 THEN "12:00PM to 04:00PM"
    WHEN hour_min between 16 and 20 THEN "04:00PM to 08:00PM" ELSE "08:00PM to 12:00AM" END) as time_line,
sum(num_trips) as num_trips, round(sum(num_trips)/981124,2) as percent_trips
FROM demo
GROUP BY time_line;

# From this table, we understand that almost 55% of the trips take place between 12:00PM and 08:00PM due to lunch time travels and errands while 
#returning home

-------- END------------------