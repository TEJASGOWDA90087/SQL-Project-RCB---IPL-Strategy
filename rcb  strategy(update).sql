-- OBJECTIVE QUESTIONS

-- 1.	List the different dtypes of columns in table “ball_by_ball” (using information schema)

SELECT 
    COLUMN_NAME, DATA_TYPE
FROM
    information_schema.columns
WHERE
    TABLE_NAME = 'ball_by_ball';
    

-- 2.What is the total number of run scored in 1st season by RCB? (bonus : also include the extra runs using the extra runs table)
WITH extra_run_data AS (

SELECT

Team_Batting AS team_Id,

SUM(e.Extra_Runs) as total_extra

FROM ball_by_ball b

JOIN extra_runs e ON e.Match_Id = b.Match_Id AND e.Innings_No = b.Innings_No AND e.Over_Id = b.Over_Id AND e.Ball_Id = b.Ball_Id

WHERE Team_Batting = 2

AND b.Match_Id IN(

SELECT distinct Match_Id FROM matches WHERE Season_Id = ( SELECT MIN(Season_Id) as first_season FROM Matches WHERE Team_1 = 2 OR Team_2 = 2))

),

run_scored_data AS (

SELECT
Team_Batting AS team_Id,
SUM(b.Runs_Scored) AS total_score
FROM ball_by_ball b
JOIN matches m ON m.Match_Id = b.Match_Id
WHERE Team_Batting = 2 AND (Team_1 = 2 OR Team_2 = 2) AND m.Season_Id = ( SELECT MIN(Season_Id) as first_season FROM Matches WHERE Team_1 = 2 OR Team_2 = 2)

)

SELECT
(total_score + total_extra) AS total_runs
FROM run_scored_data s
JOIN extra_run_data e ON e.team_Id = s.team_Id;

-- 3. How many players were more than the age of 25 during season 2014?
select count(distinct pm.Player_id ) as Older_Than_25
from  Matches m 
join Player_Match pm on m.Match_ID = pm.Match_ID
join Player p on pm.Player_Id = p.Player_Id
where m.Season_Id = 7
and timestampdiff(Year, p.DOB, m.Match_Date) > 25;

-- 4..How many matches did RCB win in 2013? 
SELECT COUNT(*) AS Matches_Won
FROM Matches m
JOIN Season s ON m.Season_Id = s.Season_Id
JOIN Team t ON m.Match_Winner = t.Team_Id
WHERE s.Season_Year = 2013
AND t.Team_Name = 'Royal Challengers Bangalore'
AND m.Match_Winner IS NOT NULL;

-- 5.List the top 10 players according to their strike rate in the last 4 seasons
WITH Last_4_Seasons AS (
    SELECT Season_Year FROM Season ORDER BY Season_Year DESC LIMIT 4
),
Striker_Rate AS (
    SELECT 
        B.Striker, 
        ROUND((SUM(B.Runs_Scored) / NULLIF(COUNT(B.Ball_Id), 0)) * 100, 2) AS Strike_Rate
    FROM Ball_by_Ball B
    JOIN Matches M ON B.Match_Id = M.Match_Id
    JOIN Season S ON M.Season_Id = S.Season_Id
    JOIN Last_4_Seasons L4S ON S.Season_Year = L4S.Season_Year
    GROUP BY B.Striker
    HAVING COUNT(B.Ball_Id) > 100
)
SELECT 
    RANK() OVER (ORDER BY SR.Strike_Rate DESC) AS Ranking,
    P.Player_Name, 
    SR.Strike_Rate
FROM Striker_Rate SR
JOIN Player P ON SR.Striker = P.Player_Id
ORDER BY SR.Strike_Rate DESC
LIMIT 10;

-- 6.What are the average runs scored by each batsman considering all the seasons?

SELECT 
    p.Player_Name,
    SUM(COALESCE(b.Runs_Scored, 0)) AS Total_Runs,
    COUNT(DISTINCT CONCAT(b.Match_Id, '-', b.Innings_No)) AS Innings_Played,
    ROUND(SUM(COALESCE(b.Runs_Scored, 0)) / NULLIF(COUNT(DISTINCT CONCAT(b.Match_Id, '-', b.Innings_No)), 0), 2) AS Avg_Runs
FROM Ball_by_Ball b
JOIN Player p ON b.Striker = p.Player_Id
GROUP BY p.Player_Name
ORDER BY Avg_Runs DESC
limit 10;

-- 7.What are the average wickets taken by each bowler considering all the seasons?

WITH wickets_per_bowler_season AS (
  SELECT
    b.Bowler,
    m.Season_Id,
    COUNT(w.Player_Out) AS wickets_taken
  FROM ball_by_ball b
  JOIN wicket_taken w
    ON b.Match_Id = w.Match_Id
   AND b.Over_Id  = w.Over_Id
   AND b.Ball_Id  = w.Ball_Id
   AND b.Innings_No = w.Innings_No
  JOIN Matches m
    ON m.Match_Id = w.Match_Id
  GROUP BY b.Bowler, m.Season_Id
),
avg_per_bowler AS (
  SELECT
    Bowler,
    AVG(wickets_taken) AS avg_wicket_per_bowler
  FROM wickets_per_bowler_season
  GROUP BY Bowler
)
SELECT
  p.Player_Name,
  ROUND(apb.avg_wicket_per_bowler, 2) AS Avg_wicket,
  RANK() OVER (ORDER BY apb.avg_wicket_per_bowler DESC) AS rnk
