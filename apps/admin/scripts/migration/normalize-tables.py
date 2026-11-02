from pathlib import Path
import json
# Application JSON field names are retained as individual SQL columns.
collections={
 'personnel':('employees',{'id':'text','code':'text','name':'text','mobile':'text','gender':'text','joined':'date','salary':'numeric','status':'text','designation':'text','address':'text','remarks':'text','isDemo':'boolean'}),
 'shifts':('shifts',{'id':'text','name':'text','start':'text','end':'text','status':'text'}),
 'locations':('duty_locations',{'id':'text','name':'text','code':'text','address':'text','strength':'numeric','status':'text'}),
 'leaders':('shift_leaders',{'id':'text','name':'text','mobile':'text','designation':'text','status':'text'}),
 'policies':('leave_policies',{'id':'text','name':'text','classification':'text','entitlement':'numeric','frequency':'text','status':'text'}),
 'leaves':('leave_requests',{'id':'text','person':'text','policy':'text','from':'date','to':'date','half':'boolean','days':'numeric','classification':'text','type':'text','status':'text','reason':'text','remarks':'text'}),
 'assignments':('duty_assignments',{'id':'text','person':'text','date':'date','shift':'text','location':'text','leader':'text','status':'text'}),
 'payroll':('payroll',{'id':'text','person':'text','name':'text','code':'text','month':'text','monthlySalary':'numeric','base':'numeric','paid':'numeric','unpaid':'numeric','daily':'numeric','deduction':'numeric','net':'numeric','status':'text','generatedAt':'text'}),
 'history':('activity_log',{'id':'text','action':'text','at':'text','details':'text'})}
quote=lambda x:'"'+x+'"'
sql='''-- Atomic conversion of existing JSON workspace storage to typed relational tables.
LOCK TABLE public.workspaces IN ACCESS EXCLUSIVE MODE;
CREATE TABLE jtp_private.workspace_json_backup AS SELECT * FROM public.workspaces;
ALTER TABLE jtp_private.workspace_json_backup ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON jtp_private.workspace_json_backup FROM PUBLIC,anon,authenticated,service_role;
'''
for key,(table,cols) in collections.items():
 sql+=f'CREATE TABLE public.{table} (workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE, '+', '.join(quote(k)+' '+v+(' NOT NULL' if k=='id' else '') for k,v in cols.items())+", sort_order integer NOT NULL DEFAULT 0, attributes jsonb NOT NULL DEFAULT '{}'::jsonb, text_fields text[] NOT NULL DEFAULT '{}', PRIMARY KEY(workspace,id));\n"
 sql+=f'ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY;\nREVOKE ALL ON public.{table} FROM PUBLIC,anon,authenticated;\nGRANT ALL ON public.{table} TO service_role;\n'
sql+='''CREATE TABLE public.app_settings(workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,key text NOT NULL,value jsonb,PRIMARY KEY(workspace,key));
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_settings FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.app_settings TO service_role;
CREATE TABLE jtp_private.workspace_extras(workspace text PRIMARY KEY REFERENCES public.workspaces(id) ON DELETE CASCADE,value jsonb NOT NULL);
ALTER TABLE jtp_private.workspace_extras ENABLE ROW LEVEL SECURITY;
GRANT ALL ON jtp_private.workspace_extras TO service_role;
'''
for table,column,foreign in [('duty_assignments','person','employees'),('duty_assignments','shift','shifts'),('duty_assignments','location','duty_locations'),('leave_requests','person','employees'),('leave_requests','policy','leave_policies'),('payroll','person','employees')]:
 sql+=f'ALTER TABLE public.{table} ADD CONSTRAINT {table}_{column}_fk FOREIGN KEY(workspace,{quote(column)}) REFERENCES public.{foreign}(workspace,id) DEFERRABLE INITIALLY DEFERRED;\nCREATE INDEX {table}_{column}_idx ON public.{table}(workspace,{quote(column)});\n'
sql+='''CREATE UNIQUE INDEX employees_code_unique ON public.employees(workspace,code);
CREATE UNIQUE INDEX payroll_person_month_unique ON public.payroll(workspace,person,month);
CREATE INDEX duty_assignments_date_idx ON public.duty_assignments(workspace,date);
CREATE FUNCTION jtp_private.record_value(row_data jsonb) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $$
DECLARE result jsonb; field text;
BEGIN
 result:=coalesce(row_data->'attributes','{}'::jsonb)||jsonb_strip_nulls(row_data-ARRAY['workspace','sort_order','attributes','text_fields']);
 FOR field IN SELECT jsonb_array_elements_text(row_data->'text_fields') LOOP
  IF result ? field AND result->field<>'null'::jsonb THEN result:=jsonb_set(result,ARRAY[field],to_jsonb(result->>field)); END IF;
 END LOOP;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION jtp_private.record_value(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION jtp_private.record_value(jsonb) TO service_role;
CREATE FUNCTION public.jtp_workspace_state(owner_id text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $$
DECLARE result jsonb; items jsonb;
BEGIN
 SELECT coalesce(value,'{}'::jsonb) INTO result FROM jtp_private.workspace_extras WHERE workspace=owner_id;
 result:=coalesce(result,'{}'::jsonb);
'''
for key,(table,cols) in collections.items():
 sql+=f" SELECT coalesce(jsonb_agg(jtp_private.record_value(to_jsonb(t)) ORDER BY sort_order,id),'[]'::jsonb) INTO items FROM public.{table} t WHERE workspace=owner_id;\n result:=result||jsonb_build_object('{key}',items);\n"
