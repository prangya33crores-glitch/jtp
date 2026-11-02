import pathlib,re,json
root=pathlib.Path('.')
tables=['workspaces','audit','portal_settings','employee_access','password_accounts','password_sessions','password_attempts']
# Derive the fixed query allowlist from server source only, never from requests.
queries=set()
for p in list(pathlib.Path('app').rglob('*.ts'))+list(pathlib.Path('lib').glob('*.ts')):
 for m in re.finditer(r'\.prepare\((\x27(?:[^\x27\\]|\\.)*\x27|"(?:[^"\\]|\\.)*")\)',p.read_text()):
  queries.add(m.group(1)[1:-1])
pathlib.Path('supabase/schema/queries.json').write_text(json.dumps(sorted(queries),indent=2))
sql='CREATE SCHEMA IF NOT EXISTS jtp_private;\nREVOKE ALL ON SCHEMA jtp_private FROM PUBLIC, anon, authenticated;\n'
for p in sorted(pathlib.Path('drizzle').glob('000[0-3]*.sql')):
 s=p.read_text().replace('`','').replace('--> statement-breakpoint','')
 s=re.sub(r'CREATE TABLE (\w+)',r'CREATE TABLE public.\1',s)
 s=re.sub(r' ON (\w+) \(',r' ON public.\1 (',s)
 s=s.replace('ALTER TABLE password_sessions','ALTER TABLE public.password_sessions')
 sql+=s+'\n'
for t in tables:
 sql+=f'ALTER TABLE public.{t} ENABLE ROW LEVEL SECURITY;\nREVOKE ALL ON public.{t} FROM PUBLIC,anon,authenticated;\nGRANT ALL ON public.{t} TO service_role;\n'
sql+='CREATE INDEX audit_workspace_created_idx ON public.audit(workspace,created_at);\nCREATE INDEX employee_access_workspace_idx ON public.employee_access(workspace);\nCREATE INDEX password_accounts_workspace_idx ON public.password_accounts(workspace);\nCREATE INDEX password_sessions_account_idx ON public.password_sessions(account);\n'
sql+='CREATE TABLE jtp_private.query_registry (source text PRIMARY KEY,template text NOT NULL);\nALTER TABLE jtp_private.query_registry ENABLE ROW LEVEL SECURITY;\nGRANT USAGE ON SCHEMA jtp_private TO service_role;\nGRANT SELECT ON jtp_private.query_registry TO service_role;\n'
for q in sorted(queries):
 pg=q
 if pg.startswith('INSERT OR IGNORE'):
  pg=pg.replace('INSERT OR IGNORE','INSERT')+' ON CONFLICT DO NOTHING'
 if pg.startswith('INSERT INTO password_attempts'):
  pg=pg.replace('WHEN reset_at<=','WHEN password_attempts.reset_at<=').replace('ELSE count+1','ELSE password_attempts.count+1').replace('ELSE reset_at END','ELSE password_attempts.reset_at END')
 # Qualify every application table; no attacker-selected identifiers.
 for t in tables:pg=re.sub(r'\b'+t+r'\b','public.'+t,pg)
 # ON CONFLICT expression table qualifiers must use the relation name, not schema.table.column.
 for t in tables:pg=pg.replace('public.'+t+'.',t+'.')
 sql+="INSERT INTO jtp_private.query_registry VALUES ('"+q.replace("'","''")+"','"+pg.replace("'","''")+"');\n"
