-- ============================================================
-- this script analyzes all features (NDVI, DEM and fire mask)
-- for kaliningrad location. once the proper data is analyzed, 
-- the completed dataset will be used in ml model. 
-- Author: [Brandon Wilson]
-- ============================================================

-- ───────────────────────────────────────────────
-- section 1: elevation statistics where fires occurred
-- ───────────────────────────────────────────────

-- wherever a fire occured, topography stats are retrieved 
SELECT 'elevation_fire_areas' AS analysis_type,
(stats).count,
(stats).mean,
(stats).min,
(stats).max,
(stats).stddev
FROM (
SELECT ST_SummaryStats(
ST_MapAlgebraExpr(
f.rast, 1,
d.rast, 1,
'CASE WHEN [rast1] = 1 THEN [rast2] ELSE NULL END'
),
TRUE
) AS stats
FROM fire_mask f
JOIN dem_clipped d ON ST_Intersects(f.rast, d.rast)
) AS result;

-- ───────────────────────────────────────────────
-- section 2: vegetation and topography stats where fires did not occur
-- ───────────────────────────────────────────────
SELECT
'ndvi_unburned' AS analysis_type,
(stats).count,
(stats).mean,
(stats).min,
(stats).max,
(stats).stddev
FROM (
SELECT ST_SummaryStats(
ST_MapAlgebraExpr(
f.rast, 1,
n.rast, 1,
'CASE WHEN [rast1] = 0 THEN [rast2] ELSE NULL END'
),
TRUE
) AS stats
FROM fire_mask f
JOIN ndvi_clipped n ON ST_Intersects(f.rast, n.rast)
) AS result;

-- Slope stats in unburned areas (optional, if slope_clipped exists)
-- SELECT
-- 'slope_unburned' AS analysis_type,
-- (stats).count,
-- (stats).mean,
-- (stats).min,
-- (stats).max,
-- (stats).stddev
-- FROM (
-- SELECT ST_SummaryStats(
-- ST_MapAlgebraExpr(
-- f.rast, 1,
-- s.rast, 1,
-- 'CASE WHEN [rast1] = 0 THEN [rast2] ELSE NULL END'
-- ),
-- TRUE
-- ) AS stats
-- FROM fire_mask f
-- JOIN slope_clipped s ON ST_Intersects(f.rast, s.rast)
-- ) AS result;

-- ───────────────────────────────────────────────
-- section 3: flattened training dataset (pixel-level features)
-- ───────────────────────────────────────────────

--- dropping table if exists
DROP TABLE IF EXISTS raster_features;

-- flattened dataset with combined features
CREATE TABLE raster_features AS
SELECT
(ST_PixelAsPoints(n.rast)).geom AS geom,
(ST_PixelAsPoints(n.rast)).val AS ndvi,
(ST_PixelAsPoints(f.rast)).val AS fire,
(ST_PixelAsPoints(d.rast)).val AS elevation
FROM ndvi_clipped n
JOIN fire_mask f ON ST_Intersects(n.rast, f.rast)
JOIN dem_clipped d ON ST_Intersects(n.rast, d.rast);

--- spatial index for performance 
CREATE INDEX idx_raster_features_geom ON raster_features USING GIST (geom);

-- summary
SELECT
COUNT(*) AS total_pixels,
AVG(ndvi) AS avg_ndvi,
AVG(elevation) AS avg_elevation,
SUM(CASE WHEN fire = 1 THEN 1 ELSE 0 END) AS fire_pixel_count
FROM raster_features;