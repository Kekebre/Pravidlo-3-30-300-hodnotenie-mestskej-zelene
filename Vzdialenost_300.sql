ALTER TABLE "sharp"."Budovy_bac"
ADD COLUMN IF NOT EXISTS nearest_plocha_m double precision;

UPDATE "sharp"."Budovy_bac" b
SET nearest_plocha_m = (
    SELECT
        ROUND(
            ST_Distance(
                ST_MakeValid(b.geom),
                ST_MakeValid(p.geom)
            )::numeric,
            2
        )
    FROM "sharp"."plochy" p
    WHERE p.geom IS NOT NULL
    ORDER BY b.geom <-> p.geom
    LIMIT 1
)
WHERE b.geom IS NOT NULL;