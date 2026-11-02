import {redirect} from 'next/navigation';
import {requireChatGPTUser} from './chatgpt-auth';
import {adminId} from '../lib/portal-db';
import AdminDashboard from './admin-client';
export const dynamic='force-dynamic';
export default async function Home(){const user=await requireChatGPTUser('/');const owner=await adminId();if(user.userId!==owner)redirect('/employee');return <AdminDashboard/>;}