FROM avg_per_bowler apb
JOIN Player p
  ON p.Player_Id = apb.Bowler
WHERE apb.avg_wicket_per_bowler > 0
ORDER BY rnk, p.Player_Name;

-- 8.List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average
-- Calculate total runs scored and innings played by each player
WITH Player_Avg_Runs AS (
    SELECT
        bb.Striker AS Player_Id,
        p.Player_Name,
        COUNT(bb.Ball_Id) AS Balls_Faced,
        SUM(bb.Runs_Scored) AS Total_Runs,
        SUM(bb.Runs_Scored) * 1.0 / NULLIF(COUNT(bb.Ball_Id), 0) AS Avg_Runs
    FROM Ball_by_Ball bb
    JOIN Player p ON bb.Striker = p.Player_Id
    GROUP BY bb.Striker, p.Player_Name
),

Player_Wickets AS (
    SELECT
        wt.Player_Out AS Player_Id,
        p.Player_Name,
        COUNT(*) AS Total_Wickets
    FROM Wicket_Taken wt
    JOIN Player p ON wt.Player_Out = p.Player_Id
    GROUP BY wt.Player_Out, p.Player_Name
),

Overall_Avg AS (
    SELECT SUM(Runs_Scored) * 1.0 / NULLIF(COUNT(Ball_Id), 0) AS Overall_Avg_Runs
    FROM Ball_by_Ball
),

Overall_Wickets AS (
    SELECT AVG(Total_Wickets) AS Overall_Avg_Wickets
    FROM (
        SELECT COUNT(*) AS Total_Wickets
        FROM Wicket_Taken
        GROUP BY Player_Out
    ) AS Wicket_Data
),

Combined AS (
    SELECT
        a.Player_Id,
        a.Player_Name,
        a.Total_Runs,
        a.Avg_Runs,
        COALESCE(w.Total_Wickets, 0) AS Total_Wickets
    FROM Player_Avg_Runs a
    LEFT JOIN Player_Wickets w ON a.Player_Id = w.Player_Id
),

Overall AS (
    SELECT oa.Overall_Avg_Runs, ow.Overall_Avg_Wickets
    FROM Overall_Avg oa
    CROSS JOIN Overall_Wickets ow
)

SELECT
     RANK() OVER (ORDER BY c.Avg_Runs DESC) AS player_rank,
    c.Player_Id,
    c.Player_Name,
    ROUND(c.Avg_Runs, 2) AS avg_per_match,
    c.Total_Wickets AS total_wicket
FROM Combined c
CROSS JOIN Overall o
WHERE c.Avg_Runs > o.Overall_Avg_Runs
  AND c.Total_Wickets > o.Overall_Avg_Wickets
ORDER BY player_rank;

-- 9.	Create a table rcb_record table that shows wins and losses of RCB in an individual venue.
WITH rcb_record AS (
SELECT
    v.Venue_Name,
    COUNT(*) AS Total_Matches,
    SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins,
    SUM(CASE WHEN m.Match_Winner != t.Team_Id AND (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id) THEN 1 ELSE 0 END) AS Loses
FROM matches m
INNER JOIN team t ON (t.Team_Name = 'Royal Challengers Bangalore')
INNER JOIN venue v ON m.Venue_Id = v.Venue_Id
WHERE (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id)
GROUP BY v.Venue_Name)

SELECT Venue_Name,Total_Matches,Wins,Loses, (Total_Matches - (Wins + Loses)) as NR  FROM rcb_record; 

-- 10.What is the impact of bowling style on wickets taken?
SELECT bs.Bowling_skill, COUNT(wt.Player_Out) AS Wickets_Taken
FROM player p
INNER JOIN bowling_style bs ON p.Bowling_skill = bs.Bowling_Id
INNER JOIN ball_by_ball ball ON p.Player_Id = ball.Bowler
INNER JOIN wicket_taken wt ON ball.Match_Id = wt.Match_Id AND ball.Over_Id = wt.Over_Id AND ball.Ball_Id = wt.Ball_Id
WHERE wt.Kind_Out <> 3 -- Removing Run Outs
GROUP BY bs.Bowling_skill

ORDER BY Wickets_Taken DESC;

-- 11.	Write the sql query to provide a status of whether the performance of the team better than the previous year performance on the basis of number of runs scored by the team in the season and number of wickets taken 


WITH total_run_match_id AS (
    -- Total runs per innings per match
    SELECT 
        bb.Match_Id, 
        bb.Innings_No, 
        SUM(bb.Runs_Scored) AS total_runs
    FROM Ball_by_Ball bb
    GROUP BY bb.Match_Id, bb.Innings_No
),

