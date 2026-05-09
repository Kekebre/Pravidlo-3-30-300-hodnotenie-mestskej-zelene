-- Tvorba line of sight (spojníc)
-- 1. Indexy na vstupných vrstvách
CREATE INDEX IF NOT EXISTS observers_all_geom_idx
ON "sharp"."observers_all"
USING GIST (geom);

CREATE INDEX IF NOT EXISTS stromy_plus_geom_idx
ON "sharp"."Stromy_plus"
USING GIST (geom);

CREATE INDEX IF NOT EXISTS budovy_bac_geom_idx
ON "sharp"."Budovy_bac"
USING GIST (geom);

ANALYZE "sharp"."observers_all";
ANALYZE "sharp"."Stromy_plus";
ANALYZE "sharp"."Budovy_bac";


-- 2. Predpripravená vrstva prekážok
DROP TABLE IF EXISTS "sharp"."los_obstacles_005";

CREATE UNLOGGED TABLE "sharp"."los_obstacles_005" AS
SELECT
    row_number() OVER () AS obstacle_id,
    s.geom
FROM "sharp"."Budovy_bac" b
CROSS JOIN LATERAL ST_Subdivide(
    ST_Buffer(ST_Boundary(b.geom), 0.05),
    256
) AS s(geom)
WHERE b.geom IS NOT NULL;

ALTER TABLE "sharp"."los_obstacles_005"
ADD CONSTRAINT los_obstacles_005_pk PRIMARY KEY (obstacle_id);

CREATE INDEX los_obstacles_005_geom_idx
ON "sharp"."los_obstacles_005"
USING GIST (geom);

ANALYZE "sharp"."los_obstacles_005";


-- 3. Kandidátne spojnice observer-strom do 30 m
DROP TABLE IF EXISTS "sharp"."tmp_candidate_tree_lines_30m";

CREATE UNLOGGED TABLE "sharp"."tmp_candidate_tree_lines_30m" AS
SELECT
    row_number() OVER () AS candidate_id,
    o.observer_id,
    s.gs_id AS strom_id,
    ST_MakeLine(o.geom, s.geom) AS full_line,
    CASE
        WHEN ST_Length(ST_MakeLine(o.geom, s.geom)) > 0.5 THEN
            ST_LineSubstring(
                ST_MakeLine(o.geom, s.geom),
                0.5 / ST_Length(ST_MakeLine(o.geom, s.geom)),
                1.0
            )
        ELSE
            ST_MakeLine(o.geom, s.geom)
    END AS test_line
FROM "sharp"."observers_all" o
JOIN "sharp"."Stromy_plus" s
  ON s.geom && ST_Expand(o.geom, 30.0)
 AND ST_DWithin(o.geom, s.geom, 30.0)
WHERE o.geom IS NOT NULL
  AND s.geom IS NOT NULL;

ALTER TABLE "sharp"."tmp_candidate_tree_lines_30m"
ADD CONSTRAINT tmp_candidate_tree_lines_30m_pk PRIMARY KEY (candidate_id);

CREATE INDEX tmp_candidate_tree_lines_30m_test_line_idx
ON "sharp"."tmp_candidate_tree_lines_30m"
USING GIST (test_line);

ANALYZE "sharp"."tmp_candidate_tree_lines_30m";


-- 4. Finálne viditeľné spojnice
DROP TABLE IF EXISTS "sharp"."observer_tree_lines_30m";

CREATE TABLE "sharp"."observer_tree_lines_30m" AS
SELECT
    row_number() OVER () AS line_id,
    c.observer_id,
    c.strom_id,
    ST_Length(c.full_line) AS length_m,
    c.full_line AS geom
FROM "sharp"."tmp_candidate_tree_lines_30m" c
WHERE NOT EXISTS (
    SELECT 1
    FROM "sharp"."los_obstacles_005" ob
    WHERE ob.geom && c.test_line
      AND ST_Intersects(c.test_line, ob.geom)
);

ALTER TABLE "sharp"."observer_tree_lines_30m"
ADD CONSTRAINT observer_tree_lines_30m_pk PRIMARY KEY (line_id);

CREATE INDEX observer_tree_lines_30m_geom_idx
ON "sharp"."observer_tree_lines_30m"
USING GIST (geom);

ANALYZE "sharp"."observer_tree_lines_30m";


-- 3. Zapísanie počtu viditeľných stromov do "sharp"."observers_all"
-- podľa vrstvy "sharp"."observer_tree_lines_30m"

ALTER TABLE "sharp"."observers_all"
ADD COLUMN IF NOT EXISTS visible_tree_count integer;

UPDATE "sharp"."observers_all"
SET visible_tree_count = 0;

WITH tree_counts AS (
    SELECT
        observer_id,
        COUNT(DISTINCT strom_id) AS cnt
    FROM "sharp"."observer_tree_lines_30m"
    GROUP BY observer_id
)
UPDATE "sharp"."observers_all" o
SET visible_tree_count = tc.cnt
FROM tree_counts tc
WHERE o.observer_id = tc.observer_id;