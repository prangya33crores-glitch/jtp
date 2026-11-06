-- Preserve original published duties; attendance on a leave cover requires an active approved leave.
CREATE OR REPLACE FUNCTION public.jtp_mark_attendance(w text,p text,d date,a text,actor text,src text) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF src NOT IN ('Employee','Admin') OR actor IS NULL OR actor='' THEN RAISE EXCEPTION 'Invalid attendance actor'; END IF;
 IF d>(now() AT TIME ZONE 'Asia/Kolkata')::date OR (src='Employee' AND d<>(now() AT TIME ZONE 'Asia/Kolkata')::date) THEN RAISE EXCEPTION 'Invalid attendance date'; END IF;
 -- Serialize against roster/leave updates using the same workspace lock as roster saves.
 PERFORM 1 FROM public.workspaces WHERE id=w FOR UPDATE;
 INSERT INTO public.attendance(workspace,person,date,assignment,shift,location,employee_name,employee_code,shift_name,location_name,source,marked_by)
 SELECT w,p,d,da.id,da.shift,da.location,e.name,e.code,sh.name,loc.name,src,actor
 FROM public.duty_assignments da JOIN public.employees e ON e.workspace=da.workspace AND e.id=da.person
 JOIN public.shifts sh ON sh.workspace=da.workspace AND sh.id=da.shift
 JOIN public.duty_locations loc ON loc.workspace=da.workspace AND loc.id=da.location
 WHERE da.workspace=w AND da.person=p AND da.id=a AND da.date=d AND da.status='Published' AND e.status='Active'
 AND NOT EXISTS(SELECT 1 FROM public.leave_requests l WHERE l.workspace=w AND l.person=p AND l.status='Approved' AND d BETWEEN l."from" AND l."to")
 AND (NOT (da.attributes ? 'replacesAssignment') OR EXISTS (
  SELECT 1 FROM public.duty_assignments original JOIN public.leave_requests l
   ON l.workspace=original.workspace AND l.person=original.person AND l.status='Approved'
   AND original.date BETWEEN l."from" AND l."to"
  WHERE original.workspace=da.workspace AND original.id=da.attributes->>'replacesAssignment' AND original.date=da.date
 ))
 ON CONFLICT(workspace,person,date) DO NOTHING RETURNING to_jsonb(attendance.*) INTO result;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.jtp_mark_attendance(text,text,date,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.jtp_mark_attendance(text,text,date,text,text,text) TO service_role;