team_runs_per_season AS (
    -- Total runs per season for each team
    SELECT 
        m.Season_Id,
        t.Team_Id,
        t.Team_Name,
        SUM(
            CASE 
                WHEN m.Toss_Decide = 1 AND m.Toss_Winner = t.Team_Id AND tr.Innings_No = 2 THEN tr.total_runs
                WHEN m.Toss_Decide = 2 AND m.Toss_Winner = t.Team_Id AND tr.Innings_No = 1 THEN tr.total_runs
                WHEN m.Toss_Decide = 1 AND m.Toss_Winner <> t.Team_Id AND tr.Innings_No = 1 THEN tr.total_runs
                WHEN m.Toss_Decide = 2 AND m.Toss_Winner <> t.Team_Id AND tr.Innings_No = 2 THEN tr.total_runs
                ELSE 0
            END
        ) AS total_runs
    FROM total_run_match_id tr
    JOIN Matches m ON tr.Match_Id = m.Match_Id
    JOIN Team t ON t.Team_Id IN (m.Team_1, m.Team_2)
    GROUP BY m.Season_Id, t.Team_Id, t.Team_Name
),

team_wickets_per_match_innings AS (
    -- Total wickets per match per innings
    SELECT 
        w.Match_Id, 
        w.Innings_No,
        COUNT(w.Player_Out) AS total_wickets
    FROM Wicket_Taken w
    GROUP BY w.Match_Id, w.Innings_No
),

team_wickets_per_season AS (
    -- Total wickets per season for each team
    SELECT 
        m.Season_Id,
        t.Team_Id,
        t.Team_Name,
        SUM(
            CASE 
                WHEN m.Toss_Decide = 1 AND m.Toss_Winner = t.Team_Id AND tw.Innings_No = 1 THEN tw.total_wickets
                WHEN m.Toss_Decide = 2 AND m.Toss_Winner = t.Team_Id AND tw.Innings_No = 2 THEN tw.total_wickets
                WHEN m.Toss_Decide = 1 AND m.Toss_Winner <> t.Team_Id AND tw.Innings_No = 2 THEN tw.total_wickets
                WHEN m.Toss_Decide = 2 AND m.Toss_Winner <> t.Team_Id AND tw.Innings_No = 1 THEN tw.total_wickets
                ELSE 0
            END
        ) AS total_wickets
    FROM team_wickets_per_match_innings tw
    JOIN Matches m ON m.Match_Id = tw.Match_Id
    JOIN Team t ON t.Team_Id IN (m.Team_1, m.Team_2)
    GROUP BY m.Season_Id, t.Team_Id, t.Team_Name
),

team_season_summary AS (
    -- Combined runs and wickets per team per season
    SELECT 
        r.Team_Id,
        r.Team_Name,
        r.Season_Id,
        r.total_runs,
        COALESCE(w.total_wickets, 0) AS total_wickets
    FROM team_runs_per_season r
    LEFT JOIN team_wickets_per_season w
      ON w.Team_Id = r.Team_Id AND w.Season_Id = r.Season_Id
)

-- Final year-over-year comparison
SELECT 
    curr.Team_Name,
    (prev.Season_Id + 2007) AS Previous_Year,
    (curr.Season_Id + 2007) AS Current_Year,
    prev.total_runs AS Previous_Runs,
    curr.total_runs AS Current_Runs,
    prev.total_wickets AS Previous_Wickets,
    curr.total_wickets AS Current_Wickets,
    CASE 
        WHEN curr.total_runs > prev.total_runs AND curr.total_wickets > prev.total_wickets THEN 'Better'
        WHEN curr.total_runs < prev.total_runs AND curr.total_wickets < prev.total_wickets THEN 'Worse'
        ELSE 'Mixed'
    END AS Performance_Status
FROM team_season_summary curr
JOIN team_season_summary prev
  ON prev.Team_Id = curr.Team_Id
 AND prev.Season_Id = curr.Season_Id - 1
ORDER BY curr.Team_Name, curr.Season_Id;



-- 12.	Can you derive more KPIs for the team strategy if possible?
 -- KPI #1 Boundary %
