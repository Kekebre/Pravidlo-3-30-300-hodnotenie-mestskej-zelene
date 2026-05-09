ALTER TABLE "sharp"."Budovy_bac"
ADD COLUMN IF NOT EXISTS canopy_30_pct double precision;

CREATE INDEX IF NOT EXISTS budovy_bac_geom_gix
ON "sharp"."Budovy_bac"
USING GIST (geom);

CREATE INDEX IF NOT EXISTS poly_geom_gix
ON "sharp"."poly" --polygonizovaný raster CHM
USING GIST (geom);

ANALYZE "sharp"."Budovy_bac";
ANALYZE "sharp"."poly";


--pomocná tabuľka okolia 
DROP TABLE IF EXISTS "sharp"."budovy_okolie_30";

CREATE TABLE "sharp"."budovy_okolie_30" AS
SELECT
    b.ctid AS bid,
    ST_Difference(
        ST_Buffer(b.geom, 30),
        b.geom
    ) AS geom
FROM "sharp"."Budovy_bac" b
WHERE b.geom IS NOT NULL;

CREATE INDEX budovy_okolie_30_geom_gix
ON "sharp"."budovy_okolie_30"
USING GIST (geom);

ANALYZE "sharp"."budovy_okolie_30";


--výpočet prekryvu
WITH vypocet AS (
    SELECT
        o.bid,
        ST_Area(o.geom) AS area_okolie,
        COALESCE(
            SUM(
                ST_Area(
                    ST_Intersection(o.geom, p.geom)
                )
            ),
            0
        ) AS area_canopy
    FROM "sharp"."budovy_okolie_30" o
    LEFT JOIN "sharp"."poly" p
      ON p.geom && o.geom
     AND ST_Intersects(p.geom, o.geom)
    GROUP BY o.bid, o.geom
)
UPDATE "sharp"."Budovy_bac" b
SET canopy_30_pct = ROUND(
    (100.0 * v.area_canopy / NULLIF(v.area_okolie, 0))::numeric,
    2
)::double precision
FROM vypocet v
WHERE b.ctid = v.bid;

UPDATE "sharp"."Budovy_bac"
SET canopy_30_pct = 0
WHERE canopy_30_pct IS NULL;

--celkový čas, cca 20-25 minút. Tento postup bol realizovaný kvôli objemu dát a optimalizácií.