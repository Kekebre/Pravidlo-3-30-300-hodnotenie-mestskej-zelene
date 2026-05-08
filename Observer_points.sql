Tvorba pozorovacích bodov

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