-- Retire the temporary bulk-copy interface after the verified cutover.
DROP FUNCTION IF EXISTS public.jtp_import(jsonb);
DROP FUNCTION IF EXISTS public.jtp_export();
