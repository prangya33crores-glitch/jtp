-- Atomic conversion of existing JSON workspace storage to typed relational tables.
LOCK TABLE public.workspaces IN ACCESS EXCLUSIVE MODE;
CREATE TABLE jtp_private.workspace_json_backup AS SELECT * FROM public.workspaces;
ALTER TABLE jtp_private.workspace_json_backup ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON jtp_private.workspace_json_backup FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE public.employees (workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE, "id" text NOT NULL, "code" text, "name" text, "mobile" text, "gender" text, "joined" date, "salary" numeric, "status" text, "designation" text, "address" text, "remarks" text, "isDemo" boolean, sort_order integer NOT NULL DEFAULT 0, attributes jsonb NOT NULL DEFAULT '{}'::jsonb, text_fields text[] NOT NULL DEFAULT '{}', PRIMARY KEY(workspace,id));
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.employees FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.employees TO service_role;
CREATE TABLE public.shifts (workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE, "id" text NOT NULL, "name" text, "start" text, "end" text, "status" text, sort_order integer NOT NULL DEFAULT 0, attributes jsonb NOT NULL DEFAULT '{}'::jsonb, text_fields text[] NOT NULL DEFAULT '{}', PRIMARY KEY(workspace,id));
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.shifts FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.shifts TO service_role;
CREATE TABLE public.duty_locations (workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE, "id" text NOT NULL, "name" text, "code" text, "address" text, "strength" numeric, "status" text, sort_order integer NOT NULL DEFAULT 0, attributes jsonb NOT NULL DEFAULT '{}'::jsonb, text_fields text[] NOT NULL DEFAULT '{}', PRIMARY KEY(workspace,id));
ALTER TABLE public.duty_locations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.duty_locations FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.duty_locations TO service_role;
CREATE TABLE public.shift_leaders (workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE, "id" text NOT NULL, "name" text, "mobile" text, "designation" text, "status" text, sort_order integer NOT NULL DEFAULT 0, attributes jsonb NOT NULL DEFAULT '{}'::jsonb, text_fields text[] NOT NULL DEFAULT '{}', PRIMARY KEY(workspace,id));
ALTER TABLE public.shift_leaders ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.shift_leaders FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.shift_leaders TO service_role;
CREATE TABLE public.leave_policies (workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE, "id" text NOT NULL, "name" text, "classification" text, "entitlement" numeric, "frequency" text, "status" text, sort_order integer NOT NULL DEFAULT 0, attributes jsonb NOT NULL DEFAULT '{}'::jsonb, text_fields text[] NOT NULL DEFAULT '{}', PRIMARY KEY(workspace,id));
ALTER TABLE public.leave_policies ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.leave_policies FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.leave_policies TO service_role;
CREATE TABLE public.leave_requests (workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE, "id" text NOT NULL, "person" text, "policy" text, "from" date, "to" date, "half" boolean, "days" numeric, "classification" text, "type" text, "status" text, "reason" text, "remarks" text, sort_order integer NOT NULL DEFAULT 0, attributes jsonb NOT NULL DEFAULT '{}'::jsonb, text_fields text[] NOT NULL DEFAULT '{}', PRIMARY KEY(workspace,id));
ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.leave_requests FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.leave_requests TO service_role;
CREATE TABLE public.duty_assignments (workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE, "id" text NOT NULL, "person" text, "date" date, "shift" text, "location" text, "leader" text, "status" text, sort_order integer NOT NULL DEFAULT 0, attributes jsonb NOT NULL DEFAULT '{}'::jsonb, text_fields text[] NOT NULL DEFAULT '{}', PRIMARY KEY(workspace,id));
ALTER TABLE public.duty_assignments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.duty_assignments FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.duty_assignments TO service_role;
CREATE TABLE public.payroll (workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE, "id" text NOT NULL, "person" text, "name" text, "code" text, "month" text, "monthlySalary" numeric, "base" numeric, "paid" numeric, "unpaid" numeric, "daily" numeric, "deduction" numeric, "net" numeric, "status" text, "generatedAt" text, sort_order integer NOT NULL DEFAULT 0, attributes jsonb NOT NULL DEFAULT '{}'::jsonb, text_fields text[] NOT NULL DEFAULT '{}', PRIMARY KEY(workspace,id));
ALTER TABLE public.payroll ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.payroll FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.payroll TO service_role;
CREATE TABLE public.activity_log (workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE, "id" text NOT NULL, "action" text, "at" text, "details" text, sort_order integer NOT NULL DEFAULT 0, attributes jsonb NOT NULL DEFAULT '{}'::jsonb, text_fields text[] NOT NULL DEFAULT '{}', PRIMARY KEY(workspace,id));
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.activity_log FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.activity_log TO service_role;
CREATE TABLE public.app_settings(workspace text NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,key text NOT NULL,value jsonb,PRIMARY KEY(workspace,key));
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_settings FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.app_settings TO service_role;
CREATE TABLE jtp_private.workspace_extras(workspace text PRIMARY KEY REFERENCES public.workspaces(id) ON DELETE CASCADE,value jsonb NOT NULL);
ALTER TABLE jtp_private.workspace_extras ENABLE ROW LEVEL SECURITY;
GRANT ALL ON jtp_private.workspace_extras TO service_role;
ALTER TABLE public.duty_assignments ADD CONSTRAINT duty_assignments_person_fk FOREIGN KEY(workspace,"person") REFERENCES public.employees(workspace,id) DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX duty_assignments_person_idx ON public.duty_assignments(workspace,"person");
ALTER TABLE public.duty_assignments ADD CONSTRAINT duty_assignments_shift_fk FOREIGN KEY(workspace,"shift") REFERENCES public.shifts(workspace,id) DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX duty_assignments_shift_idx ON public.duty_assignments(workspace,"shift");
ALTER TABLE public.duty_assignments ADD CONSTRAINT duty_assignments_location_fk FOREIGN KEY(workspace,"location") REFERENCES public.duty_locations(workspace,id) DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX duty_assignments_location_idx ON public.duty_assignments(workspace,"location");
ALTER TABLE public.leave_requests ADD CONSTRAINT leave_requests_person_fk FOREIGN KEY(workspace,"person") REFERENCES public.employees(workspace,id) DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX leave_requests_person_idx ON public.leave_requests(workspace,"person");
ALTER TABLE public.leave_requests ADD CONSTRAINT leave_requests_policy_fk FOREIGN KEY(workspace,"policy") REFERENCES public.leave_policies(workspace,id) DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX leave_requests_policy_idx ON public.leave_requests(workspace,"policy");
ALTER TABLE public.payroll ADD CONSTRAINT payroll_person_fk FOREIGN KEY(workspace,"person") REFERENCES public.employees(workspace,id) DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX payroll_person_idx ON public.payroll(workspace,"person");
CREATE UNIQUE INDEX employees_code_unique ON public.employees(workspace,code);
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
 SELECT coalesce(jsonb_agg(jtp_private.record_value(to_jsonb(t)) ORDER BY sort_order,id),'[]'::jsonb) INTO items FROM public.employees t WHERE workspace=owner_id;
 result:=result||jsonb_build_object('personnel',items);
 SELECT coalesce(jsonb_agg(jtp_private.record_value(to_jsonb(t)) ORDER BY sort_order,id),'[]'::jsonb) INTO items FROM public.shifts t WHERE workspace=owner_id;
 result:=result||jsonb_build_object('shifts',items);
 SELECT coalesce(jsonb_agg(jtp_private.record_value(to_jsonb(t)) ORDER BY sort_order,id),'[]'::jsonb) INTO items FROM public.duty_locations t WHERE workspace=owner_id;
 result:=result||jsonb_build_object('locations',items);
 SELECT coalesce(jsonb_agg(jtp_private.record_value(to_jsonb(t)) ORDER BY sort_order,id),'[]'::jsonb) INTO items FROM public.shift_leaders t WHERE workspace=owner_id;
 result:=result||jsonb_build_object('leaders',items);
 SELECT coalesce(jsonb_agg(jtp_private.record_value(to_jsonb(t)) ORDER BY sort_order,id),'[]'::jsonb) INTO items FROM public.leave_policies t WHERE workspace=owner_id;
 result:=result||jsonb_build_object('policies',items);
 SELECT coalesce(jsonb_agg(jtp_private.record_value(to_jsonb(t)) ORDER BY sort_order,id),'[]'::jsonb) INTO items FROM public.leave_requests t WHERE workspace=owner_id;
 result:=result||jsonb_build_object('leaves',items);
 SELECT coalesce(jsonb_agg(jtp_private.record_value(to_jsonb(t)) ORDER BY sort_order,id),'[]'::jsonb) INTO items FROM public.duty_assignments t WHERE workspace=owner_id;
 result:=result||jsonb_build_object('assignments',items);
 SELECT coalesce(jsonb_agg(jtp_private.record_value(to_jsonb(t)) ORDER BY sort_order,id),'[]'::jsonb) INTO items FROM public.payroll t WHERE workspace=owner_id;
 result:=result||jsonb_build_object('payroll',items);
 SELECT coalesce(jsonb_agg(jtp_private.record_value(to_jsonb(t)) ORDER BY sort_order,id),'[]'::jsonb) INTO items FROM public.activity_log t WHERE workspace=owner_id;
 result:=result||jsonb_build_object('history',items);
 SELECT coalesce(jsonb_object_agg(key,value),'{}'::jsonb) INTO items FROM public.app_settings WHERE workspace=owner_id;
 RETURN result||jsonb_build_object('settings',items);
