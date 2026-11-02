CREATE SCHEMA IF NOT EXISTS jtp_private;
REVOKE ALL ON SCHEMA jtp_private FROM PUBLIC, anon, authenticated;
CREATE TABLE public.audit (
	id text PRIMARY KEY NOT NULL,
	workspace text NOT NULL,
	action text NOT NULL,
	details text NOT NULL,
	created_at text NOT NULL
);

CREATE TABLE public.workspaces (
	id text PRIMARY KEY NOT NULL,
	revision integer DEFAULT 0 NOT NULL,
	data text NOT NULL
);

CREATE TABLE public.employee_access (
	id text PRIMARY KEY NOT NULL,
	workspace text NOT NULL,
	person text NOT NULL,
	code_hash text,
	expires_at text,
	user_id text,
	email text,
	status text DEFAULT 'Active' NOT NULL,
	created_at text NOT NULL
);

CREATE UNIQUE INDEX employee_access_code_hash_unique ON public.employee_access (code_hash);
CREATE UNIQUE INDEX employee_access_user_id_unique ON public.employee_access (user_id);
CREATE TABLE public.portal_settings (
	key text PRIMARY KEY NOT NULL,
	value text NOT NULL
);

CREATE TABLE public.password_accounts (
	id text PRIMARY KEY NOT NULL,
	workspace text NOT NULL,
	person text NOT NULL,
	login_id text NOT NULL,
	mobile text,
	password_hash text NOT NULL,
	status text DEFAULT 'Active' NOT NULL,
	must_change integer DEFAULT 1 NOT NULL,
	updated_at text NOT NULL
);

CREATE UNIQUE INDEX password_accounts_login_id_unique ON public.password_accounts (login_id);
CREATE UNIQUE INDEX password_accounts_mobile_unique ON public.password_accounts (mobile);
CREATE TABLE public.password_attempts (
	key text PRIMARY KEY NOT NULL,
	count integer NOT NULL,
	reset_at text NOT NULL
);

CREATE TABLE public.password_sessions (
	token_hash text PRIMARY KEY NOT NULL,
	account text NOT NULL,
	expires_at text NOT NULL
);

