import {db} from '../../../lib/portal-db';
export const dynamic='force-dynamic';
export async function GET(){try{const r=await db().prepare('SELECT id FROM workspaces LIMIT 2').all();if(r.results.length!==1)throw Error('Workspace unavailable');return Response.json({ready:true,database:'supabase'},{headers:{'Cache-Control':'no-store'}});}catch{return Response.json({ready:false,database:'supabase'},{status:503,headers:{'Cache-Control':'no-store'}});}}