END $$;
REVOKE ALL ON FUNCTION public.jtp_workspace_state(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.jtp_workspace_state(text) TO service_role;
CREATE FUNCTION public.jtp_write_workspace(owner_id text,state jsonb,expected_revision integer) RETURNS integer LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE actual_revision integer; row_value jsonb; item record; position integer; prior_flag text;
BEGIN
 SELECT revision INTO actual_revision FROM public.workspaces WHERE id=owner_id FOR UPDATE;
 IF actual_revision IS NULL OR actual_revision<>expected_revision THEN RETURN 0; END IF;
 IF jsonb_typeof(state)<>'object' THEN RAISE EXCEPTION 'Invalid workspace state'; END IF;
 prior_flag:=current_setting('jtp.normalized_write',true);
 PERFORM set_config('jtp.normalized_write','1',true);
 IF jsonb_typeof(state->'personnel')<>'array' THEN RAISE EXCEPTION 'Missing personnel collection'; END IF;
 position:=0;
 FOR row_value IN SELECT jsonb_array_elements(state->'personnel') LOOP
  IF coalesce(row_value->>'id','')='' THEN RAISE EXCEPTION 'Record ID required'; END IF;
  INSERT INTO public.employees(workspace,"id","code","name","mobile","gender","joined","salary","status","designation","address","remarks","isDemo",sort_order,attributes,text_fields) VALUES(owner_id,(row_value->>'id')::text,(row_value->>'code')::text,(row_value->>'name')::text,(row_value->>'mobile')::text,(row_value->>'gender')::text,(row_value->>'joined')::date,(row_value->>'salary')::numeric,(row_value->>'status')::text,(row_value->>'designation')::text,(row_value->>'address')::text,(row_value->>'remarks')::text,(row_value->>'isDemo')::boolean,position,row_value-ARRAY['id','code','name','mobile','gender','joined','salary','status','designation','address','remarks','isDemo'],ARRAY(SELECT k FROM jsonb_each(row_value) x(k,v) WHERE jsonb_typeof(v)='string' AND k=ANY(ARRAY['id','code','name','mobile','gender','joined','salary','status','designation','address','remarks','isDemo']))) ON CONFLICT(workspace,id) DO UPDATE SET "code"=excluded."code","name"=excluded."name","mobile"=excluded."mobile","gender"=excluded."gender","joined"=excluded."joined","salary"=excluded."salary","status"=excluded."status","designation"=excluded."designation","address"=excluded."address","remarks"=excluded."remarks","isDemo"=excluded."isDemo",sort_order=excluded.sort_order,attributes=excluded.attributes,text_fields=excluded.text_fields;
 position:=position+1;
 END LOOP;
 IF jsonb_typeof(state->'shifts')<>'array' THEN RAISE EXCEPTION 'Missing shifts collection'; END IF;
 position:=0;
 FOR row_value IN SELECT jsonb_array_elements(state->'shifts') LOOP
  IF coalesce(row_value->>'id','')='' THEN RAISE EXCEPTION 'Record ID required'; END IF;
  INSERT INTO public.shifts(workspace,"id","name","start","end","status",sort_order,attributes,text_fields) VALUES(owner_id,(row_value->>'id')::text,(row_value->>'name')::text,(row_value->>'start')::text,(row_value->>'end')::text,(row_value->>'status')::text,position,row_value-ARRAY['id','name','start','end','status'],ARRAY(SELECT k FROM jsonb_each(row_value) x(k,v) WHERE jsonb_typeof(v)='string' AND k=ANY(ARRAY['id','name','start','end','status']))) ON CONFLICT(workspace,id) DO UPDATE SET "name"=excluded."name","start"=excluded."start","end"=excluded."end","status"=excluded."status",sort_order=excluded.sort_order,attributes=excluded.attributes,text_fields=excluded.text_fields;
 position:=position+1;
 END LOOP;
 IF jsonb_typeof(state->'locations')<>'array' THEN RAISE EXCEPTION 'Missing locations collection'; END IF;
 position:=0;
 FOR row_value IN SELECT jsonb_array_elements(state->'locations') LOOP
  IF coalesce(row_value->>'id','')='' THEN RAISE EXCEPTION 'Record ID required'; END IF;
  INSERT INTO public.duty_locations(workspace,"id","name","code","address","strength","status",sort_order,attributes,text_fields) VALUES(owner_id,(row_value->>'id')::text,(row_value->>'name')::text,(row_value->>'code')::text,(row_value->>'address')::text,(row_value->>'strength')::numeric,(row_value->>'status')::text,position,row_value-ARRAY['id','name','code','address','strength','status'],ARRAY(SELECT k FROM jsonb_each(row_value) x(k,v) WHERE jsonb_typeof(v)='string' AND k=ANY(ARRAY['id','name','code','address','strength','status']))) ON CONFLICT(workspace,id) DO UPDATE SET "name"=excluded."name","code"=excluded."code","address"=excluded."address","strength"=excluded."strength","status"=excluded."status",sort_order=excluded.sort_order,attributes=excluded.attributes,text_fields=excluded.text_fields;
 position:=position+1;
 END LOOP;
 IF jsonb_typeof(state->'leaders')<>'array' THEN RAISE EXCEPTION 'Missing leaders collection'; END IF;
 position:=0;
 FOR row_value IN SELECT jsonb_array_elements(state->'leaders') LOOP
  IF coalesce(row_value->>'id','')='' THEN RAISE EXCEPTION 'Record ID required'; END IF;
  INSERT INTO public.shift_leaders(workspace,"id","name","mobile","designation","status",sort_order,attributes,text_fields) VALUES(owner_id,(row_value->>'id')::text,(row_value->>'name')::text,(row_value->>'mobile')::text,(row_value->>'designation')::text,(row_value->>'status')::text,position,row_value-ARRAY['id','name','mobile','designation','status'],ARRAY(SELECT k FROM jsonb_each(row_value) x(k,v) WHERE jsonb_typeof(v)='string' AND k=ANY(ARRAY['id','name','mobile','designation','status']))) ON CONFLICT(workspace,id) DO UPDATE SET "name"=excluded."name","mobile"=excluded."mobile","designation"=excluded."designation","status"=excluded."status",sort_order=excluded.sort_order,attributes=excluded.attributes,text_fields=excluded.text_fields;
 position:=position+1;
 END LOOP;
 IF jsonb_typeof(state->'policies')<>'array' THEN RAISE EXCEPTION 'Missing policies collection'; END IF;
 position:=0;
 FOR row_value IN SELECT jsonb_array_elements(state->'policies') LOOP
  IF coalesce(row_value->>'id','')='' THEN RAISE EXCEPTION 'Record ID required'; END IF;
  INSERT INTO public.leave_policies(workspace,"id","name","classification","entitlement","frequency","status",sort_order,attributes,text_fields) VALUES(owner_id,(row_value->>'id')::text,(row_value->>'name')::text,(row_value->>'classification')::text,(row_value->>'entitlement')::numeric,(row_value->>'frequency')::text,(row_value->>'status')::text,position,row_value-ARRAY['id','name','classification','entitlement','frequency','status'],ARRAY(SELECT k FROM jsonb_each(row_value) x(k,v) WHERE jsonb_typeof(v)='string' AND k=ANY(ARRAY['id','name','classification','entitlement','frequency','status']))) ON CONFLICT(workspace,id) DO UPDATE SET "name"=excluded."name","classification"=excluded."classification","entitlement"=excluded."entitlement","frequency"=excluded."frequency","status"=excluded."status",sort_order=excluded.sort_order,attributes=excluded.attributes,text_fields=excluded.text_fields;
 position:=position+1;
 END LOOP;
 IF jsonb_typeof(state->'leaves')<>'array' THEN RAISE EXCEPTION 'Missing leaves collection'; END IF;
 position:=0;
 FOR row_value IN SELECT jsonb_array_elements(state->'leaves') LOOP
  IF coalesce(row_value->>'id','')='' THEN RAISE EXCEPTION 'Record ID required'; END IF;
  INSERT INTO public.leave_requests(workspace,"id","person","policy","from","to","half","days","classification","type","status","reason","remarks",sort_order,attributes,text_fields) VALUES(owner_id,(row_value->>'id')::text,(row_value->>'person')::text,(row_value->>'policy')::text,(row_value->>'from')::date,(row_value->>'to')::date,(row_value->>'half')::boolean,(row_value->>'days')::numeric,(row_value->>'classification')::text,(row_value->>'type')::text,(row_value->>'status')::text,(row_value->>'reason')::text,(row_value->>'remarks')::text,position,row_value-ARRAY['id','person','policy','from','to','half','days','classification','type','status','reason','remarks'],ARRAY(SELECT k FROM jsonb_each(row_value) x(k,v) WHERE jsonb_typeof(v)='string' AND k=ANY(ARRAY['id','person','policy','from','to','half','days','classification','type','status','reason','remarks']))) ON CONFLICT(workspace,id) DO UPDATE SET "person"=excluded."person","policy"=excluded."policy","from"=excluded."from","to"=excluded."to","half"=excluded."half","days"=excluded."days","classification"=excluded."classification","type"=excluded."type","status"=excluded."status","reason"=excluded."reason","remarks"=excluded."remarks",sort_order=excluded.sort_order,attributes=excluded.attributes,text_fields=excluded.text_fields;
 position:=position+1;
 END LOOP;
 IF jsonb_typeof(state->'assignments')<>'array' THEN RAISE EXCEPTION 'Missing assignments collection'; END IF;
 position:=0;
 FOR row_value IN SELECT jsonb_array_elements(state->'assignments') LOOP
  IF coalesce(row_value->>'id','')='' THEN RAISE EXCEPTION 'Record ID required'; END IF;
  INSERT INTO public.duty_assignments(workspace,"id","person","date","shift","location","leader","status",sort_order,attributes,text_fields) VALUES(owner_id,(row_value->>'id')::text,(row_value->>'person')::text,(row_value->>'date')::date,(row_value->>'shift')::text,(row_value->>'location')::text,(row_value->>'leader')::text,(row_value->>'status')::text,position,row_value-ARRAY['id','person','date','shift','location','leader','status'],ARRAY(SELECT k FROM jsonb_each(row_value) x(k,v) WHERE jsonb_typeof(v)='string' AND k=ANY(ARRAY['id','person','date','shift','location','leader','status']))) ON CONFLICT(workspace,id) DO UPDATE SET "person"=excluded."person","date"=excluded."date","shift"=excluded."shift","location"=excluded."location","leader"=excluded."leader","status"=excluded."status",sort_order=excluded.sort_order,attributes=excluded.attributes,text_fields=excluded.text_fields;
 position:=position+1;
 END LOOP;
 IF jsonb_typeof(state->'payroll')<>'array' THEN RAISE EXCEPTION 'Missing payroll collection'; END IF;
 position:=0;
 FOR row_value IN SELECT jsonb_array_elements(state->'payroll') LOOP
  IF coalesce(row_value->>'id','')='' THEN RAISE EXCEPTION 'Record ID required'; END IF;
  INSERT INTO public.payroll(workspace,"id","person","name","code","month","monthlySalary","base","paid","unpaid","daily","deduction","net","status","generatedAt",sort_order,attributes,text_fields) VALUES(owner_id,(row_value->>'id')::text,(row_value->>'person')::text,(row_value->>'name')::text,(row_value->>'code')::text,(row_value->>'month')::text,(row_value->>'monthlySalary')::numeric,(row_value->>'base')::numeric,(row_value->>'paid')::numeric,(row_value->>'unpaid')::numeric,(row_value->>'daily')::numeric,(row_value->>'deduction')::numeric,(row_value->>'net')::numeric,(row_value->>'status')::text,(row_value->>'generatedAt')::text,position,row_value-ARRAY['id','person','name','code','month','monthlySalary','base','paid','unpaid','daily','deduction','net','status','generatedAt'],ARRAY(SELECT k FROM jsonb_each(row_value) x(k,v) WHERE jsonb_typeof(v)='string' AND k=ANY(ARRAY['id','person','name','code','month','monthlySalary','base','paid','unpaid','daily','deduction','net','status','generatedAt']))) ON CONFLICT(workspace,id) DO UPDATE SET "person"=excluded."person","name"=excluded."name","code"=excluded."code","month"=excluded."month","monthlySalary"=excluded."monthlySalary","base"=excluded."base","paid"=excluded."paid","unpaid"=excluded."unpaid","daily"=excluded."daily","deduction"=excluded."deduction","net"=excluded."net","status"=excluded."status","generatedAt"=excluded."generatedAt",sort_order=excluded.sort_order,attributes=excluded.attributes,text_fields=excluded.text_fields;
 position:=position+1;
 END LOOP;
 IF jsonb_typeof(state->'history')<>'array' THEN RAISE EXCEPTION 'Missing history collection'; END IF;
 position:=0;
 FOR row_value IN SELECT jsonb_array_elements(state->'history') LOOP
  IF coalesce(row_value->>'id','')='' THEN RAISE EXCEPTION 'Record ID required'; END IF;
  INSERT INTO public.activity_log(workspace,"id","action","at","details",sort_order,attributes,text_fields) VALUES(owner_id,(row_value->>'id')::text,(row_value->>'action')::text,(row_value->>'at')::text,(row_value->>'details')::text,position,row_value-ARRAY['id','action','at','details'],ARRAY(SELECT k FROM jsonb_each(row_value) x(k,v) WHERE jsonb_typeof(v)='string' AND k=ANY(ARRAY['id','action','at','details']))) ON CONFLICT(workspace,id) DO UPDATE SET "action"=excluded."action","at"=excluded."at","details"=excluded."details",sort_order=excluded.sort_order,attributes=excluded.attributes,text_fields=excluded.text_fields;
 position:=position+1;
 END LOOP;
 DELETE FROM public.duty_assignments t WHERE workspace=owner_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(state->'assignments') r WHERE r->>'id'=t.id);
 DELETE FROM public.leave_requests t WHERE workspace=owner_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(state->'leaves') r WHERE r->>'id'=t.id);
 DELETE FROM public.payroll t WHERE workspace=owner_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(state->'payroll') r WHERE r->>'id'=t.id);
 DELETE FROM public.activity_log t WHERE workspace=owner_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(state->'history') r WHERE r->>'id'=t.id);
 DELETE FROM public.employees t WHERE workspace=owner_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(state->'personnel') r WHERE r->>'id'=t.id);
 DELETE FROM public.shifts t WHERE workspace=owner_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(state->'shifts') r WHERE r->>'id'=t.id);
 DELETE FROM public.duty_locations t WHERE workspace=owner_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(state->'locations') r WHERE r->>'id'=t.id);
 DELETE FROM public.shift_leaders t WHERE workspace=owner_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(state->'leaders') r WHERE r->>'id'=t.id);
 DELETE FROM public.leave_policies t WHERE workspace=owner_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(state->'policies') r WHERE r->>'id'=t.id);
 IF jsonb_typeof(state->'settings')<>'object' THEN RAISE EXCEPTION 'Missing application settings'; END IF;
 FOR item IN SELECT key,value FROM jsonb_each(state->'settings') LOOP
  INSERT INTO public.app_settings(workspace,key,value) VALUES(owner_id,item.key,item.value) ON CONFLICT(workspace,key) DO UPDATE SET value=excluded.value;
 END LOOP;
 DELETE FROM public.app_settings WHERE workspace=owner_id AND NOT (state->'settings' ? key);
 INSERT INTO jtp_private.workspace_extras(workspace,value) VALUES(owner_id,state-ARRAY['personnel','shifts','locations','leaders','policies','leaves','assignments','payroll','history','settings']) ON CONFLICT(workspace) DO UPDATE SET value=excluded.value;
 UPDATE public.workspaces SET revision=revision+1 WHERE id=owner_id;
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
CREATE TRIGGER touch_employees_revision AFTER INSERT OR UPDATE OR DELETE ON public.employees FOR EACH ROW EXECUTE FUNCTION jtp_private.touch_workspace();
CREATE TRIGGER touch_shifts_revision AFTER INSERT OR UPDATE OR DELETE ON public.shifts FOR EACH ROW EXECUTE FUNCTION jtp_private.touch_workspace();
CREATE TRIGGER touch_duty_locations_revision AFTER INSERT OR UPDATE OR DELETE ON public.duty_locations FOR EACH ROW EXECUTE FUNCTION jtp_private.touch_workspace();
CREATE TRIGGER touch_shift_leaders_revision AFTER INSERT OR UPDATE OR DELETE ON public.shift_leaders FOR EACH ROW EXECUTE FUNCTION jtp_private.touch_workspace();
CREATE TRIGGER touch_leave_policies_revision AFTER INSERT OR UPDATE OR DELETE ON public.leave_policies FOR EACH ROW EXECUTE FUNCTION jtp_private.touch_workspace();
CREATE TRIGGER touch_leave_requests_revision AFTER INSERT OR UPDATE OR DELETE ON public.leave_requests FOR EACH ROW EXECUTE FUNCTION jtp_private.touch_workspace();
CREATE TRIGGER touch_duty_assignments_revision AFTER INSERT OR UPDATE OR DELETE ON public.duty_assignments FOR EACH ROW EXECUTE FUNCTION jtp_private.touch_workspace();
CREATE TRIGGER touch_payroll_revision AFTER INSERT OR UPDATE OR DELETE ON public.payroll FOR EACH ROW EXECUTE FUNCTION jtp_private.touch_workspace();
CREATE TRIGGER touch_activity_log_revision AFTER INSERT OR UPDATE OR DELETE ON public.activity_log FOR EACH ROW EXECUTE FUNCTION jtp_private.touch_workspace();
CREATE TRIGGER touch_app_settings_revision AFTER INSERT OR UPDATE OR DELETE ON public.app_settings FOR EACH ROW EXECUTE FUNCTION jtp_private.touch_workspace();
NOTIFY pgrst,'reload schema';