ALTER TABLE public.password_sessions ADD credential_hash text DEFAULT '' NOT NULL;
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.workspaces FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.workspaces TO service_role;
ALTER TABLE public.audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.audit FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.audit TO service_role;
ALTER TABLE public.portal_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.portal_settings FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.portal_settings TO service_role;
ALTER TABLE public.employee_access ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.employee_access FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.employee_access TO service_role;
ALTER TABLE public.password_accounts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.password_accounts FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.password_accounts TO service_role;
ALTER TABLE public.password_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.password_sessions FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.password_sessions TO service_role;
ALTER TABLE public.password_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.password_attempts FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.password_attempts TO service_role;
CREATE INDEX audit_workspace_created_idx ON public.audit(workspace,created_at);
CREATE INDEX employee_access_workspace_idx ON public.employee_access(workspace);
CREATE INDEX password_accounts_workspace_idx ON public.password_accounts(workspace);
CREATE INDEX password_sessions_account_idx ON public.password_sessions(account);
CREATE TABLE jtp_private.query_registry (source text PRIMARY KEY,template text NOT NULL);
ALTER TABLE jtp_private.query_registry ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA jtp_private TO service_role;
GRANT SELECT ON jtp_private.query_registry TO service_role;
INSERT INTO jtp_private.query_registry VALUES ('DELETE FROM password_attempts WHERE key=?','DELETE FROM public.password_attempts WHERE key=?');
INSERT INTO jtp_private.query_registry VALUES ('DELETE FROM password_sessions WHERE account=?','DELETE FROM public.password_sessions WHERE account=?');
INSERT INTO jtp_private.query_registry VALUES ('DELETE FROM password_sessions WHERE account=? AND credential_hash=?','DELETE FROM public.password_sessions WHERE account=? AND credential_hash=?');
INSERT INTO jtp_private.query_registry VALUES ('DELETE FROM password_sessions WHERE token_hash=?','DELETE FROM public.password_sessions WHERE token_hash=?');
INSERT INTO jtp_private.query_registry VALUES ('INSERT INTO audit(id,workspace,action,details,created_at) SELECT ?,?,?,?,? WHERE EXISTS (SELECT 1 FROM employee_access WHERE id=? AND user_id=?)','INSERT INTO public.audit(id,workspace,action,details,created_at) SELECT ?,?,?,?,? WHERE EXISTS (SELECT 1 FROM public.employee_access WHERE id=? AND user_id=?)');
INSERT INTO jtp_private.query_registry VALUES ('INSERT INTO audit(id,workspace,action,details,created_at) SELECT ?,?,?,?,? WHERE EXISTS (SELECT 1 FROM workspaces WHERE id=? AND revision=? AND data=?)','INSERT INTO public.audit(id,workspace,action,details,created_at) SELECT ?,?,?,?,? WHERE EXISTS (SELECT 1 FROM public.workspaces WHERE id=? AND revision=? AND data=?)');
INSERT INTO jtp_private.query_registry VALUES ('INSERT INTO audit(id,workspace,action,details,created_at) VALUES(?,?,?,?,?)','INSERT INTO public.audit(id,workspace,action,details,created_at) VALUES(?,?,?,?,?)');
INSERT INTO jtp_private.query_registry VALUES ('INSERT INTO employee_access(id,workspace,person,code_hash,expires_at,user_id,email,status,created_at) VALUES(?,?,?,?,?,NULL,NULL,''Active'',?) ON CONFLICT(id) DO UPDATE SET code_hash=excluded.code_hash,expires_at=excluded.expires_at,user_id=NULL,email=NULL,status=''Active''','INSERT INTO public.employee_access(id,workspace,person,code_hash,expires_at,user_id,email,status,created_at) VALUES(?,?,?,?,?,NULL,NULL,''Active'',?) ON CONFLICT(id) DO UPDATE SET code_hash=excluded.code_hash,expires_at=excluded.expires_at,user_id=NULL,email=NULL,status=''Active''');
INSERT INTO jtp_private.query_registry VALUES ('INSERT INTO password_accounts(id,workspace,person,login_id,mobile,password_hash,status,must_change,updated_at) VALUES(?,?,?,?,?,?,''Active'',1,?) ON CONFLICT(id) DO UPDATE SET login_id=excluded.login_id,mobile=excluded.mobile,password_hash=excluded.password_hash,status=''Active'',must_change=1,updated_at=excluded.updated_at','INSERT INTO public.password_accounts(id,workspace,person,login_id,mobile,password_hash,status,must_change,updated_at) VALUES(?,?,?,?,?,?,''Active'',1,?) ON CONFLICT(id) DO UPDATE SET login_id=excluded.login_id,mobile=excluded.mobile,password_hash=excluded.password_hash,status=''Active'',must_change=1,updated_at=excluded.updated_at');
INSERT INTO jtp_private.query_registry VALUES ('INSERT INTO password_attempts(key,count,reset_at) VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=CASE WHEN reset_at<=? THEN 1 ELSE count+1 END,reset_at=CASE WHEN reset_at<=? THEN excluded.reset_at ELSE reset_at END','INSERT INTO public.password_attempts(key,count,reset_at) VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=CASE WHEN password_attempts.reset_at<=? THEN 1 ELSE password_attempts.count+1 END,reset_at=CASE WHEN password_attempts.reset_at<=? THEN excluded.reset_at ELSE password_attempts.reset_at END');
INSERT INTO jtp_private.query_registry VALUES ('INSERT INTO password_sessions(token_hash,account,credential_hash,expires_at) SELECT ?,id,password_hash,? FROM password_accounts WHERE id=? AND password_hash=? AND status=''Active''','INSERT INTO public.password_sessions(token_hash,account,credential_hash,expires_at) SELECT ?,id,password_hash,? FROM public.password_accounts WHERE id=? AND password_hash=? AND status=''Active''');
INSERT INTO jtp_private.query_registry VALUES ('INSERT INTO workspaces(id,revision,data) VALUES(?,1,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data,revision=workspaces.revision+1 WHERE workspaces.revision=?','INSERT INTO public.workspaces(id,revision,data) VALUES(?,1,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data,revision=workspaces.revision+1 WHERE workspaces.revision=?');
INSERT INTO jtp_private.query_registry VALUES ('INSERT OR IGNORE INTO portal_settings(key,value) VALUES(''admin_user_id'',?)','INSERT INTO public.portal_settings(key,value) VALUES(''admin_user_id'',?) ON CONFLICT DO NOTHING');
INSERT INTO jtp_private.query_registry VALUES ('SELECT * FROM password_accounts WHERE login_id=? OR mobile=? LIMIT 1','SELECT * FROM public.password_accounts WHERE login_id=? OR mobile=? LIMIT 1');
INSERT INTO jtp_private.query_registry VALUES ('SELECT a.*,s.expires_at FROM password_sessions s JOIN password_accounts a ON a.id=s.account WHERE s.token_hash=? AND s.expires_at>? AND s.credential_hash=a.password_hash','SELECT a.*,s.expires_at FROM public.password_sessions s JOIN public.password_accounts a ON a.id=s.account WHERE s.token_hash=? AND s.expires_at>? AND s.credential_hash=a.password_hash');
INSERT INTO jtp_private.query_registry VALUES ('SELECT count FROM password_attempts WHERE key=?','SELECT count FROM public.password_attempts WHERE key=?');
INSERT INTO jtp_private.query_registry VALUES ('SELECT data FROM workspaces WHERE id=?','SELECT data FROM public.workspaces WHERE id=?');
INSERT INTO jtp_private.query_registry VALUES ('SELECT id FROM employee_access WHERE user_id=?','SELECT id FROM public.employee_access WHERE user_id=?');
INSERT INTO jtp_private.query_registry VALUES ('SELECT id FROM password_accounts WHERE id<>? AND (login_id=? OR mobile=? OR login_id=? OR mobile=?) LIMIT 1','SELECT id FROM public.password_accounts WHERE id<>? AND (login_id=? OR mobile=? OR login_id=? OR mobile=?) LIMIT 1');
INSERT INTO jtp_private.query_registry VALUES ('SELECT id FROM password_accounts WHERE id=?','SELECT id FROM public.password_accounts WHERE id=?');
INSERT INTO jtp_private.query_registry VALUES ('SELECT id FROM workspaces LIMIT 2','SELECT id FROM public.workspaces LIMIT 2');
INSERT INTO jtp_private.query_registry VALUES ('SELECT id,workspace,person,user_id,status,expires_at,code_hash FROM employee_access WHERE code_hash=?','SELECT id,workspace,person,user_id,status,expires_at,code_hash FROM public.employee_access WHERE code_hash=?');
INSERT INTO jtp_private.query_registry VALUES ('SELECT person,login_id,mobile,status,must_change,updated_at FROM password_accounts WHERE workspace=?','SELECT person,login_id,mobile,status,must_change,updated_at FROM public.password_accounts WHERE workspace=?');
INSERT INTO jtp_private.query_registry VALUES ('SELECT person,status,email,expires_at,user_id IS NOT NULL AS linked FROM employee_access WHERE workspace=?','SELECT person,status,email,expires_at,user_id IS NOT NULL AS linked FROM public.employee_access WHERE workspace=?');
INSERT INTO jtp_private.query_registry VALUES ('SELECT revision, data FROM workspaces WHERE id = ?','SELECT revision, data FROM public.workspaces WHERE id = ?');
INSERT INTO jtp_private.query_registry VALUES ('SELECT value FROM portal_settings WHERE key=''admin_user_id''','SELECT value FROM public.portal_settings WHERE key=''admin_user_id''');
INSERT INTO jtp_private.query_registry VALUES ('SELECT workspace,person,user_id,status FROM employee_access WHERE user_id=?','SELECT workspace,person,user_id,status FROM public.employee_access WHERE user_id=?');
INSERT INTO jtp_private.query_registry VALUES ('UPDATE employee_access SET status=? WHERE id=?','UPDATE public.employee_access SET status=? WHERE id=?');
INSERT INTO jtp_private.query_registry VALUES ('UPDATE employee_access SET user_id=?,email=?,code_hash=NULL,expires_at=NULL WHERE id=? AND code_hash=? AND user_id IS NULL AND status=''Active'' AND expires_at>?','UPDATE public.employee_access SET user_id=?,email=?,code_hash=NULL,expires_at=NULL WHERE id=? AND code_hash=? AND user_id IS NULL AND status=''Active'' AND expires_at>?');
INSERT INTO jtp_private.query_registry VALUES ('UPDATE password_accounts SET password_hash=?,must_change=0,updated_at=? WHERE id=? AND password_hash=?','UPDATE public.password_accounts SET password_hash=?,must_change=0,updated_at=? WHERE id=? AND password_hash=?');
INSERT INTO jtp_private.query_registry VALUES ('UPDATE password_accounts SET status=?,updated_at=? WHERE id=?','UPDATE public.password_accounts SET status=?,updated_at=? WHERE id=?');

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
