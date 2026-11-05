import {headers} from 'next/headers';
import {redirect} from 'next/navigation';
import {validAdminSession} from '../lib/admin-session';
import AdminDashboard from './admin-client';
export const dynamic='force-dynamic';
export default async function Home(){if(!await validAdminSession(await headers()))redirect('/admin-login');return <AdminDashboard/>}
