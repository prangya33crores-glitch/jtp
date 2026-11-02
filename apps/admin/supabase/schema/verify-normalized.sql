-- Run as the database owner. Every test write is rolled back.
BEGIN;
DO $verify$
DECLARE owner_id text; state jsonb; original jsonb; rev integer; result jsonb; source_sql text; person_id text; changed_name text; count_before integer;
BEGIN
 SELECT value INTO STRICT owner_id FROM public.portal_settings WHERE key='admin_user_id';
 SELECT revision INTO rev FROM public.workspaces WHERE id=owner_id FOR UPDATE;
 state:=public.jtp_workspace_state(owner_id);original:=state;
 IF jsonb_array_length(state->'personnel')<>(SELECT count(*) FROM public.employees WHERE workspace=owner_id) THEN RAISE EXCEPTION 'Read does not use employee rows'; END IF;
 person_id:=state->'personnel'->0->>'id';changed_name:='Verification employee - rollback only';
 state:=jsonb_set(state,'{personnel,0,name}',to_jsonb(changed_name));
 SELECT source INTO STRICT source_sql FROM jtp_private.query_registry WHERE source LIKE 'INSERT INTO workspaces%';
 result:=public.jtp_batch(jsonb_build_array(jsonb_build_object('sql',source_sql,'params',jsonb_build_array(owner_id,state::text,rev))));
 IF result->0->'meta'->>'changes'<>'1' THEN RAISE EXCEPTION 'Server save failed'; END IF;
 IF (SELECT name FROM public.employees WHERE workspace=owner_id AND id=person_id)<>changed_name THEN RAISE EXCEPTION 'Save did not update employee table'; END IF;
 result:=public.jtp_batch(jsonb_build_array(jsonb_build_object('sql',source_sql,'params',jsonb_build_array(owner_id,original::text,rev))));
 IF result->0->'meta'->>'changes'<>'0' THEN RAISE EXCEPTION 'Stale revision overwrote data'; END IF;
 SELECT revision INTO rev FROM public.workspaces WHERE id=owner_id;
 UPDATE public.employees SET name='Dashboard edit - rollback only' WHERE workspace=owner_id AND id=person_id;
 IF (SELECT revision FROM public.workspaces WHERE id=owner_id)<>rev+1 THEN RAISE EXCEPTION 'Dashboard edit did not invalidate cached revision'; END IF;
 IF public.jtp_workspace_state(owner_id)->'personnel'->0->>'name'<>'Dashboard edit - rollback only' THEN RAISE EXCEPTION 'Dashboard edit missing from application read'; END IF;
 result:=public.jtp_batch(jsonb_build_array(jsonb_build_object('sql','SELECT data FROM workspaces WHERE id=?','params',jsonb_build_array('x'' OR 1=1 --'))));
 IF jsonb_array_length(result->0->'results')<>0 THEN RAISE EXCEPTION 'Query parameter was not isolated'; END IF;
 SELECT revision INTO rev FROM public.workspaces WHERE id=owner_id;
 state:=public.jtp_workspace_state(owner_id);count_before:=jsonb_array_length(state->'assignments');
 IF count_before>0 THEN
  state:=jsonb_set(state,'{assignments}',(state->'assignments')-0);
  PERFORM public.jtp_write_workspace(owner_id,state,rev);
  IF (SELECT count(*) FROM public.duty_assignments WHERE workspace=owner_id)<>count_before-1 THEN RAISE EXCEPTION 'Duty deletion did not reach relational table'; END IF;
 END IF;
 IF has_table_privilege('anon','public.employees','SELECT') OR has_table_privilege('authenticated','public.payroll','SELECT') THEN RAISE EXCEPTION 'Browser direct data access enabled'; END IF;
END $verify$;
ROLLBACK;
