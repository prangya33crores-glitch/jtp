import {requireAdmin,privateJson} from '../../../lib/portal-db';
import {attendanceData,markAttendance} from '../../../lib/attendance';
export const dynamic='force-dynamic';
export async function GET(req:Request){try{const owner=await requireAdmin(req);return privateJson(await attendanceData(owner,new URL(req.url).searchParams.get('month')||undefined))}catch(e){return privateJson({error:(e as Error).message},403)}}
export async function POST(req:Request){try{const owner=await requireAdmin(req);if(req.headers.get('origin')!==new URL(req.url).origin)return privateJson({error:'Invalid origin.'},403);const p:any=await req.json();if(typeof p.person!=='string')throw Error('Select employee.');return privateJson({record:await markAttendance(owner,p.person,p.date,p.assignment,owner,'Admin')})}catch(e){return privateJson({error:(e as Error).message},400)}}