sql+='''
CREATE FUNCTION public.jtp_batch(statements jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE item jsonb; template text; pieces text[]; rendered text; args jsonb; i integer; rows jsonb; changed integer; output jsonb:='[]';
BEGIN
 IF jsonb_typeof(statements)<>'array' OR jsonb_array_length(statements)>25 THEN RAISE EXCEPTION 'Invalid database batch'; END IF;
 FOREACH item IN ARRAY ARRAY(SELECT jsonb_array_elements(statements)) LOOP
  SELECT q.template INTO template FROM jtp_private.query_registry q WHERE q.source=item->>'sql';
  IF template IS NULL THEN RAISE EXCEPTION 'Unsupported database operation'; END IF;
  args:=item->'params'; pieces:=string_to_array(template,'?');
  IF jsonb_typeof(args)<>'array' OR jsonb_array_length(args)<>array_length(pieces,1)-1 THEN RAISE EXCEPTION 'Invalid parameter count'; END IF;
  rendered:=pieces[1];
  FOR i IN 1..jsonb_array_length(args) LOOP
   rendered:=rendered||quote_nullable(args->>(i-1))||pieces[i+1];
  END LOOP;
  IF template LIKE 'SELECT %' THEN
   EXECUTE 'SELECT coalesce(jsonb_agg(to_jsonb(r)),''[]''::jsonb) FROM ('||rendered||') r' INTO rows;
   changed:=0;
  ELSE
   EXECUTE rendered; GET DIAGNOSTICS changed=ROW_COUNT; rows:='[]';
  END IF;
  output:=output||jsonb_build_array(jsonb_build_object('results',rows,'meta',jsonb_build_object('changes',changed),'success',true));
 END LOOP;
 RETURN output;
END; $$;
REVOKE ALL ON FUNCTION public.jtp_batch(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.jtp_batch(jsonb) TO service_role;
CREATE TABLE jtp_private.import_manifest (id boolean PRIMARY KEY DEFAULT true CHECK(id),created_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE jtp_private.import_manifest ENABLE ROW LEVEL SECURITY;
GRANT ALL ON jtp_private.import_manifest TO service_role;
CREATE FUNCTION public.jtp_export() RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE output jsonb:='{}'; t text; rows jsonb;
BEGIN
 FOREACH t IN ARRAY ARRAY['workspaces','audit','portal_settings','employee_access','password_accounts','password_sessions','password_attempts'] LOOP
  EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(r)),''[]''::jsonb) FROM public.%I r',t) INTO rows;
  output:=output||jsonb_build_object(t,rows);
 END LOOP;
 RETURN output;
END; $$;
REVOKE ALL ON FUNCTION public.jtp_export() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.jtp_export() TO service_role;
CREATE FUNCTION public.jtp_import(snapshot jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE t text; n bigint;
BEGIN
 PERFORM pg_advisory_xact_lock(92348373);
 IF EXISTS(SELECT 1 FROM jtp_private.import_manifest) THEN RETURN public.jtp_export(); END IF;
 FOREACH t IN ARRAY ARRAY['workspaces','audit','portal_settings','employee_access','password_accounts','password_sessions','password_attempts'] LOOP
  EXECUTE format('SELECT count(*) FROM public.%I',t) INTO n;
  IF n<>0 THEN RAISE EXCEPTION 'Destination must be empty before initial import'; END IF;
  IF jsonb_typeof(snapshot->t)<>'array' THEN RAISE EXCEPTION 'Missing source table'; END IF;
  EXECUTE format('INSERT INTO public.%I SELECT * FROM jsonb_populate_recordset(null::public.%I,$1)',t,t) USING snapshot->t;
 END LOOP;
 INSERT INTO jtp_private.import_manifest(id) VALUES(true);
 RETURN public.jtp_export();
END; $$;
REVOKE ALL ON FUNCTION public.jtp_import(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.jtp_import(jsonb) TO service_role;
'''
pathlib.Path('supabase/schema/initial.sql').write_text(sql)
guard=[]
for t in tables:
 if t=='portal_settings':continue
 for action in ['INSERT','UPDATE','DELETE']:
  guard.append(f"CREATE TRIGGER freeze_{t}_{action.lower()} BEFORE {action} ON {t} WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;")
pathlib.Path('drizzle/0004_supabase_cutover_guard.sql').write_text('\n--> statement-breakpoint\n'.join(guard))
print(len(queries),'allowlisted operations generated')
