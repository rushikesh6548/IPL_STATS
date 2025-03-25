drop table if exists #df1 
select * into #df1 
From matches
--where date >= '2010-01-01'
order by date desc;


drop table if exists #main_df 
select * into #main_df from #df1 a
left join deliveries b on a.id = b.match_id
order by date desc

select * from #main_df
order by season desc, date desc

with batting_stats as 
(select match_id,season,venue,batter , sum(batsman_runs) as batsmen_runs,batting_team as batsman_team , 
rank() over(partition by match_id  order by id desc ) as rnk

from #main_df 
where match_id = '1426311'
group by id,venue,batter ,batting_team,match_id,season
), bowling_stats AS 
(select match_id,venue,bowler ,season, count(*) as bowler_wickets,bowling_team , 
rank() over(partition by match_id  order by id desc ) as rnk
from #main_df 
where match_id = '1426311' and is_wicket = 1 
group by id,venue,bowler,match_id,bowling_team,season), 
player_base as 
(select distinct match_id , venue , season,batter as players ,batting_team as team  from #main_df where match_id = '1426311'
union 
select distinct match_id , venue , season,bowler as players ,bowling_team as team  from #main_df where match_id = '1426311')

select a.match_id , a.venue , a.season , a.players as player_name , a.team as player_team 
, b.batsmen_runs as player_runs ,c.bowler_wickets as player_wicket
From player_base a 
left join batting_stats b on a.match_id = b.match_id and a.season = b.season and a.players = b.batter
left join bowling_stats c on a.match_id = c.match_id and a.season = c.season and a.players = c.bowler



DROP TABLE IF EXISTS #FINAL_TABLE
WITH batting_stats AS (
    SELECT 
        match_id,
        season,
        venue,
        batter AS player_name,
        batting_team AS player_team,
        SUM(batsman_runs) AS runs_scored
    FROM #main_df
    GROUP BY match_id, season, venue, batter, batting_team
),
bowling_stats AS (
    SELECT 
        match_id,
        season,
        venue,
        bowler AS player_name,
        bowling_team AS player_team,
        COUNT(*) AS wickets_taken
    FROM #main_df
    WHERE is_wicket = 1 AND dismissal_kind NOT IN ('run out')
    GROUP BY match_id, season, venue, bowler, bowling_team
),
catch_stats AS (
    SELECT 
        match_id,
        season,
        venue,
        fielder AS player_name,
        COUNT(*) AS catches_taken
    FROM #main_df
    WHERE dismissal_kind = 'caught' 
    GROUP BY match_id, season, venue, fielder 
),
runout_stats AS (
    SELECT 
        match_id,
        season,
        venue,
        fielder AS player_name,
        COUNT(*) AS runouts
    FROM #main_df
    WHERE dismissal_kind = 'run out'
    GROUP BY match_id, season, venue, fielder 
),
player_base AS (
    SELECT DISTINCT match_id, season, venue, batter AS player_name, batting_team AS player_team, bowling_team AS opponent_team
    FROM #main_df
    UNION
    SELECT DISTINCT match_id, season, venue, bowler AS player_name, bowling_team AS player_team, batting_team AS opponent_team
    FROM #main_df
),
-- Calculate Historical Averages for Last 5 Matches
historical_stats AS (
    SELECT 
        p.player_name,
        p.venue,
        p.match_id,
        -- Average Runs Last 5 Matches
        AVG(cast(b.runs_scored as float)) OVER (
            PARTITION BY p.player_name 
            ORDER BY p.match_id 
            ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING
        ) AS avg_runs_last_5,
        -- Average Runs Last 5 Matches at Same Venue
        
        -- Average Wickets Last 5 Matches
        AVG(cast(w.wickets_taken as float)) OVER (
            PARTITION BY p.player_name 
            ORDER BY p.match_id 
            ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING
        ) AS avg_wickets_last_5
        -- Average Wickets Last 5 Matches at Same Venue
        
    FROM player_base p
    LEFT JOIN batting_stats b ON p.match_id = b.match_id AND p.player_name = b.player_name
    LEFT JOIN bowling_stats w ON p.match_id = w.match_id AND p.player_name = w.player_name
),avg_runs_last_5_at_venue as (
SELECT 
    t.player, 
    t.team, 
    t.venue, 
    AVG(cast(b.runs_scored as float)) AS last_5_matches_avg_at_that_venue
FROM (
    SELECT distinct batter AS player, batting_team AS team, venue, match_id, 
           dense_rank() OVER (PARTITION BY batter, venue ORDER BY match_id DESC) AS rn
    FROM #main_df 
) t
JOIN (
    SELECT batter, match_id, SUM(cast(batsman_runs as float)) AS runs_scored
    FROM #main_df 
    GROUP BY batter, match_id 
) b ON t.player = b.batter AND t.match_id = b.match_id
WHERE t.rn <= 5  --and t.player = 'H Klaasen' and t.venue = 'Rajiv Gandhi International Stadium, Uppal, Hyderabad'
GROUP BY t.player, t.team, t.venue)




,avg_wickets_last_5_at_venue as (
SELECT 
    t.player, 
    t.team, 
    t.venue, 
    AVG(cast(b.wickets_taken as float)) AS last_5_matches_avg_at_that_venue 
FROM (
    SELECT distinct bowler AS player, bowling_team AS team, venue, match_id, 
           dense_rank() OVER (PARTITION BY bowler, venue ORDER BY match_id DESC) AS rn
    FROM #main_df 
) t
JOIN (
    SELECT bowler, match_id, count(is_wicket) AS wickets_taken
    FROM #main_df  where is_wicket = '1'
    GROUP BY bowler, match_id 
) b ON t.player = b.bowler AND t.match_id = b.match_id
WHERE t.rn <= 5 
GROUP BY t.player, t.team, t.venue)
 
 

SELECT 
    p.match_id,
    p.season,
    p.venue,
    p.player_name,
    COALESCE(p.player_team, '') AS player_team,
    p.opponent_team AS opponent_team,
    b.runs_scored AS runs_scored,
    wickets_taken AS wickets_taken,
    catches_taken AS catches_taken,
    runouts AS runouts,
    -- Historical Averages
    avg_runs_last_5 AS avg_runs_last_5,
   x.last_5_matches_avg_at_that_venue AS avg_runs_last_5_venue,
    avg_wickets_last_5 AS avg_wickets_last_5,
x.last_5_matches_avg_at_that_venue AS avg_wickets_last_5_venue,
    -- Fantasy Points Calculation
    (COALESCE(w.wickets_taken, 0) * 25) + 
    (COALESCE(b.runs_scored, 0) * 2) + 
    (COALESCE(c.catches_taken, 0) * 4) + 
    (COALESCE(r.runouts, 0) * 4) AS fantasy_points into #FINAL_TABLE
FROM player_base p
LEFT JOIN batting_stats b ON p.match_id = b.match_id AND p.player_name = b.player_name
LEFT JOIN bowling_stats w ON p.match_id = w.match_id AND p.player_name = w.player_name
LEFT JOIN catch_stats c ON p.match_id = c.match_id AND p.player_name = c.player_name
LEFT JOIN runout_stats r ON p.match_id = r.match_id AND p.player_name = r.player_name
LEFT JOIN historical_stats h ON p.match_id = h.match_id AND p.player_name = h.player_name
left join avg_runs_last_5_at_venue x on x.player = p.player_name and x.team = p.player_team and x.venue = p.venue 
left join avg_wickets_last_5_at_venue y on y.player = p.player_name and y.team = p.player_team and y.venue = p.venue
--WHERE p.match_id = '1426311' and p.player_name = 'H Klaasen'
ORDER BY p.player_name,fantasy_points DESC;


UPDATE #FINAL_TABLE
SET venue = 
    CASE 
        WHEN venue IN ('Rajiv Gandhi International Stadium, Uppal, Hyderabad', 'Rajiv Gandhi International Stadium, Uppal') 
            THEN 'Rajiv Gandhi International Stadium'
        WHEN venue IN ('MA Chidambaram Stadium, Chepauk, Chennai', 'MA Chidambaram Stadium, Chepauk') 
            THEN 'MA Chidambaram Stadium'
        WHEN venue IN ('M Chinnaswamy Stadium, Bengaluru', 'M Chinnaswamy Stadium') 
            THEN 'M. Chinnaswamy Stadium'
        WHEN venue IN ('Eden Gardens, Kolkata', 'Eden Gardens') 
            THEN 'Eden Gardens'
        WHEN venue IN ('Arun Jaitley Stadium, Delhi', 'Feroz Shah Kotla', 'Arun Jaitley Stadium') 
            THEN 'Arun Jaitley Stadium'
        WHEN venue IN ('Punjab Cricket Association IS Bindra Stadium, Mohali', 
                       'Punjab Cricket Association IS Bindra Stadium, Mohali, Chandigarh', 
                       'Punjab Cricket Association Stadium, Mohali') 
            THEN 'Punjab Cricket Association IS Bindra Stadium'
        WHEN venue IN ('Wankhede Stadium, Mumbai') 
            THEN 'Wankhede Stadium'
        WHEN venue IN ('Dr DY Patil Sports Academy, Mumbai') 
            THEN 'Dr DY Patil Sports Academy'
        WHEN venue IN ('Brabourne Stadium, Mumbai') 
            THEN 'Brabourne Stadium'
        WHEN venue IN ('Himachal Pradesh Cricket Association Stadium, Dharamsala') 
            THEN 'Himachal Pradesh Cricket Association Stadium'
        WHEN venue IN ('Shaheed Veer Narayan Singh International Stadium, Raipur') 
            THEN 'Shaheed Veer Narayan Singh International Stadium'
        WHEN venue IN ('Maharashtra Cricket Association Stadium, Pune') 
            THEN 'Maharashtra Cricket Association Stadium'
        ELSE venue  -- Keep the original name if not in the list
    END;

	update #FINAL_TABLE set venue = 'St Georges Park' where venue like '%St George%'


UPDATE #FINAL_TABLE 
SET pitch_nature = CASE 
    WHEN venue IN ('Holkar Cricket Stadium, Indore', 
                   'M. Chinnaswamy Stadium, Bengaluru',
                   'Rajiv Gandhi International Cricket Stadium, Dehradun',
                   'Wankhede Stadium, Mumbai',
                   'Punjab Cricket Association IS Bindra Stadium, Mohali',
                   'Maharashtra Cricket Association Stadium, Pune',
                   'Dr DY Patil Sports Academy, Mumbai',
                   'Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium, Visakhapatnam',
                   'Sharjah Cricket Stadium',
                   'New Wanderers Stadium, Johannesburg',
                   'SuperSport Park, Centurion',
                   'Brabourne Stadium, Mumbai') 
        THEN 'Batting-friendly'
    
    WHEN venue IN ('MA Chidambaram Stadium, Chennai',
                   'Arun Jaitley Stadium, Delhi',
                   'Green Park, Kanpur',
                   'Himachal Pradesh Cricket Association Stadium, Dharamsala',
                   'JSCA International Stadium Complex, Ranchi',
                   'Dubai International Cricket Stadium',
                   'St Georges Park, Gqeberha',
                   'Kingsmead, Durban') 
        THEN 'Bowling-friendly'
    
    ELSE 'Balanced'
END;



select match_id , season , venue , player_name , player_team , opponent_team ,avg_runs_last_5 as avg_runs_last_5_innings,
avg_runs_last_5_venue as avg_runs_last_5_innings_at_that_venue,
avg_wickets_last_5 ,avg_wickets_last_5_venue as avg_wickets_last_5_innings_at_that_venue, fantasy_points

from #FINAL_TABLE where season not in ('2013',
'2012',
'2011',
'2009/10',
'2009',
'2007/08') order by match_id
