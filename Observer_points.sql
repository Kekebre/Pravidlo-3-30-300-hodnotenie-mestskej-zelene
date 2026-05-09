Tvorba pozorovacích bodov
-- 1.Pridanie segmentov
-- PARAMETRE:
-- min_edge_m = minimálna dĺžka hrany pre observer bod
-- spacing_m  = približný rozostup observer bodov na dlhej hrane
-- radius_m   = dosah viditeľnosti ku stromom

CREATE TABLE "sharp"."budovy_facade_segments" AS
WITH polys AS (
    SELECT
        id AS building_id,
        (ST_Dump(ST_Force2D(geom))).geom AS poly_geom
    FROM "sharp"."Budovy_bac"
    WHERE geom IS NOT NULL
),
rings AS (
    SELECT
        building_id,
        ST_ExteriorRing(poly_geom) AS ring_geom
    FROM polys
),
segments AS (
    SELECT
        building_id,
        (ST_DumpSegments(ring_geom)).geom AS geom
    FROM rings
)
SELECT
    row_number() OVER () AS segment_id,
    building_id,
    ST_Length(geom) AS length_m,
    geom
FROM segments
WHERE ST_Length(geom) >= 2.0;

ALTER TABLE "sharp"."budovy_facade_segments"
ADD CONSTRAINT budovy_facade_segments_pk PRIMARY KEY (segment_id);

CREATE INDEX budovy_facade_segments_geom_idx
ON "sharp"."budovy_facade_segments"
USING GIST (geom);

ANALYZE "sharp"."budovy_facade_segments";

-- 2.OBSERVER BODY
-- Krátke hrany < 2 m sú vynechané.
-- Dlhé hrany sa rozdelia podľa rozostupu cca 10 m.
-- Body na spoločných hranách susedných budov sa vynechajú.

CREATE TABLE "sharp"."observers_all" AS
WITH segment_info AS (
    SELECT
        segment_id,
        building_id,
        length_m,
        geom,
        GREATEST(1, CEIL(length_m / 10.0)::int) AS n_parts
    FROM "sharp"."budovy_facade_segments"
),
candidate_points AS (
    SELECT
        si.segment_id,
        si.building_id,
        si.length_m,
        i AS point_index,
        ST_LineInterpolatePoint(
            si.geom,
            (i - 0.5)::double precision / si.n_parts
        ) AS geom
    FROM segment_info si
    CROSS JOIN LATERAL generate_series(1, si.n_parts) AS i
),
filtered_points AS (
    SELECT cp.*
    FROM candidate_points cp
    WHERE NOT EXISTS (
        SELECT 1
        FROM "sharp"."Budovy_bac" b
        WHERE b.id <> cp.building_id
          AND ST_DWithin(cp.geom, ST_Force2D(b.geom), 0.05)
    )
)
SELECT
    row_number() OVER () AS observer_id,
    segment_id,
    building_id,
    point_index,
    length_m,
    0::integer AS visible_tree_count,
    geom
FROM filtered_points;

ALTER TABLE "sharp"."observers_all"
ADD CONSTRAINT observers_all_pk PRIMARY KEY (observer_id);

CREATE INDEX observers_all_geom_idx
ON "sharp"."observers_all"
USING GIST (geom);

ANALYZE "sharp"."observers_all";