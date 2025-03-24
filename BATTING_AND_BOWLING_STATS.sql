
drop table if exists #df1 
select * into #df1 
From matches
where date >= '2010-01-01'
order by date desc;

drop table if exists #main_df 
select * into #main_df from #df1 a
left join deliveries b on a.id = b.match_id
order by date desc

select * from #main_df where id = '1426312' order by inning asc , [over] asc , ball asc 

--MAKING SOME ANAYLYSIS QUERIES  : 


CREATE OR ALTER PROCEDURE STATS_AGAINST_OPPONENT 

@PLAYER_NAME varchar(70) , @OPPONENT_TEAM varchar(70)

AS 
BEGIN

--PLAYER_NAME  |  OPPONENT    |  BATTING AVERAGE   |   BATTING STRIKERATE    |  WICKETS  | ECONOMY  | BOWLING_STRIKERATE 

WITH cte1 AS (
    SELECT 
        player_name, 
        opponent, 
        cast(AVG(score_that_day) as float) AS batting_average 
    FROM (
        SELECT DISTINCT 
            player_name, 
            opponent, 
            score_that_day, 
            match_date
        FROM (
            SELECT  
                batter AS player_name, 
                bowling_team AS opponent, 
                SUM(cast(batsman_runs as float)) OVER (PARTITION BY batter, date) AS score_that_day,  
                venue,  
                date AS match_date
            FROM #main_df 
            WHERE batter = @PLAYER_NAME 
             AND bowling_team = @OPPONENT_TEAM
        ) AS base
    ) AS cleaned_data
    GROUP BY player_name, opponent 
)



, cte2 as 
(select batter , bowling_team , (sum(cast(batsman_runs as float))/ count(*) )*100 as strike_rate 
From #main_df where batter = @PLAYER_NAME --and bowling_team = 'Punjab Kings'
group by batter , bowling_team 
)

, cte3 as (

select bowler  ,batting_team,count(*)/6 as overs_bowled, sum(total_runs) as runs_concedded 
, cast(sum(total_runs) as float)/cast((count(*)/6) as float ) as economy
from #main_df where bowler = @PLAYER_NAME 
and batting_team = @OPPONENT_TEAM  
--and date = '2023-04-09' 
 
group by bowler , batting_team
)

select a.player_name ,a.opponent ,a.batting_average , b.strike_rate , c.economy as bowling_economy 
from cte1 a left join cte2 b on a.player_name = b.batter and a.opponent = b.bowling_team
left join cte3 c on c.bowler = a.player_name and c.batting_team = a.opponent


END 

EXECUTE STATS_AGAINST_OPPONENT @PLAYER_NAME = 'RG Sharma', @OPPONENT_TEAM = 'Chennai Super Kings'

select * from #main_df where batter like '%SHARMA%'





--PROCEDURE THAT WILL GIVE ME HOW A BATTER HAS PERFORMED AGAINST A PARTICULAR BOWLER : 

CREATE OR ALTER PROCEDURE STATS_AGAINST_BOWLER_BY_VENUE @BATTER_NAME varchar(70), @BOWLER_NAME varchar(70)
AS 
BEGIN
select batter  , bowler , venue ,runs_scored , balls_faced, 
cast(runs_scored as float) /cast(balls_faced as float) *100 as strike_rate , got_out
,season 
from 
(
select batter , bowler ,venue ,sum(batsman_runs) as runs_scored ,
(select count(*) from #main_df b  where batter = @BATTER_NAME
and bowler  = @BOWLER_NAME
and is_wicket = 1 and b.venue = a.venue and b.season = a.season
) as got_out, (select count(*) from #main_df c  where batter = @BATTER_NAME
and bowler  = @BOWLER_NAME and (extras_type is null or extras_type = 'legbyes')
 and c.venue = a.venue and c.season = a.season ) as balls_faced , season
from
#main_df a where batter = @BATTER_NAME and bowler = @BOWLER_NAME
group by batter , bowler , venue , season
) inner_table
END			


execute  statS_against_bowler_by_venue @batter_name = 'Abhishek Sharma' , @bowler_name = 'CV Varun'

select 