sql+=" SELECT coalesce(jsonb_object_agg(key,value),'{}'::jsonb) INTO items FROM public.app_settings WHERE workspace=owner_id;\n RETURN result||jsonb_build_object('settings',items);\nEND $$;\nREVOKE ALL ON FUNCTION public.jtp_workspace_state(text) FROM PUBLIC,anon,authenticated;\nGRANT EXECUTE ON FUNCTION public.jtp_workspace_state(text) TO service_role;\n"
sql+='''CREATE FUNCTION public.jtp_write_workspace(owner_id text,state jsonb,expected_revision integer) RETURNS integer LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE actual_revision integer; row_value jsonb; item record; position integer; prior_flag text;
BEGIN
 SELECT revision INTO actual_revision FROM public.workspaces WHERE id=owner_id FOR UPDATE;
 IF actual_revision IS NULL OR actual_revision<>expected_revision THEN RETURN 0; END IF;
 IF jsonb_typeof(state)<>'object' THEN RAISE EXCEPTION 'Invalid workspace state'; END IF;
 prior_flag:=current_setting('jtp.normalized_write',true);
 PERFORM set_config('jtp.normalized_write','1',true);
'''
for key,(table,cols) in collections.items():
 names=list(cols)
 keyarray='ARRAY['+','.join("'"+k+"'" for k in names)+']'
 # Only recognized SQL identifiers are generated into this function.
 sql+=f" IF jsonb_typeof(state->'{key}')<>'array' THEN RAISE EXCEPTION 'Missing {key} collection'; END IF;\n position:=0;\n FOR row_value IN SELECT jsonb_array_elements(state->'{key}') LOOP\n"
 sql+=f"  IF coalesce(row_value->>'id','')='' THEN RAISE EXCEPTION 'Record ID required'; END IF;\n  INSERT INTO public.{table}(workspace,"+','.join(quote(k) for k in names)+",sort_order,attributes,text_fields) VALUES(owner_id,"
 sql+=','.join(f"(row_value->>'{k}')::{typ}" for k,typ in cols.items())
 sql+=f",position,row_value-{keyarray},ARRAY(SELECT k FROM jsonb_each(row_value) x(k,v) WHERE jsonb_typeof(v)='string' AND k=ANY({keyarray}))) ON CONFLICT(workspace,id) DO UPDATE SET "
 sql+=','.join(quote(k)+'=excluded.'+quote(k) for k in names if k!='id')+',sort_order=excluded.sort_order,attributes=excluded.attributes,text_fields=excluded.text_fields;\n position:=position+1;\n END LOOP;\n'
# Remove missing child records before parents. Deferrable constraints keep the transaction atomic.
for key in ['assignments','leaves','payroll','history','personnel','shifts','locations','leaders','policies']:
 table=collections[key][0];sql+=f" DELETE FROM public.{table} t WHERE workspace=owner_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(state->'{key}') r WHERE r->>'id'=t.id);\n"