SELECT pm.Player_Id, p.Player_Name,
       ROUND((SUM(CASE WHEN b.Runs_Scored = 4 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS Four_Percentage,
       ROUND((SUM(CASE WHEN b.Runs_Scored = 6 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS Six_Percentage
FROM Ball_by_Ball b
JOIN Matches m 
ON m.Match_Id = b.Match_Id
JOIN Player_Match pm
ON m.Match_Id = pm.Match_Id AND pm.Player_Id = b.Striker
JOIN Player p
ON pm.Player_Id = p.Player_Id
WHERE m.Season_Id IN (SELECT DISTINCT Season_Id FROM Matches WHERE Team_1 = 2 OR Team_2 = 2)
GROUP BY pm.Player_Id, p.Player_Name
ORDER BY Six_Percentage DESC, Four_Percentage DESC
LIMIT 15;

-- KPI #2 Bowling strike rate (Lower is better)
SELECT bb.Bowler, p.Player_Name,
       ROUND(COUNT(bb.Ball_Id) / COUNT(w.Player_Out),2) AS Strike_Rate
FROM ball_by_ball bb
LEFT JOIN wicket_taken w 
       ON bb.Match_Id = w.Match_Id 
       AND bb.Over_Id = w.Over_Id 
       AND bb.Ball_Id = w.Ball_Id
JOIN player p
ON p.Player_Id = bb.Bowler
WHERE bb.Team_Bowling = 2
GROUP BY bb.Bowler
HAVING Strike_Rate IS NOT NULL
ORDER BY Strike_Rate ASC
LIMIT 15;


-- Q13.	Using SQL, write a query to find out average wickets taken by each bowler in each venue. Also rank the gender according to the average value.
WITH player_wickets AS (
    SELECT v.Venue_Id, v.Venue_Name, 
           p.Player_Name, 
           COUNT(w.Player_Out) AS total_wickets, 
           COUNT(DISTINCT m.Match_Id) AS matches_played  -- Distinct matches where the player bowled
    FROM Wicket_Taken w
    JOIN Ball_by_Ball b 
        ON w.Match_Id = b.Match_Id 
       AND w.Over_Id = b.Over_Id 
       AND w.Ball_Id = b.Ball_Id
       AND w.Innings_No = b.Innings_No  -- Ensuring correct innings mapping
    JOIN Matches m 
        ON b.Match_Id = m.Match_Id
    JOIN Player_Match pm 
        ON pm.Match_Id = m.Match_Id 
       AND pm.Player_Id = b.Bowler  -- Ensuring only actual bowlers are counted
    JOIN Player p 
        ON p.Player_Id = pm.Player_Id
    JOIN Venue v 
        ON v.Venue_Id = m.Venue_Id
    GROUP BY v.Venue_Id, v.Venue_Name, p.Player_Name
),
unranked_table AS (
    SELECT Venue_Id, Venue_Name, Player_Name, 
           total_wickets, 
           matches_played,
           ROUND(total_wickets / matches_played, 2) AS avg_wickets
    FROM player_wickets
)
SELECT *, DENSE_RANK() OVER(ORDER BY avg_wickets DESC) AS Ranking
FROM unranked_table
WHERE matches_played > 10;

-- 14.Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)
#Bowling performance
WITH Player_Season_Performance AS (
    SELECT 
        p.Player_Name, 
        s.Season_Year, 
        SUM(bbb.Runs_Scored) AS Total_Runs, 
        COUNT(wt.Player_Out) AS Total_Wickets,
        COUNT(DISTINCT m.Match_Id) AS Matches_Played
    FROM Player p
    INNER JOIN Ball_by_Ball bbb ON p.Player_Id = bbb.Striker
    LEFT JOIN Wicket_Taken wt ON bbb.Match_Id = wt.Match_Id 
                              AND bbb.Over_Id = wt.Over_Id 
                              AND bbb.Ball_Id = wt.Ball_Id 
                              AND bbb.Innings_No = wt.Innings_No
    INNER JOIN Matches m ON bbb.Match_Id = m.Match_Id
    INNER JOIN Season s ON m.Season_Id = s.Season_Id
    WHERE p.Player_Id = bbb.Bowler OR p.Player_Id = bbb.Striker
    GROUP BY p.Player_Name, s.Season_Year
)
SELECT 
    Player_Name, 
    AVG(Total_Runs) AS Avg_Runs_Per_Season, 
    AVG(Total_Wickets) AS Avg_Wickets_Per_Season, 
    COUNT(Season_Year) AS Seasons_Played
FROM Player_Season_Performance
GROUP BY Player_Name
HAVING Seasons_Played >3
ORDER BY Avg_Runs_Per_Season DESC, Avg_Wickets_Per_Season DESC
LIMIT 10;

-- 15.Are there players whose performance is more suited to specific venues or conditions?
#Batting performance
SELECT p.Player_Name, v.Venue_Name, 
       SUM(b.Runs_Scored) AS Total_Runs, 
       COUNT(b.Ball_Id) AS Balls_Faced,
       ROUND(SUM(b.Runs_Scored) / COUNT(b.Ball_Id), 2) * 100 AS Strike_Rate
FROM Ball_by_Ball b
JOIN Matches m ON m.Match_Id = b.Match_Id
JOIN Player p ON p.Player_Id = b.Striker
JOIN Venue v ON m.Venue_Id = v.Venue_Id
GROUP BY p.Player_Name, v.Venue_Name
HAVING Total_Runs > 0 AND Balls_Faced > 100
ORDER BY Total_Runs DESC, p.Player_Name;

#Bowling performance
SELECT p.Player_Name, v.Venue_Name, 
       COUNT(w.Player_Out) AS Wickets_Taken, 
       COUNT(b.Ball_Id) AS Balls_Bowled
FROM ball_by_ball b
JOIN wicket_taken w ON b.Match_Id = w.Match_Id 
AND b.Over_Id = w.Over_Id AND b.Ball_Id = w.Ball_Id AND b.Innings_No = w.Innings_No
JOIN matches m ON m.Match_Id = w.Match_Id
JOIN player p ON p.Player_Id = b.Bowler
JOIN venue v ON m.Venue_Id = v.Venue_Id
GROUP BY p.Player_Name, v.Venue_Name
HAVING Balls_Bowled > 5
ORDER BY  Wickets_Taken DESC,p.Player_Name;




-- SUBJECTIVE QUESTIONS

-- 1.	How does toss decision have affected the result of the match ? (which visualisations could be used to better present your answer) And is the impact limited to only specific venues?

WITH Toss_Win_Stats AS (
    SELECT v.Venue_Name, 
           td.Toss_Name AS Toss_Decision, 
           COUNT(*) AS Total_Matches,
           SUM(CASE WHEN m.Match_Winner = m.Toss_Winner THEN 1 ELSE 0 END) AS Matches_Won_After_Toss,
           ROUND((SUM(CASE WHEN m.Match_Winner = m.Toss_Winner THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS Win_Percentage
    FROM matches m
    INNER JOIN toss_decision td ON m.Toss_Decide = td.Toss_Id
    INNER JOIN venue v ON m.Venue_Id = v.Venue_Id
    GROUP BY v.Venue_Name, td.Toss_Name
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY Win_Percentage DESC, Total_Matches DESC) AS S_No,
    Venue_Name, 
    Toss_Decision, 
    Total_Matches, 
    Matches_Won_After_Toss, 
    Win_Percentage
FROM Toss_Win_Stats
ORDER BY Win_Percentage DESC, Total_Matches DESC;


-- 2.	Suggest some of the players who would be best fit for the team?

#List of consistently performing batsmen
SELECT p.Player_Name, 
       SUM(b.Runs_Scored) AS Total_Runs, 
       COUNT(b.Ball_Id) AS Balls_Faced, 
       ROUND((SUM(b.Runs_Scored) / COUNT(b.Ball_Id)) * 100, 2) AS Strike_Rate, 
       ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT m.Match_Id), 2) AS Average_Runs
FROM Player p
JOIN Ball_by_Ball b ON p.Player_Id = b.Striker
JOIN Matches m ON b.Match_Id = m.Match_Id
WHERE m.Season_Id BETWEEN 1 AND 9
GROUP BY  p.Player_Name
ORDER BY Total_Runs DESC, Strike_Rate DESC
LIMIT 20;



#List of consistent bowlers
SELECT p.Player_Name, 
       COUNT(w.Player_Out) AS Wickets_Taken, 
      ROUND(SUM(bb.Ball_Id) / COUNT(w.Player_Out),2) AS Strike_Rate, 
      
       ROUND(SUM(bb.Runs_Scored) / (SUM(bb.Ball_Id)/6),2) AS Economy_Rate
FROM Player p
JOIN Ball_by_Ball bb ON p.Player_Id = bb.Bowler
JOIN Matches m ON bb.Match_Id = m.Match_Id
 JOIN Wicket_Taken w 
ON bb.Match_Id = w.Match_Id AND bb.Over_Id = w.Over_Id AND bb.Innings_No = w.Innings_No AND bb.Ball_Id = w.Ball_Id
WHERE m.Season_Id between 1 and 9
GROUP BY p.Player_Id, p.Player_Name
ORDER BY Wickets_Taken DESC, Economy_Rate ASC, Strike_Rate ASC
LIMIT 20;

-- 3.What are some of the parameters that should be focused on while selecting the players?
#Key parameters for selecting players

# A. Death over bowling performance
SELECT p.Player_Name, 
      SUM(CASE WHEN bb.Over_Id >= 16 AND bb.Over_Id <= 20  AND p.Player_Id IN (SELECT Bowler FROM ball_by_ball) THEN bb.Runs_Scored ELSE 0 END) AS Death_Over_Runs_Conceded
FROM Player p
JOIN ball_by_ball bb ON p.Player_Id = bb.Striker OR p.Player_Id = bb.Bowler

JOIN Matches m ON bb.Match_Id = m.Match_Id 
WHERE m.Season_Id between 1 and 9
GROUP BY  p.Player_Name
HAVING COUNT(bb.Ball_Id) > 100 AND Death_Over_Runs_Conceded != 0
ORDER BY Death_Over_Runs_Conceded asc
LIMIT 20;


# B. Batting performance accross different venues

SELECT p.Player_Name, 
       v.Venue_Id, v.Venue_Name, 
       SUM(bb.Runs_Scored) AS Total_Runs, 
       COUNT(bb.Ball_Id) AS Balls_Faced, 
       ROUND(SUM(bb.Runs_Scored) / COUNT(bb.Ball_Id), 2) * 100 AS Strike_Rate
FROM Player p
JOIN Ball_by_Ball bb ON p.Player_Id = bb.Striker
JOIN Matches m ON bb.Match_Id = m.Match_Id
JOIN Venue v ON m.Venue_Id = v.Venue_Id
JOIN Ball_by_Ball bb2 
ON bb.Match_Id = bb2.Match_Id 
AND bb.Over_Id = bb2.Over_Id 
AND bb.Ball_Id = bb2.Ball_Id 
AND bb.Innings_No = bb2.Innings_No
GROUP BY p.Player_Name, v.Venue_Id, v.Venue_Name
ORDER BY Total_Runs DESC, Strike_Rate DESC
LIMIT 20;


-- Q4. Which players offer versatility in their skills and can contribute effectively with both bat and ball? (can you visualize the data for the same)
#We can find all-rounder performance for all players

WITH batting_performance AS (
    SELECT p.Player_Id, p.Player_Name,
           SUM(b.Runs_Scored) AS Total_Runs,
           COUNT(bb.Ball_Id) AS Balls_Faced,
           ROUND((SUM(b.Runs_Scored) / COUNT(bb.Ball_Id)) * 100, 2) AS Batting_Strike_Rate
    FROM Player p
    JOIN Ball_by_Ball bb ON p.Player_Id = bb.Striker
    JOIN Ball_by_Ball b 
      ON bb.Match_Id = b.Match_Id 
     AND bb.Over_Id = b.Over_Id 
     AND bb.Ball_Id = b.Ball_Id 
     AND bb.Innings_No = b.Innings_No
    WHERE b.Runs_Scored IS NOT NULL
    GROUP BY p.Player_Id, p.Player_Name
),
bowling_performance AS (
    SELECT p.Player_Id, p.Player_Name, 
           COUNT(w.Player_Out) AS Total_Wickets,
           ROUND(SUM(bb.Team_Batting) / COUNT(bb.Ball_Id), 2) AS Economy_Rate
    FROM Player p
    JOIN Ball_by_Ball bb ON p.Player_Id = bb.Bowler
    JOIN Wicket_Taken w 
      ON bb.Match_Id = w.Match_Id 
     AND bb.Over_Id = w.Over_Id 
     AND bb.Ball_Id = w.Ball_Id 
     AND bb.Innings_No = w.Innings_No
    GROUP BY p.Player_Id, p.Player_Name
)
SELECT bp.Player_Id, bp.Player_Name, 
       bp.Total_Runs, bp.Batting_Strike_Rate, bp.Balls_Faced,
       bw.Total_Wickets, bw.Economy_Rate
FROM batting_performance bp
JOIN bowling_performance bw 
  ON bp.Player_Id = bw.Player_Id
ORDER BY bp.Batting_Strike_Rate DESC, bw.Economy_Rate ASC
LIMIT 20;


-- Q5.Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualisation)

#runs_in_boundaries

WITH cte AS (
    -- Extract relevant match details for the 2015 and 2016 seasons
    SELECT bbb.Striker, m.Season_Id, s.Season_Year, 
           bbb.Match_Id, bbb.Over_Id, bbb.Ball_Id, 
           bbb.Innings_No, bbb.Runs_Scored
    FROM ball_by_ball bbb
    JOIN matches m 
        ON bbb.Match_Id = m.Match_Id
    JOIN season s 
        ON m.Season_Id = s.Season_Id
    WHERE s.Season_Year IN (2015, 2016)
),

cte2 AS (
    -- Calculate total runs per player
    SELECT Striker, SUM(Runs_Scored) AS Total_Runs
    FROM cte 
    GROUP BY Striker
),

cte3 AS (
    -- Calculate runs from boundaries (4s and 6s) per player
    SELECT Striker, SUM(Runs_Scored) AS Runs_In_Boundaries
    FROM cte
    WHERE Runs_Scored IN (4, 6)
    GROUP BY Striker
)

-- Final output with boundary percentage calculation
SELECT c2.Striker AS Player_Id, p.Player_Name, 
       c2.Total_Runs, c3.Runs_In_Boundaries, 
       ROUND((c3.Runs_In_Boundaries * 100.0 / c2.Total_Runs), 2) AS Boundary_Percentage 
FROM cte2 c2
JOIN cte3 c3 ON c2.Striker = c3.Striker
JOIN player p ON c2.Striker = p.Player_Id
WHERE c2.Total_Runs >= 100
ORDER BY Boundary_Percentage DESC
LIMIT 15;

#win percentage
-- Step 1: Calculate the team's win percentage with each player
WITH PlayerWinStats AS (
    SELECT p.Player_Name, pm.Team_Id, COUNT(m.Match_Id) AS Total_Matches, 
           SUM(CASE WHEN m.Match_Winner = pm.Team_Id THEN 1 ELSE 0 END) AS Matches_Won
    FROM player p
    INNER JOIN player_match pm ON p.Player_Id = pm.Player_Id
    INNER JOIN matches m ON pm.Match_Id = m.Match_Id
    WHERE m.Outcome_type = 1 -- considering only completed matches
    GROUP BY p.Player_Name, pm.Team_Id
),
-- Step 2: Calculate Win Percentage for each player
PlayerWinPercentage AS (
    SELECT pws.Player_Name, pws.Team_Id, pws.Total_Matches, pws.Matches_Won, 
           ROUND((pws.Matches_Won / NULLIF(pws.Total_Matches, 0)) * 100, 2) AS Win_Percentage
    FROM PlayerWinStats pws
    WHERE pws.Total_Matches > 5 -- consider players with more than 5 matches
)
-- Step 3: Combine Player Performance (runs scored, wickets taken, etc.)
SELECT pwp.Player_Name, t.Team_Name, pwp.Total_Matches, pwp.Matches_Won, 
       pwp.Win_Percentage
FROM PlayerWinPercentage pwp
INNER JOIN team t ON pwp.Team_Id = t.Team_Id
ORDER BY Win_Percentage DESC
LIMIT 15;

-- 7.What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies?
SELECT 
    v.venue_name,
    COUNT(DISTINCT m.match_id) AS total_matches,
    AVG(match_runs.total_runs) AS avg_runs_per_match,
    SUM(match_runs.total_runs) AS total_runs_all_matches
FROM venue v
JOIN matches m 
    ON v.venue_id = m.venue_id
JOIN (
    SELECT 
        bbb.match_id,
        SUM(bbb.runs_scored + COALESCE(er.extra_runs, 0)) AS total_runs
    FROM ball_by_ball bbb
    LEFT JOIN extra_runs er 
        ON bbb.match_id = er.match_id
       AND bbb.over_id = er.over_id
       AND bbb.ball_id = er.ball_id
    GROUP BY bbb.match_id
) match_runs
    ON m.match_id = match_runs.match_id
GROUP BY v.venue_name
ORDER BY total_matches DESC, avg_runs_per_match DESC
LIMIT 10;



-- 8.	Analyze the impact of home ground advantage on team performance and identify strategies to maximize this advantage for RCB.
-- home ground matches --

# Home vs Away Win/Loss record
WITH win_loss_record AS (
		SELECT m.Match_Id, v.Venue_Name,
        CASE WHEN m.Match_Winner = 2 THEN 'Win' ELSE 'Loss'
        END AS Result,
        CASE WHEN v.Venue_Id = 1 THEN 'Home' ELSE 'Away'
		END AS Venue_Type
		FROM matches m
		JOIN venue v ON m.Venue_Id = v.Venue_Id
		WHERE (m.Team_1 = 2 OR m.Team_2 = 2) AND Outcome_type !=  2
		)
		SELECT 
		Venue_Type,
		COUNT(CASE WHEN Result = 'Win' THEN 1 END) AS Wins,
		COUNT(CASE WHEN Result = 'Loss' THEN 1 END) AS Losses,
		COUNT(*) AS Total_Matches,
		ROUND(COUNT(CASE WHEN Result = 'Win' THEN 1 END) / COUNT(*) * 100, 2) AS Win_Percentage
		FROM win_loss_record
		GROUP BY Venue_Type;

#Home vs away batting performance

WITH rcb_run_stats AS (
    SELECT m.Match_Id, v.Venue_Name,
        CASE WHEN v.Venue_Id = 1 THEN 'Home' ELSE 'Away' END AS Venue_Type,
        SUM(CASE WHEN bb.Team_Batting = 2 THEN bb.Runs_Scored ELSE 0 END) AS Runs_Scored,
        SUM(CASE WHEN bb.Team_Bowling = 2 THEN bb.Runs_Scored ELSE 0 END) AS Runs_Conceded
    FROM matches m
    JOIN venue v ON m.Venue_Id = v.Venue_Id
    JOIN ball_by_ball bb ON m.Match_Id = bb.Match_Id
    WHERE (m.Team_1 = 2 OR m.Team_2 = 2) -- 2 is the team ID for RCB
    GROUP BY m.Match_Id, v.Venue_Name
)
SELECT Venue_Type,
    ROUND(AVG(Runs_Scored), 2) AS Avg_Runs_Scored,
    ROUND(SUM(Runs_Scored), 2) AS Total_Runs_Scored
FROM rcb_run_stats
GROUP BY Venue_Type;

#Home vs away bowling performance
WITH bowling_performance AS (
    SELECT v.Venue_Name,
        CASE WHEN v.Venue_Id = 1 THEN 'Home' ELSE 'Away' END AS Venue_Type,
        SUM(CASE WHEN bb.Team_Bowling = 2 THEN bb.Runs_Scored ELSE 0 END) AS Runs_Conceded,
        COUNT(CASE WHEN bb.Team_Bowling = 2 AND w.Player_Out IS NOT NULL THEN 1 ELSE NULL END) AS Wickets_Taken,
        COUNT(CASE WHEN bb.Team_Bowling = 2 THEN bb.Ball_Id ELSE NULL END) AS Balls_Bowled
    FROM matches m
    JOIN venue v ON m.Venue_Id = v.Venue_Id
    JOIN ball_by_ball bb ON m.Match_Id = bb.Match_Id
    LEFT JOIN wicket_taken w ON bb.Match_Id = w.Match_Id 
        AND bb.Over_Id = w.Over_Id 
        AND bb.Ball_Id = w.Ball_Id
        AND bb.Innings_No = w.Innings_No  -- Ensuring correct innings mapping
    WHERE (m.Team_1 = 2 OR m.Team_2 = 2) -- 2 is the team ID for RCB
    GROUP BY v.Venue_Name,Venue_Type
)
SELECT Venue_Type,
    ROUND(SUM(Wickets_taken),2) AS Total_Wickets_taken,
    ROUND(SUM(Runs_Conceded) / SUM(Balls_Bowled), 2) AS Economy_Rate
FROM bowling_performance
GROUP BY Venue_Type;


-- 9.Come up with a visual and analytical analysis with the RCB past seasons performance and potential reasons for them not winning a trophy.
# A. Win-Loss Performance Over Seasons
WITH RCB_Performance AS (
    SELECT m.Season_Id, COUNT(m.Match_Id) AS Matches_Played,
           SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Matches_Won,
           (COUNT(m.Match_Id) - SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END)) AS Matches_Lost,
           (SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) / COUNT(m.Match_Id)) * 100 AS Win_Percentage
    FROM matches m
    INNER JOIN team t ON (t.Team_Id = m.Team_1 OR t.Team_Id = m.Team_2)
    WHERE t.Team_Name = 'Royal Challengers Bangalore'
    GROUP BY m.Season_Id
)
SELECT s.Season_Year, rp.Matches_Played, rp.Matches_Won, rp.Matches_Lost, rp.Win_Percentage
FROM RCB_Performance rp
INNER JOIN season s ON rp.Season_Id = s.Season_Id
ORDER BY s.Season_Year;

-- Venue wise performance
WITH VenuePerformance AS (
    SELECT v.Venue_Name, COUNT(*) AS Matches_Played,
           SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins
    FROM matches m
    JOIN team t ON t.Team_Id IN (m.Team_1, m.Team_2)
    JOIN venue v ON m.Venue_Id = v.Venue_Id
    WHERE (t.Team_Id = m.Team_1 OR t.Team_Id = m.Team_2)
      AND t.Team_Name = 'Royal Challengers Bangalore'  -- Only consider RCB's matches
    GROUP BY v.Venue_Name
),
WinPercentage AS (
    SELECT Venue_Name, Matches_Played, Wins,
           (1.0 * Wins / Matches_Played) * 100 AS Win_Percentage
    FROM VenuePerformance
)
SELECT Venue_Name, Matches_Played, Wins, Win_Percentage
FROM WinPercentage
ORDER BY Win_Percentage DESC;

-- Home and away performance

WITH VenuePerformance AS (
    SELECT 
        CASE WHEN v.Venue_Name = 'M Chinnaswamy Stadium' THEN 'M Chinnaswamy Stadium'
		ELSE 'Away or Neutral Venue' END AS Venue_Category,
        COUNT(*) AS Matches_Played,
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins
    FROM matches m
    JOIN team t ON t.Team_Id IN (m.Team_1, m.Team_2)
    JOIN venue v ON m.Venue_Id = v.Venue_Id
    WHERE (t.Team_Id = m.Team_1 OR t.Team_Id = m.Team_2)
      AND t.Team_Name = 'Royal Challengers Bangalore'  -- Only consider RCB's matches
    GROUP BY 
        CASE WHEN v.Venue_Name = 'M Chinnaswamy Stadium' THEN 'M Chinnaswamy Stadium'
		ELSE 'Away or Neutral Venue' END
),
WinPercentage AS (
    SELECT 
        Venue_Category, Matches_Played, Wins,
        (1.0 * Wins / Matches_Played) * 100 AS Win_Percentage
    FROM VenuePerformance
)
SELECT 
    Venue_Category, Matches_Played, Wins,Win_Percentage
FROM WinPercentage
ORDER BY Venue_Category DESC;

-- Chasing vs Defending

WITH MatchRecords AS (
    SELECT 
        t.Team_Name,
        CASE 
            WHEN (m.Team_1 = t.Team_Id AND m.Toss_Winner = m.Team_1 AND m.Toss_Decide = 'bat') OR 
                 (m.Team_2 = t.Team_Id AND m.Toss_Winner = m.Team_2 AND m.Toss_Decide = 'bat') THEN 'Batting First'
            WHEN (m.Team_1 = t.Team_Id AND m.Toss_Winner = m.Team_1 AND m.Toss_Decide = 'field') OR 
                 (m.Team_2 = t.Team_Id AND m.Toss_Winner = m.Team_2 AND m.Toss_Decide = 'field') THEN 'Batting Second'
            ELSE 
                CASE WHEN m.Team_1 = t.Team_Id THEN 'Batting First'WHEN m.Team_2 = t.Team_Id THEN 'Batting Second'
                END
        END AS Game_Strategy,
        COUNT(*) AS Matches_Played,
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins
    FROM matches m
    JOIN team t ON t.Team_Id IN (m.Team_1, m.Team_2)
    WHERE t.Team_Name = 'Royal Challengers Bangalore'  -- Filter for RCB matches only
    GROUP BY t.Team_Name, Game_Strategy
),
WinPercentage AS (
    SELECT 
        Team_Name, Game_Strategy,Matches_Played,Wins,
        (1.0 * Wins / Matches_Played) * 100 AS Win_Percentage
    FROM MatchRecords
)
SELECT 
    Team_Name, Game_Strategy, Matches_Played, Wins, Win_Percentage
FROM WinPercentage
ORDER BY Win_Percentage DESC;

#  Batting performance each season
WITH rcb_batting_in_powerplay AS (
    SELECT 
        m.Season_Id,
        bb.Match_Id,
        bb.Innings_No,
        bb.Striker AS Batsman_Id,
        p.Player_Name,
        SUM(bb.Runs_Scored) AS total_runs_in_power_play, 
        COUNT(bb.Ball_Id) AS balls_faced_in_power_play
    FROM Ball_by_Ball bb
    JOIN Matches m ON bb.Match_Id = m.Match_Id
    JOIN Player p ON bb.Striker = p.Player_Id 
    WHERE (m.Team_1 = 2 OR m.Team_2 = 2) 
      AND bb.Over_Id BETWEEN 1 AND 6  
    GROUP BY m.Season_Id, bb.Match_Id, bb.Innings_No, bb.Striker, p.Player_Name
)
SELECT 
    rcb.Season_Id,
    rcb.Player_Name,
    SUM(rcb.total_runs_in_power_play) AS total_runs_in_power_play,
    SUM(rcb.balls_faced_in_power_play) AS total_balls_faced_in_powerplay,
    ROUND((SUM(rcb.total_runs_in_power_play) / NULLIF(SUM(rcb.balls_faced_in_power_play), 0)) * 100, 2) AS strike_rate_in_power_play 
FROM rcb_batting_in_powerplay rcb
GROUP BY rcb.Season_Id, rcb.Player_Name
HAVING SUM(rcb.balls_faced_in_power_play) > 100  
ORDER BY rcb.Season_Id, strike_rate_in_power_play DESC;






-- Q11.	In the "Match" table, some entries in the 
-- "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". 
-- Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".

Select * from Team;
select Team_Id, replace(Team_name,"Delhi Daredevils","Delhi Capitals") as Team_name from team;
 





















