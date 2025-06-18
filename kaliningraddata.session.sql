SELECT rid, ST_Width(rast), ST_Height(rast), ST_SRID(rast) FROM public.dem_clipped LIMIT 5;