sql+=''' IF jsonb_typeof(state->'settings')<>'object' THEN RAISE EXCEPTION 'Missing application settings'; END IF;
 FOR item IN SELECT key,value FROM jsonb_each(state->'settings') LOOP
  INSERT INTO public.app_settings(workspace,key,value) VALUES(owner_id,item.key,item.value) ON CONFLICT(workspace,key) DO UPDATE SET value=excluded.value;
 END LOOP;
 DELETE FROM public.app_settings WHERE workspace=owner_id AND NOT (state->'settings' ? key);
'''
allkeys=list(collections)+['settings'];sql+=" INSERT INTO jtp_private.workspace_extras(workspace,value) VALUES(owner_id,state-ARRAY["+','.join("'"+k+"'" for k in allkeys)+"]) ON CONFLICT(workspace) DO UPDATE SET value=excluded.value;\n"
sql+=''' UPDATE public.workspaces SET revision=revision+1 WHERE id=owner_id;
 PERFORM set_config('jtp.normalized_write',coalesce(prior_flag,''),true);
 RETURN 1;
END $$;
REVOKE ALL ON FUNCTION public.jtp_write_workspace(text,jsonb,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.jtp_write_workspace(text,jsonb,integer) TO service_role;
-- Copy every workspace and require an exact JSON round-trip before retiring the blob.
DO $$ DECLARE w record; reconstructed jsonb; BEGIN
 FOR w IN SELECT * FROM public.workspaces LOOP
  PERFORM public.jtp_write_workspace(w.id,w.data::jsonb,w.revision);
  reconstructed:=public.jtp_workspace_state(w.id);
  IF reconstructed<>w.data::jsonb THEN RAISE EXCEPTION 'Relational conversion failed exact data comparison'; END IF;
  UPDATE public.workspaces SET revision=w.revision WHERE id=w.id;
 END LOOP;
END $$;
ALTER TABLE public.workspaces DROP COLUMN data;
-- Preserve the existing server protocol while resolving all business reads from tables.
UPDATE jtp_private.query_registry SET template='SELECT revision,public.jtp_workspace_state(id)::text AS data FROM public.workspaces WHERE id=?' WHERE source='SELECT revision, data FROM workspaces WHERE id = ?';
UPDATE jtp_private.query_registry SET template='SELECT public.jtp_workspace_state(id)::text AS data FROM public.workspaces WHERE id=?' WHERE source='SELECT data FROM workspaces WHERE id=?';
UPDATE jtp_private.query_registry SET template='SELECT public.jtp_write_workspace(?,?::jsonb,?)' WHERE source LIKE 'INSERT INTO workspaces%';
UPDATE jtp_private.query_registry SET template='INSERT INTO public.audit(id,workspace,action,details,created_at) SELECT ?,?,?,?,? WHERE EXISTS(SELECT 1 FROM public.workspaces WHERE id=? AND revision=? AND public.jtp_workspace_state(id)=?::jsonb)' WHERE source LIKE 'INSERT INTO audit%SELECT%workspaces%';
CREATE OR REPLACE FUNCTION public.jtp_batch(statements jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE item jsonb; template text; pieces text[]; rendered text; args jsonb; i integer; rows jsonb; changed integer; output jsonb:='[]';
BEGIN
 IF jsonb_typeof(statements)<>'array' OR jsonb_array_length(statements)>25 THEN RAISE EXCEPTION 'Invalid database batch'; END IF;
 FOR item IN SELECT jsonb_array_elements(statements) LOOP
  SELECT q.template INTO template FROM jtp_private.query_registry q WHERE q.source=item->>'sql';
  IF template IS NULL THEN RAISE EXCEPTION 'Unsupported database operation'; END IF;
  args:=item->'params'; pieces:=string_to_array(template,'?');
  IF jsonb_typeof(args)<>'array' OR jsonb_array_length(args)<>array_length(pieces,1)-1 THEN RAISE EXCEPTION 'Invalid parameter count'; END IF;
  rendered:=pieces[1];
  FOR i IN 1..jsonb_array_length(args) LOOP rendered:=rendered||quote_nullable(args->>(i-1))||pieces[i+1]; END LOOP;
  IF template LIKE 'SELECT public.jtp_write_workspace(%' THEN
   EXECUTE rendered INTO changed; rows:='[]';
  ELSIF template LIKE 'SELECT %' THEN
   EXECUTE 'SELECT coalesce(jsonb_agg(to_jsonb(r)),''[]''::jsonb) FROM ('||rendered||') r' INTO rows;changed:=0;
  ELSE EXECUTE rendered;GET DIAGNOSTICS changed=ROW_COUNT;rows:='[]';END IF;
  output:=output||jsonb_build_array(jsonb_build_object('results',rows,'meta',jsonb_build_object('changes',changed),'success',true));
 END LOOP;
 RETURN output;
END $$;
-- Direct dashboard edits must also invalidate stale application revisions.
CREATE FUNCTION jtp_private.touch_workspace() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
BEGIN
 IF current_setting('jtp.normalized_write',true) IS DISTINCT FROM '1' THEN
  IF TG_OP<>'INSERT' THEN UPDATE public.workspaces SET revision=revision+1 WHERE id=OLD.workspace; END IF;
  IF TG_OP='INSERT' OR (TG_OP='UPDATE' AND NEW.workspace IS DISTINCT FROM OLD.workspace) THEN UPDATE public.workspaces SET revision=revision+1 WHERE id=NEW.workspace; END IF;
 END IF;
 RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION jtp_private.touch_workspace() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION jtp_private.touch_workspace() TO service_role;
'''
for table in [t[0] for t in collections.values()]+['app_settings']:
 sql+=f'CREATE TRIGGER touch_{table}_revision AFTER INSERT OR UPDATE OR DELETE ON public.{table} FOR EACH ROW EXECUTE FUNCTION jtp_private.touch_workspace();\n'
sql+="NOTIFY pgrst,'reload schema';\n"
Path('supabase/schema/normalize-tables.sql').write_text(sql)
Path('supabase/schema/table-map.json').write_text(json.dumps({k:v[0] for k,v in collections.items()},indent=2)+'\n')
print(len(sql),'SQL characters')
